import { AccessToken, RoomServiceClient } from "livekit-server-sdk";
import ApiError from "../../utils/apiError";
import { RoomBanService } from "../room-ban/room-ban.service";
import { MAX_ROOM_CAPACITY, roomStateManager } from "../../socket/roomState";
import { TCreateLiveKitToken } from "./livekit.validation";

interface CreateTokenParams extends TCreateLiveKitToken {
	userId: string;
	name: string;
}

function requireLiveKitConfig() {
	const apiKey = process.env.LIVEKIT_API_KEY;
	const apiSecret = process.env.LIVEKIT_API_SECRET;
	const url = process.env.LIVEKIT_URL;

	if (!apiKey || !apiSecret || !url) {
		throw new ApiError(500, "LiveKit is not configured on the server");
	}

	return { apiKey, apiSecret, url };
}

/** RoomService HTTP host (wss → https). */
function getRoomServiceClient() {
	const { apiKey, apiSecret, url } = requireLiveKitConfig();
	const host = url.replace(/^wss:/i, "https:").replace(/^ws:/i, "http:");
	return new RoomServiceClient(host, apiKey, apiSecret);
}

/**
 * Mid-session permission change so a connected viewer can start publishing
 * as a guest without disconnecting (and without tearing down host video).
 * Permissions are replaced atomically — keep subscribe/data grants.
 */
const setCanPublish = async (
	roomName: string,
	identity: string,
	canPublish: boolean
) => {
	const client = getRoomServiceClient();
	await client.updateParticipant(roomName, identity, {
		permission: {
			canPublish,
			canSubscribe: true,
			canPublishData: true,
		},
	});
};

// Generates a signed LiveKit access token server-side, using the API
// key/secret from .env - these never reach the client. `identity`/`name`
// come from the caller's verified JWT (never the request body). Two checks
// run before a token is ever minted:
//   1. A strict ban check - one of two enforcement points for the ban
//      system, the other being socket.io's `room:join` handler.
//   2. A 50-participant capacity check - the host is exempt, so an owner
//      is never locked out of their own room.
const createToken = async (params: CreateTokenParams) => {
	const { apiKey, apiSecret } = requireLiveKitConfig();

	const { roomName, role, userId, name } = params;

	const banned = await RoomBanService.isBanned(roomName, userId);
	if (banned) {
		throw new ApiError(403, "You are banned from this room.");
	}

	if (role !== "host" && roomStateManager.getParticipantCount(roomName) >= MAX_ROOM_CAPACITY) {
		throw new ApiError(409, "Room is full (50/50)");
	}

	const accessToken = new AccessToken(apiKey, apiSecret, {
		identity: userId,
		name,
		ttl: "6h",
	});

	accessToken.addGrant({
		room: roomName,
		roomJoin: true,
		canPublish: role === "host" || role === "guest",
		canSubscribe: true,
		canPublishData: true,
	});

	return accessToken.toJwt();
};

export const LiveKitServices = { createToken, setCanPublish };
