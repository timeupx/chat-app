import { Server, Socket } from "socket.io";
import { LiveRoomService } from "../modules/live-room/live-room.service";
import { RoomBanService } from "../modules/room-ban/room-ban.service";
import { MAX_ROOM_CAPACITY, roomStateManager } from "./roomState";

// All room-moderation real-time events live here: join/leave, chat
// (with mute enforcement), ban/unban, warnings, guest invites and guest
// requests. Every handler trusts `socket.data.user` (set by
// socketAuthMiddleware from the verified JWT) as the identity - never a
// client-supplied userId - so participants can't impersonate one another
// or forge moderation actions.

function emitToUser(io: Server, roomName: string, userId: string, event: string, payload?: unknown) {
	const viewer = roomStateManager.getViewer(roomName, userId);
	if (viewer) io.to(viewer.socketId).emit(event, payload);
}

function broadcastViewerList(io: Server, roomName: string) {
	// Only the host's own socket needs the moderation panel data.
	const hostId = roomStateManager.getHostUserId(roomName);
	if (!hostId) return;

	const viewers = roomStateManager.listViewers(roomName).map((v) => ({
		userId: v.userId,
		name: v.name,
		isMuted: v.isMuted,
		isGuest: v.isGuest,
	}));
	emitToUser(io, roomName, hostId, "room:viewerListUpdated", { viewers });
}

function broadcastGuestRequests(io: Server, roomName: string) {
	const hostId = roomStateManager.getHostUserId(roomName);
	if (hostId) {
		emitToUser(io, roomName, hostId, "guest:requestListUpdated", {
			requests: roomStateManager.listGuestRequests(roomName),
		});
	}
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
			isMuted: viewer.isMuted,
			isGuest: viewer.isGuest,
			viewers: isHost
				? roomStateManager.listViewers(roomName).map((v) => ({
						userId: v.userId,
						name: v.name,
						isMuted: v.isMuted,
						isGuest: v.isGuest,
					}))
				: undefined,
			guestRequests: isHost ? roomStateManager.listGuestRequests(roomName) : undefined,
		});

		// Always re-broadcast, regardless of who just joined - this is what
		// keeps the host's viewer list correct even if the HOST is the one
		// reconnecting after viewers already joined (the old `if (!isHost)`
		// guard here meant a reconnecting host only ever got the one-time
		// `room:joined` snapshot, which the client didn't even listen for).
		broadcastViewerList(io, roomName);
		broadcastGuestRequests(io, roomName);
	});

	socket.on("room:leave", ({ roomName }: { roomName: string }) => {
		socket.leave(roomName);
		roomStateManager.leave(roomName, user.userId);
		broadcastViewerList(io, roomName);
		broadcastGuestRequests(io, roomName);
	});

	socket.on("disconnect", () => {
		const located = roomStateManager.findBySocketId(socket.id);
		if (!located) return;
		roomStateManager.leave(located.roomName, located.userId);
		broadcastViewerList(io, located.roomName);
		broadcastGuestRequests(io, located.roomName);
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
		}
	);

	socket.on("host:unban", async ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		await RoomBanService.unbanUser(roomName, targetUserId);
		socket.emit("host:unbanAck", { targetUserId });
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

	socket.on("host:acceptGuestRequest", ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		roomStateManager.setGuest(roomName, targetUserId, true);
		roomStateManager.removeGuestRequest(roomName, targetUserId);
		emitToUser(io, roomName, targetUserId, "guest:inviteAccepted");
		broadcastViewerList(io, roomName);
		broadcastGuestRequests(io, roomName);
	});

	socket.on("host:rejectGuestRequest", ({ roomName, targetUserId }: { roomName: string; targetUserId: string }) => {
		if (!roomStateManager.isHost(roomName, user.userId)) return;
		roomStateManager.removeGuestRequest(roomName, targetUserId);
		emitToUser(io, roomName, targetUserId, "guest:requestRejected");
		broadcastGuestRequests(io, roomName);
	});

	// ---- Viewer-initiated guest flows ----

	socket.on("viewer:requestGuest", ({ roomName }: { roomName: string }) => {
		roomStateManager.addGuestRequest(roomName, user.userId, user.name);
		broadcastGuestRequests(io, roomName);
	});

	socket.on("guest:acceptInvite", ({ roomName }: { roomName: string }) => {
		roomStateManager.setGuest(roomName, user.userId, true);
		socket.emit("guest:inviteAccepted");
		broadcastViewerList(io, roomName);
	});

	socket.on("guest:declineInvite", ({ roomName }: { roomName: string }) => {
		const hostId = roomStateManager.getHostUserId(roomName);
		if (hostId) emitToUser(io, roomName, hostId, "guest:inviteDeclined", { userId: user.userId, name: user.name });
	});
}
