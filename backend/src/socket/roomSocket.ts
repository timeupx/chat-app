import { Server, Socket } from "socket.io";
import db from "../config/prisma";
import { LiveKitServices } from "../modules/livekit/livekit.service";
import { LiveRoomService } from "../modules/live-room/live-room.service";
import { RoomBanService } from "../modules/room-ban/room-ban.service";
import { MAX_ROOM_CAPACITY, roomStateManager } from "./roomState";

/** Best-effort LiveKit publish grant/revoke — never blocks socket UX on failure. */
async function setLiveKitCanPublish(roomName: string, userId: string, canPublish: boolean) {
	try {
		await LiveKitServices.setCanPublish(roomName, userId, canPublish);
	} catch (err) {
		console.warn(
			`[livekit] setCanPublish(${canPublish}) failed for ${userId} in ${roomName}:`,
			err
		);
	}
}

// All room-moderation real-time events live here: join/leave, chat
// (with mute enforcement), ban/unban, warnings, guest invites and guest
// requests. Every handler trusts `socket.data.user` (set by
// socketAuthMiddleware from the verified JWT) as the identity - never a
// client-supplied userId - so participants can't impersonate one another
// or forge moderation actions.

/** Persisted + broadcast like normal chat; clients render as "{name} joined". */
export const ROOM_ENTERED_MESSAGE = "joined";

function serializeViewer(v: {
	userId: string;
	name: string;
	isMuted: boolean;
	isGuest: boolean;
	slotNumber: number | null;
}) {
	return {
		userId: v.userId,
		name: v.name,
		isMuted: v.isMuted,
		isGuest: v.isGuest,
		slotNumber: v.slotNumber,
	};
}

function emitToUser(io: Server, roomName: string, userId: string, event: string, payload?: unknown) {
	const viewer = roomStateManager.getViewer(roomName, userId);
	if (viewer) io.to(viewer.socketId).emit(event, payload);
}

/**
 * Broadcasts stage occupancy + moderation viewer list to everyone in the
 * room. Slot assignments ride on this same event so host/viewer/guest UIs
 * stay in sync without a separate channel.
 */
function broadcastViewerList(io: Server, roomName: string) {
	const viewers = roomStateManager.listViewers(roomName).map(serializeViewer);
	const slots = roomStateManager.listOccupiedSlots(roomName).map(serializeViewer);
	const slotCount = roomStateManager.getSlotCount(roomName);

	io.to(roomName).emit("room:viewerListUpdated", {
		viewers,
		slots,
		slotCount,
	});
}

function broadcastGuestRequests(io: Server, roomName: string) {
	const hostId = roomStateManager.getHostUserId(roomName);
	if (hostId) {
		emitToUser(io, roomName, hostId, "guest:requestListUpdated", {
			requests: roomStateManager.listGuestRequests(roomName),
		});
	}
}

/** Host-only: pushes the current ban list, e.g. right after a ban/unban. */
async function broadcastBannedList(io: Server, roomName: string) {
	const hostId = roomStateManager.getHostUserId(roomName);
	if (!hostId) return;
	const banned = await RoomBanService.listBanned(roomName);
	emitToUser(io, roomName, hostId, "room:bannedListUpdated", { banned });
}

/** Loads the room's configured seat count from Postgres into in-memory state. */
async function syncRoomSlotCount(roomName: string): Promise<void> {
	try {
		const room = await db.liveRoom.findUnique({
			where: { id: roomName },
			select: { slotCount: true },
		});
		if (room) roomStateManager.setSlotCount(roomName, room.slotCount);
	} catch (err) {
		console.error(`Failed to load slotCount for room ${roomName}:`, err);
	}
}

function guestLimitReachedPayload(roomName: string) {
	const max = roomStateManager.getMaxGuests(roomName);
	return { reason: `Guest limit reached (${max}/${max}).` };
}

export function registerRoomSocketHandlers(io: Server, socket: Socket) {
	const user = socket.data.user;

	socket.on("room:join", async ({ roomName, role }: { roomName: string; role: "host" | "viewer" }) => {
		if (!roomName) return;

		const banned = await RoomBanService.isBanned(roomName, user.userId);
		if (banned) {
			socket.emit("room:joinRejected", { reason: "You are banned from this room." });
			return;
		}

		// The host is exempt - never lock an owner out of their own room.
		if (role !== "host" && roomStateManager.getParticipantCount(roomName) >= MAX_ROOM_CAPACITY) {
			socket.emit("room:joinRejected", { reason: "Room is full (50/50)" });
			return;
		}

		await syncRoomSlotCount(roomName);

		socket.join(roomName);
		const viewer = roomStateManager.join({
			roomName,
			userId: user.userId,
			name: user.name,
			socketId: socket.id,
			role,
		});

		const isHost = roomStateManager.isHost(roomName, user.userId);
		socket.emit("room:joined", {
			isHost,
			hostUserId: roomStateManager.getHostUserId(roomName),
			isMuted: viewer.isMuted,
			isGuest: viewer.isGuest,
			slotNumber: viewer.slotNumber,
			slotCount: roomStateManager.getSlotCount(roomName),
			slots: roomStateManager.listOccupiedSlots(roomName).map(serializeViewer),
			// Host filter (legacy field) + per-user filters for host + guests.
			videoFilter: roomStateManager.getVideoFilter(roomName),
			participantFilters: roomStateManager.listParticipantFilters(roomName),
			// Everyone gets the online list so the eye pill can open it.
			viewers: roomStateManager.listViewers(roomName).map(serializeViewer),
			guestRequests: isHost ? roomStateManager.listGuestRequests(roomName) : undefined,
			// Same snapshot-on-join treatment as viewers/guestRequests above -
			// without this the host's Banned Users sheet stays empty until
			// the next ban/unban happens to re-broadcast it.
			bannedUsers: isHost ? await RoomBanService.listBanned(roomName) : undefined,
		});

		// Viewer fully entered (tap-to-enter): persist + broadcast like chat
		// so history and live feed both show "admin joined" / "rana joined".
		// Hosts are excluded so going live doesn't spam the feed.
		if (role === "viewer") {
			const payload = {
				userId: user.userId,
				name: user.name,
				message: ROOM_ENTERED_MESSAGE,
				isSystem: true,
				sentAt: new Date().toISOString(),
			};
			io.to(roomName).emit("chat:message", payload);

			try {
				await LiveRoomService.saveMessage(roomName, user.userId, user.name, ROOM_ENTERED_MESSAGE);
			} catch (err) {
				console.error(`Failed to persist enter message for room ${roomName}:`, err);
			}
		}

		// Always re-broadcast, regardless of who just joined - this is what
		// keeps the host's viewer list correct even if the HOST is the one
		// reconnecting after viewers already joined (the old `if (!isHost)`
		// guard here meant a reconnecting host only ever got the one-time
		// `room:joined` snapshot, which the client didn't even listen for).
		broadcastViewerList(io, roomName);
		broadcastGuestRequests(io, roomName);

		// Host on socket = on air for the Live list. Room row is kept on leave.
		if (isHost) {
			try {
				await LiveRoomService.syncHostPresence(roomName, user.userId, true);
			} catch (err) {
				console.error(`Failed to mark host online for room ${roomName}:`, err);
			}
		}
	});

	// Leave / disconnect must NOT delete the room — only intentional host
	// Exit (DELETE via /end-live) does that. But when the host leaves we
	// clear the public LIVE / on-air flag so the list doesn't show a ghost stream.
	socket.on("room:leave", async ({ roomName }: { roomName: string }) => {
		const wasHost = roomStateManager.isHost(roomName, user.userId);
		socket.leave(roomName);
		roomStateManager.leave(roomName, user.userId);
		broadcastViewerList(io, roomName);
		broadcastGuestRequests(io, roomName);
		if (wasHost) {
			try {
				await LiveRoomService.syncHostPresence(roomName, user.userId, false);
			} catch (err) {
				console.error(`Failed to mark host offline for room ${roomName}:`, err);
			}
		}
	});

	socket.on("disconnect", async () => {
		const located = roomStateManager.findBySocketId(socket.id);
		if (!located) return;
		const wasHost = roomStateManager.isHost(located.roomName, located.userId);
		roomStateManager.leave(located.roomName, located.userId);
		broadcastViewerList(io, located.roomName);
		broadcastGuestRequests(io, located.roomName);
		if (wasHost) {
			try {
				await LiveRoomService.syncHostPresence(
					located.roomName,
					located.userId,
					false
				);
			} catch (err) {
				console.error(
					`Failed to mark host offline for room ${located.roomName}:`,
					err
				);
			}
		}
	});

	// ---- Chat (mute enforced here) ----

	socket.on("chat:send", async ({ roomName, message }: { roomName: string; message: string }) => {
		const viewer = roomStateManager.getViewer(roomName, user.userId);
		if (viewer?.isMuted) {
			socket.emit("chat:rejected", { reason: "You are muted by the host." });
			return;
		}
		if (!message?.trim()) return;

		io.to(roomName).emit("chat:message", {
			userId: user.userId,
			name: user.name,
			message,
			sentAt: new Date().toISOString(),
		});

		// Persisted for history (last-50 fetch on join) - broadcast above
		// already happened, so a persistence failure never blocks live chat.
		try {
			await LiveRoomService.saveMessage(roomName, user.userId, user.name, message);
		} catch (err) {
			console.error(`Failed to persist chat message for room ${roomName}:`, err);
		}
	});

	// Virtual gifts — overlay + chat line for everyone in the socket room.
	// Hosts cannot send gifts (viewers / guests only).
	socket.on(
		"gift:send",
		(payload: {
			roomName?: string;
			gift?: { id: string; name: string; emoji: string; coinCost?: number };
		}) => {
			const located = roomStateManager.findBySocketId(socket.id);
			const roomName = payload?.roomName || located?.roomName;
			if (!roomName) return;
			if (!roomStateManager.getViewer(roomName, user.userId)) return;
			if (roomStateManager.isHost(roomName, user.userId)) return;

			const gift = payload?.gift;
			if (!gift?.id || !gift?.name || !gift?.emoji) return;

			const giftPayload = {
				id: String(gift.id),
				name: String(gift.name).slice(0, 40),
				emoji: String(gift.emoji).slice(0, 16),
				coinCost: Number(gift.coinCost) || 0,
			};
			const sentAt = new Date().toISOString();

			io.to(roomName).emit("gift:received", {
				userId: user.userId,
				username: user.name,
				name: user.name,
				gift: giftPayload,
				// Flat fields — Flutter web sometimes fails nested Map checks.
				giftId: giftPayload.id,
				giftName: giftPayload.name,
				giftEmoji: giftPayload.emoji,
				coinCost: giftPayload.coinCost,
				sentAt,
			});

			const chatLine = `sent a ${giftPayload.name} ${giftPayload.emoji}`;
			io.to(roomName).emit("chat:message", {
				userId: user.userId,
				name: user.name,
				message: chatLine,
				isSystem: false,
				sentAt,
			});
		}
	);

	// ---- Host-only moderation actions ----
	// Every handler below re-checks host status server-side; a non-host
	// emitting these events is simply ignored.

	socket.on(
		"host:ban",
		async ({ roomName, targetUserId, reason }: { roomName: string; targetUserId: string; reason?: string }) => {
			if (!roomStateManager.isHost(roomName, user.userId)) return;

			await RoomBanService.banUser({ roomName, userId: targetUserId, bannedBy: user.userId, reason });

			emitToUser(io, roomName, targetUserId, "room:banned", {
				reason: reason ?? "You have been banned by the host.",
			});

			const target = roomStateManager.getViewer(roomName, targetUserId);
			if (target) {
				io.sockets.sockets.get(target.socketId)?.leave(roomName);
			}
			roomStateManager.leave(roomName, targetUserId);
			broadcastViewerList(io, roomName);
			broadcastGuestRequests(io, roomName);
			await broadcastBannedList(io, roomName);
		}
	);

	socket.on("host:unban", async ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		await RoomBanService.unbanUser(roomName, targetUserId);
		socket.emit("host:unbanAck", { targetUserId });
		await broadcastBannedList(io, roomName);
	});

	// Lets the host open the Banned Users sheet and get a fresh list
	// on-demand too, not just right after connecting or a ban/unban.
	socket.on("host:listBans", async ({ roomName }: { roomName: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		await broadcastBannedList(io, roomName);
	});

	socket.on("host:chatMute", ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		roomStateManager.setMuted(roomName, targetUserId, true);
		emitToUser(io, roomName, targetUserId, "chat:muted");
		broadcastViewerList(io, roomName);
	});

	socket.on("host:chatUnmute", ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		roomStateManager.setMuted(roomName, targetUserId, false);
		emitToUser(io, roomName, targetUserId, "chat:unmuted");
		broadcastViewerList(io, roomName);
	});

	socket.on(
		"host:warn",
		({ roomName, targetUserId, reason }: { roomName: string; targetUserId: string; reason: string }) => {
			if (!roomStateManager.isHost(roomName, user.userId)) return;
			emitToUser(io, roomName, targetUserId, "warning:received", { reason });
		}
	);

	socket.on("host:inviteGuest", ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		emitToUser(io, roomName, targetUserId, "guest:invited", { hostName: user.name });
	});

	socket.on(
		"host:acceptGuestRequest",
		async ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
			if (!roomStateManager.isHost(roomName, user.userId)) return;

			const maxGuests = roomStateManager.getMaxGuests(roomName);
			// The cap is enforced here (not just when the request is made) so a
			// burst of requests can't slip in once a slot happens to free up.
			if (roomStateManager.countGuests(roomName) >= maxGuests) {
				roomStateManager.removeGuestRequest(roomName, targetUserId);
				emitToUser(io, roomName, targetUserId, "guest:requestRejected", guestLimitReachedPayload(roomName));
				broadcastGuestRequests(io, roomName);
				return;
			}

			const slotNumber = roomStateManager.assignGuestSlot(roomName, targetUserId);
			if (slotNumber == null) {
				roomStateManager.removeGuestRequest(roomName, targetUserId);
				emitToUser(io, roomName, targetUserId, "guest:requestRejected", guestLimitReachedPayload(roomName));
				broadcastGuestRequests(io, roomName);
				return;
			}

			roomStateManager.removeGuestRequest(roomName, targetUserId);
			// Grant publish before the client tries to enable camera (no reconnect).
			await setLiveKitCanPublish(roomName, targetUserId, true);
			emitToUser(io, roomName, targetUserId, "guest:inviteAccepted", { slotNumber });
			broadcastViewerList(io, roomName);
			broadcastGuestRequests(io, roomName);
		}
	);

	socket.on("host:rejectGuestRequest", ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		roomStateManager.removeGuestRequest(roomName, targetUserId);
		emitToUser(io, roomName, targetUserId, "guest:requestRejected", {
			reason: "The host declined your request.",
		});
		broadcastGuestRequests(io, roomName);
	});

	const normalizeFilter = (filter: {
		beauty?: number;
		brightness?: number;
		contrast?: number;
		saturation?: number;
		beautyModeEnabled?: boolean;
		preset?: string;
	}) => ({
		beauty: Number(filter.beauty) || 0,
		brightness: Number(filter.brightness) || 0,
		contrast: Number(filter.contrast) || 0,
		saturation: Number(filter.saturation) || 0,
		beautyModeEnabled: !!filter.beautyModeEnabled,
		preset: String(filter.preset || "natural"),
	});

	const broadcastParticipantFilter = (
		roomName: string,
		userId: string
	) => {
		const filter = roomStateManager.getParticipantFilter(roomName, userId);
		io.to(roomName).emit("room:participantFilterUpdated", {
			userId,
			filter,
		});
		// Keep legacy host-only event in sync so older clients still update.
		if (roomStateManager.isHost(roomName, userId)) {
			io.to(roomName).emit("room:filterUpdated", {
				filter: roomStateManager.getVideoFilter(roomName),
			});
		}
	};

	// Beauty / color filter — applied client-side on every device so viewers
	// see the same look as the host (LiveKit publishes the raw camera track).
	socket.on(
		"host:setFilter",
		({
			roomName,
			filter,
		}: {
			roomName: string;
			filter: {
				beauty: number;
				brightness: number;
				contrast: number;
				saturation: number;
				beautyModeEnabled: boolean;
				preset: string;
			};
		}) => {
			if (!roomStateManager.isHost(roomName, user.userId)) return;
			if (!filter || typeof filter !== "object") return;
			roomStateManager.setVideoFilter(roomName, normalizeFilter(filter));
			broadcastParticipantFilter(roomName, user.userId);
		}
	);

	// Host or on-stage guest: set their own tile's beauty look for everyone.
	socket.on(
		"participant:setFilter",
		({
			roomName,
			filter,
		}: {
			roomName: string;
			filter: {
				beauty: number;
				brightness: number;
				contrast: number;
				saturation: number;
				beautyModeEnabled: boolean;
				preset: string;
			};
		}) => {
			const viewer = roomStateManager.getViewer(roomName, user.userId);
			if (!viewer) return;
			const onStage =
				roomStateManager.isHost(roomName, user.userId) || viewer.isGuest;
			if (!onStage) return;
			if (!filter || typeof filter !== "object") return;
			roomStateManager.setParticipantFilter(
				roomName,
				user.userId,
				normalizeFilter(filter)
			);
			broadcastParticipantFilter(roomName, user.userId);
		}
	);

	// ---- Viewer-initiated guest flows ----

	socket.on("viewer:requestGuest", ({ roomName }: { roomName: string }) => {
		roomStateManager.addGuestRequest(roomName, user.userId, user.name);
		broadcastGuestRequests(io, roomName);
	});

	// Viewer joins co-host stage immediately — no host approval required.
	socket.on(
		"viewer:joinGuest",
		async ({ roomName, slotNumber }: { roomName: string; slotNumber?: number }) => {
			const maxGuests = roomStateManager.getMaxGuests(roomName);
			if (roomStateManager.countGuests(roomName) >= maxGuests) {
				socket.emit("guest:requestRejected", guestLimitReachedPayload(roomName));
				return;
			}

			const seat = roomStateManager.assignGuestSlot(
				roomName,
				user.userId,
				typeof slotNumber === "number" ? slotNumber : null
			);
			if (seat == null) {
				socket.emit("guest:requestRejected", guestLimitReachedPayload(roomName));
				return;
			}

			roomStateManager.removeGuestRequest(roomName, user.userId);
			await setLiveKitCanPublish(roomName, user.userId, true);
			socket.emit("guest:inviteAccepted", { slotNumber: seat });
			broadcastViewerList(io, roomName);
			broadcastGuestRequests(io, roomName);
		}
	);

	socket.on("guest:acceptInvite", async ({ roomName }: { roomName: string }) => {
		const maxGuests = roomStateManager.getMaxGuests(roomName);
		if (roomStateManager.countGuests(roomName) >= maxGuests) {
			socket.emit("guest:requestRejected", guestLimitReachedPayload(roomName));
			return;
		}

		const slotNumber = roomStateManager.assignGuestSlot(roomName, user.userId);
		if (slotNumber == null) {
			socket.emit("guest:requestRejected", guestLimitReachedPayload(roomName));
			return;
		}

		await setLiveKitCanPublish(roomName, user.userId, true);
		socket.emit("guest:inviteAccepted", { slotNumber });
		broadcastViewerList(io, roomName);
	});

	socket.on("guest:declineInvite", ({ roomName }: { roomName: string }) => {
		const hostId = roomStateManager.getHostUserId(roomName);
		if (hostId) emitToUser(io, roomName, hostId, "guest:inviteDeclined", { userId: user.userId, name: user.name });
	});

	// Guest steps off stage but stays in the room as a normal viewer.
	socket.on("guest:leaveStage", async ({ roomName }: { roomName: string }) => {
		const viewer = roomStateManager.getViewer(roomName, user.userId);
		if (!viewer?.isGuest) return;
		roomStateManager.freeSlot(roomName, user.userId);
		await setLiveKitCanPublish(roomName, user.userId, false);
		broadcastParticipantFilter(roomName, user.userId);
		socket.emit("guest:leftStage", {});
		broadcastViewerList(io, roomName);
	});

	// Host removes a co-host from the stage; they stay in the room as a viewer.
	socket.on(
		"host:removeGuest",
		async ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
			if (!roomStateManager.isHost(roomName, user.userId)) return;
			const target = roomStateManager.getViewer(roomName, targetUserId);
			if (!target?.isGuest) return;

			roomStateManager.freeSlot(roomName, targetUserId);
			await setLiveKitCanPublish(roomName, targetUserId, false);
			broadcastParticipantFilter(roomName, targetUserId);
			emitToUser(io, roomName, targetUserId, "guest:removedFromStage", {
				reason: "The host removed you from the live stage.",
			});
			broadcastViewerList(io, roomName);
		}
	);
}
