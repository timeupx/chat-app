import db from "../../config/prisma";
import ApiError from "../../utils/apiError";
import { getIO } from "../../socket/ioInstance";
import { roomStateManager } from "../../socket/roomState";
import { TCreateLiveRoom } from "./live-room.validation";

const hostSelect = {
	include: { host: { select: { id: true, name: true, photo: true } } },
} as const;

const createRoom = async (hostId: string, payload: TCreateLiveRoom) => {
	const host = await db.user.findUnique({
		where: { id: hostId },
		select: { photo: true, name: true },
	});
	if (!host) {
		throw new ApiError(404, "Host not found");
	}

	// One room per host — create again only after the existing room is deleted.
	const existing = await db.liveRoom.findFirst({
		where: { hostId },
		select: { id: true, roomName: true },
	});
	if (existing) {
		throw new ApiError(
			409,
			"You already have a room. Use your existing room instead of creating another.",
		);
	}

	// Cover is the host's profile photo — no separate upload on Go Live.
	// Fallback avatar keeps the list card non-empty when photo is unset.
	const roomImage =
		payload.roomImage?.trim() ||
		host.photo?.trim() ||
		`https://ui-avatars.com/api/?name=${encodeURIComponent(host.name || "Host")}&background=6C3483&color=fff&size=256`;

	return db.liveRoom.create({
		data: {
			hostId,
			roomName: payload.roomName,
			roomImage,
			is18Plus: payload.is18Plus ?? false,
			roomRules: payload.roomRules ?? "",
			filterName: payload.filterName ?? "Natural",
			slotCount: payload.slotCount ?? 6,
		},
	});
};

// Room list for LiveRoomListScreen's grid. `viewerCount` comes from the
// live in-memory socket state (roomStateManager), not the database - it's
// the count of everyone (host + viewers + guests) currently connected.
//
// No live/offline sorting happens here on purpose: prioritizing "your own
// room" requires knowing the REQUESTING user's id, which is a per-viewer
// concern, not a property of the room list itself. That sort lives entirely
// client-side in LiveRoomListScreen. `hostId` is included specifically so
// the client can do that `hostId == currentUserId` comparison.
const listRooms = async () => {
	const rooms = await db.liveRoom.findMany({
		orderBy: { createdAt: "desc" },
		...hostSelect,
	});

	return rooms.map((room) => {
		// LIVE badge only while the host is actually connected — a stale
		// DB `isLive=true` after app-kill must not keep the room "on air".
		const hostOnline = roomStateManager.isHostOnline(room.id);
		return {
			id: room.id,
			hostId: room.hostId,
			roomName: room.roomName,
			roomImage: room.roomImage,
			is18Plus: room.is18Plus,
			isLive: room.isLive && hostOnline,
			filterName: room.filterName,
			slotCount: room.slotCount,
			hostName: room.host.name,
			hostPhoto: room.host.photo,
			viewerCount: roomStateManager.getParticipantCount(room.id),
		};
	});
};

// `isHost` is computed here, server-side, and is the ONLY thing the
// Flutter app should trust to decide whether to render the "GO LIVE"
// button - never a client-side `currentUserId == hostId` comparison.
const getRoomDetail = async (roomId: string, requestingUserId: string) => {
	const room = await db.liveRoom.findUnique({ where: { id: roomId }, ...hostSelect });
	if (!room) {
		throw new ApiError(404, "Room not found");
	}

	const hostOnline = roomStateManager.isHostOnline(room.id);
	return {
		id: room.id,
		hostId: room.hostId,
		roomName: room.roomName,
		roomImage: room.roomImage,
		is18Plus: room.is18Plus,
		roomRules: room.roomRules,
		filterName: room.filterName,
		slotCount: room.slotCount,
		isLive: room.isLive && hostOnline,
		hostName: room.host.name,
		hostPhoto: room.host.photo,
		isHost: room.hostId === requestingUserId,
		viewerCount: roomStateManager.getParticipantCount(room.id),
	};
};

const setLive = async (roomId: string, requestingUserId: string, isLive: boolean) => {
	const room = await db.liveRoom.findUnique({ where: { id: roomId } });
	if (!room) {
		throw new ApiError(404, "Room not found");
	}
	if (room.hostId !== requestingUserId) {
		throw new ApiError(403, "Only the host can control this room's live status");
	}

	const updated = await db.liveRoom.update({ where: { id: roomId }, data: { isLive } });

	// Global broadcast (not scoped to any one room's socket.io channel) so
	// every client sitting on LiveRoomListScreen re-sorts/updates instantly
	// instead of only picking this up on their next manual refresh.
	// Public "on air" = DB flag AND host currently connected.
	const onAir = isLive && roomStateManager.isHostOnline(roomId);
	getIO()?.emit("room:statusUpdated", { roomId, isLive: onAir, deleted: false });

	return updated;
};

/**
 * Host socket join/leave — flips the public on-air signal without deleting
 * the room. Leave keeps the row so the host can resume later via Go Live.
 */
const syncHostPresence = async (roomId: string, hostUserId: string, online: boolean) => {
	const room = await db.liveRoom.findUnique({ where: { id: roomId } });
	if (!room || room.hostId !== hostUserId) return;

	if (online) {
		if (!room.isLive) {
			await db.liveRoom.update({ where: { id: roomId }, data: { isLive: true } });
		}
		getIO()?.emit("room:statusUpdated", { roomId, isLive: true, deleted: false });
		return;
	}

	// Host left / disconnected — room stays, but stop showing LIVE on the list.
	if (room.isLive) {
		await db.liveRoom.update({ where: { id: roomId }, data: { isLive: false } });
	}
	getIO()?.emit("room:statusUpdated", { roomId, isLive: false, deleted: false });
};

/**
 * Host intentional exit: delete the room row (chat messages cascade) and
 * notify everyone. Accidental disconnect must NOT call this.
 */
const deleteRoom = async (roomId: string, requestingUserId: string) => {
	const room = await db.liveRoom.findUnique({ where: { id: roomId } });
	if (!room) {
		throw new ApiError(404, "Room not found");
	}
	if (room.hostId !== requestingUserId) {
		throw new ApiError(403, "Only the host can delete this room");
	}

	// Bans are not FK-cascaded — clear them with the room.
	await db.roomBan.deleteMany({ where: { roomName: roomId } });
	await db.liveRoom.delete({ where: { id: roomId } });

	roomStateManager.destroyRoom(roomId);

	const io = getIO();
	if (io) {
		io.to(roomId).emit("room:ended", { reason: "Host ended the live." });
		io.emit("room:statusUpdated", { roomId, isLive: false, deleted: true });
		io.in(roomId).disconnectSockets(true);
	}

	return { id: roomId, deleted: true };
};

// Strictly the last 50 messages, oldest-first for rendering as a feed.
const getMessages = async (roomId: string) => {
	const messages = await db.liveMessage.findMany({
		where: { roomId },
		orderBy: { createdAt: "desc" },
		take: 50,
	});

	return messages.reverse();
};

const saveMessage = async (roomId: string, userId: string, name: string, message: string) => {
	return db.liveMessage.create({ data: { roomId, userId, name, message } });
};

export const LiveRoomService = {
	createRoom,
	listRooms,
	getRoomDetail,
	setLive,
	syncHostPresence,
	deleteRoom,
	getMessages,
	saveMessage,
};
