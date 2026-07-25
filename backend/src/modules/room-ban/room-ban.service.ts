import db from "../../config/prisma";

// Persistent, strict ban enforcement - checked by BOTH the LiveKit token
// endpoint (livekit.service.ts) and the socket `room:join` handler
// (socket/roomSocket.ts), so a banned user can neither mint a new LiveKit
// token nor join the room's chat/signaling via socket.io.

const isBanned = async (roomName: string, userId: string): Promise<boolean> => {
	const ban = await db.roomBan.findUnique({
		where: { roomName_userId: { roomName, userId } },
	});
	return ban !== null;
};

const banUser = async (params: {
	roomName: string;
	userId: string;
	bannedBy: string;
	reason?: string;
}) => {
	const { roomName, userId, bannedBy, reason } = params;

	// Upsert so re-banning an already-banned user (e.g. with a new reason)
	// doesn't throw a unique-constraint error.
	return db.roomBan.upsert({
		where: { roomName_userId: { roomName, userId } },
		update: { bannedBy, reason },
		create: { roomName, userId, bannedBy, reason },
	});
};

const unbanUser = async (roomName: string, userId: string) => {
	// deleteMany (not delete) so unbanning someone who isn't banned is a
	// harmless no-op instead of a "record not found" error.
	await db.roomBan.deleteMany({ where: { roomName, userId } });
};

/** Host moderation panel: every active ban for [roomName], newest first. */
const listBanned = async (roomName: string) => {
	const bans = await db.roomBan.findMany({
		where: { roomName },
		include: { user: { select: { name: true } } },
		orderBy: { createdAt: "desc" },
	});

	return bans.map((ban) => ({
		userId: ban.userId,
		name: ban.user.name,
		reason: ban.reason,
		createdAt: ban.createdAt.toISOString(),
	}));
};

export const RoomBanService = { isBanned, banUser, unbanUser, listBanned };
