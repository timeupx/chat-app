// In-memory state for "live session" concerns that do NOT need to survive
// a server restart: who is currently in the room, who's chat-muted, who's a
// guest, and pending guest requests. This is intentionally NOT persisted to
// Postgres - only bans are (see room-ban.service.ts) since bans are the one
// thing that must survive a reconnect/restart per the strict-ban
// requirement. If this server is ever scaled to multiple instances, this
// Map would need to move to Redis - out of scope for now.

// Shared by the LiveKit token endpoint and the `room:join` socket handler -
// both enforce this same limit (the host is exempt in both places, so an
// owner is never locked out of their own room).
export const MAX_ROOM_CAPACITY = 50;

export interface ViewerState {
	userId: string;
	name: string;
	socketId: string;
	isMuted: boolean; // chat-mute only, never affects mic/cam
	isGuest: boolean;
}

interface RoomState {
	hostUserId: string | null;
	viewers: Map<string, ViewerState>; // keyed by userId
	guestRequests: Map<string, { userId: string; name: string }>; // keyed by userId
}

class RoomStateManager {
	private rooms = new Map<string, RoomState>();

	private getOrCreateRoom(roomName: string): RoomState {
		let room = this.rooms.get(roomName);
		if (!room) {
			room = { hostUserId: null, viewers: new Map(), guestRequests: new Map() };
			this.rooms.set(roomName, room);
		}
		return room;
	}

	/** Registers a participant as present in the room. Sets the host if this
	 * is the first participant to join with role "host". */
	join(params: {
		roomName: string;
		userId: string;
		name: string;
		socketId: string;
		role: "host" | "viewer" | "guest";
	}): ViewerState {
		const { roomName, userId, name, socketId, role } = params;
		const room = this.getOrCreateRoom(roomName);

		if (role === "host" && room.hostUserId === null) {
			room.hostUserId = userId;
		}

		const existing = room.viewers.get(userId);
		const viewer: ViewerState = {
			userId,
			name,
			socketId,
			isMuted: existing?.isMuted ?? false,
			isGuest: existing?.isGuest ?? role === "guest",
		};
		room.viewers.set(userId, viewer);
		room.guestRequests.delete(userId);
		return viewer;
	}

	leave(roomName: string, userId: string): void {
		const room = this.rooms.get(roomName);
		if (!room) return;

		room.viewers.delete(userId);
		room.guestRequests.delete(userId);

		if (room.viewers.size === 0) {
			this.rooms.delete(roomName);
		}
	}

	/** Finds which room/userId a disconnecting socket belonged to. */
	findBySocketId(socketId: string): { roomName: string; userId: string } | null {
		for (const [roomName, room] of this.rooms) {
			for (const viewer of room.viewers.values()) {
				if (viewer.socketId === socketId) {
					return { roomName, userId: viewer.userId };
				}
			}
		}
		return null;
	}

	isHost(roomName: string, userId: string): boolean {
		return this.rooms.get(roomName)?.hostUserId === userId;
	}

	getHostUserId(roomName: string): string | null {
		return this.rooms.get(roomName)?.hostUserId ?? null;
	}

	/** Total connected participants (host + viewers + guests) - used for the
	 * 50-person room capacity check in both the LiveKit token endpoint and
	 * the `room:join` socket handler. */
	getParticipantCount(roomName: string): number {
		return this.rooms.get(roomName)?.viewers.size ?? 0;
	}

	getViewer(roomName: string, userId: string): ViewerState | undefined {
		return this.rooms.get(roomName)?.viewers.get(userId);
	}

	/** Viewer list for the host's moderation panel - excludes the host. */
	listViewers(roomName: string): ViewerState[] {
		const room = this.rooms.get(roomName);
		if (!room) return [];
		return Array.from(room.viewers.values()).filter(
			(v) => v.userId !== room.hostUserId
		);
	}

	setMuted(roomName: string, userId: string, isMuted: boolean): void {
		const viewer = this.getViewer(roomName, userId);
		if (viewer) viewer.isMuted = isMuted;
	}

	setGuest(roomName: string, userId: string, isGuest: boolean): void {
		const viewer = this.getViewer(roomName, userId);
		if (viewer) viewer.isGuest = isGuest;
	}

	addGuestRequest(roomName: string, userId: string, name: string): void {
		const room = this.getOrCreateRoom(roomName);
		room.guestRequests.set(userId, { userId, name });
	}

	removeGuestRequest(roomName: string, userId: string): void {
		this.rooms.get(roomName)?.guestRequests.delete(userId);
	}

	listGuestRequests(roomName: string): { userId: string; name: string }[] {
		const room = this.rooms.get(roomName);
		return room ? Array.from(room.guestRequests.values()) : [];
	}
}

// Single shared instance for the whole process.
export const roomStateManager = new RoomStateManager();
