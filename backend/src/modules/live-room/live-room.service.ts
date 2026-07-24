import db from "../../config/prisma";
import ApiError from "../../utils/apiError";
import { getIO } from "../../socket/ioInstance";
import { roomStateManager } from "../../socket/roomState";
import { TCreateLiveRoom } from "./live-room.validation";

const hostSelect = {
	include: { host: { select: { id: true, name: true, photo: true } } },
} as const;

const createRoom = async (hostId: string, payload: TCreateLiveRoom) => {
	return db.liveRoom.create({ data: { ...payload, hostId } });
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

	return rooms.map((room) => ({
		id: room.id,
		hostId: room.hostId,
		roomName: room.roomName,
		roomImage: room.roomImage,
		is18Plus: room.is18Plus,
		isLive: room.isLive,
		hostName: room.host.name,
		hostPhoto: room.host.photo,
		viewerCount: roomStateManager.getParticipantCount(room.id),
	}));
};

// `isHost` is computed here, server-side, and is the ONLY thing the
// Flutter app should trust to decide whether to render the "GO LIVE"
// button - never a client-side `currentUserId == hostId` comparison.
const getRoomDetail = async (roomId: string, requestingUserId: string) => {
	const room = await db.liveRoom.findUnique({ where: { id: roomId }, ...hostSelect });
	if (!room) {
		throw new ApiError(404, "Room not found");
	}

	return {
		id: room.id,
		roomName: room.roomName,
		roomImage: room.roomImage,
		is18Plus: room.is18Plus,
		roomRules: room.roomRules,
		isLive: room.isLive,
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
	getIO()?.emit("room:statusUpdated", { roomId, isLive });

	return updated;
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
	getMessages,
	saveMessage,
};
