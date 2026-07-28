// In-memory state for "live session" concerns that do NOT need to survive
// a server restart: who is currently in the room, who's chat-muted, who's a
// guest, slot occupancy, and pending guest requests. This is intentionally
// NOT persisted to Postgres - only bans are (see room-ban.service.ts) since
// bans are the one thing that must survive a reconnect/restart per the
// strict-ban requirement. If this server is ever scaled to multiple
// instances, this Map would need to move to Redis - out of scope for now.

// Shared by the LiveKit token endpoint and the `room:join` socket handler -
// both enforce this same limit (the host is exempt in both places, so an
// owner is never locked out of their own room).
export const MAX_ROOM_CAPACITY = 50;

/** Fallback when a room's slotCount hasn't been loaded from the DB yet. */
export const DEFAULT_SLOT_COUNT = 6;

export interface ViewerState {
	userId: string;
	name: string;
	socketId: string;
	isMuted: boolean; // chat-mute only, never affects mic/cam
	isGuest: boolean;
	/** 1 = host, 2..slotCount = guests, null = regular viewer (not on stage). */
	slotNumber: number | null;
}

/** Client-side beauty filter payload broadcast to everyone in the room. */
export interface RoomFilterState {
	beauty: number;
	brightness: number;
	contrast: number;
	saturation: number;
	beautyModeEnabled: boolean;
	preset: string;
}

interface RoomState {
	hostUserId: string | null;
	/** Total seats on stage (3 / 6 / 9). Host always takes seat 1. */
	slotCount: number;
	viewers: Map<string, ViewerState>; // keyed by userId
	guestRequests: Map<string, { userId: string; name: string }>; // keyed by userId
	/**
	 * Live beauty filters keyed by userId (host + co-host guests).
	 * Every client mirrors the matching user's tile with this look —
	 * LiveKit still publishes the raw camera track.
	 */
	participantFilters: Map<string, RoomFilterState>;
}

class RoomStateManager {
	private rooms = new Map<string, RoomState>();

	private getOrCreateRoom(roomName: string): RoomState {
		let room = this.rooms.get(roomName);
		if (!room) {
			room = {
				hostUserId: null,
				slotCount: DEFAULT_SLOT_COUNT,
				viewers: new Map(),
				guestRequests: new Map(),
				participantFilters: new Map(),
			};
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

		if (role === "host" && (room.hostUserId === null || room.hostUserId === userId)) {
			room.hostUserId = userId;
		}

		const existing = room.viewers.get(userId);
		const isHost = role === "host" || room.hostUserId === userId;
		const isGuest = existing?.isGuest ?? role === "guest";

		// Preserve an existing seat across reconnect; host always lands on 1.
		let slotNumber = existing?.slotNumber ?? null;
		if (isHost) {
			slotNumber = 1;
		}

		const viewer: ViewerState = {
			userId,
			name,
			socketId,
			isMuted: existing?.isMuted ?? false,
			isGuest: isHost ? false : isGuest,
			slotNumber,
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

	/** True when the given user currently has a socket in this room. */
	isUserPresent(roomName: string, userId: string): boolean {
		return this.rooms.get(roomName)?.viewers.has(userId) ?? false;
	}

	/** True when the room's host is currently connected (on stage / in socket). */
	isHostOnline(roomName: string): boolean {
		const room = this.rooms.get(roomName);
		if (!room?.hostUserId) return false;
		return room.viewers.has(room.hostUserId);
	}

	setSlotCount(roomName: string, slotCount: number): void {
		const room = this.getOrCreateRoom(roomName);
		const normalized = [3, 6, 9].includes(slotCount) ? slotCount : DEFAULT_SLOT_COUNT;
		room.slotCount = normalized;
	}

	getSlotCount(roomName: string): number {
		return this.rooms.get(roomName)?.slotCount ?? DEFAULT_SLOT_COUNT;
	}

	/** Guest seats available = total seats minus the host seat. */
	getMaxGuests(roomName: string): number {
		return Math.max(0, this.getSlotCount(roomName) - 1);
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
		return Array.from(room.viewers.values()).filter((v) => v.userId !== room.hostUserId);
	}

	/** Everyone currently on stage (host + guests), ordered by seat number. */
	listOccupiedSlots(roomName: string): ViewerState[] {
		const room = this.rooms.get(roomName);
		if (!room) return [];
		return Array.from(room.viewers.values())
			.filter((v) => v.slotNumber != null)
			.sort((a, b) => (a.slotNumber ?? 0) - (b.slotNumber ?? 0));
	}

	setMuted(roomName: string, userId: string, isMuted: boolean): void {
		const viewer = this.getViewer(roomName, userId);
		if (viewer) viewer.isMuted = isMuted;
	}

	setGuest(roomName: string, userId: string, isGuest: boolean): void {
		const viewer = this.getViewer(roomName, userId);
		if (!viewer) return;
		viewer.isGuest = isGuest;
		if (!isGuest && viewer.slotNumber !== 1) {
			viewer.slotNumber = null;
		}
	}

	/**
	 * Assigns a guest seat in 2..slotCount. Prefers [preferredSlot] when free,
	 * otherwise the next open seat. Returns the seat, or null if the stage is full.
	 */
	assignGuestSlot(
		roomName: string,
		userId: string,
		preferredSlot?: number | null
	): number | null {
		const room = this.getOrCreateRoom(roomName);
		const viewer = room.viewers.get(userId);
		if (!viewer) return null;

		if (viewer.slotNumber != null && viewer.slotNumber > 1) {
			viewer.isGuest = true;
			return viewer.slotNumber;
		}

		const occupied = new Set(
			Array.from(room.viewers.values())
				.map((v) => v.slotNumber)
				.filter((n): n is number => n != null)
		);

		if (
			preferredSlot != null &&
			preferredSlot >= 2 &&
			preferredSlot <= room.slotCount &&
			!occupied.has(preferredSlot)
		) {
			viewer.isGuest = true;
			viewer.slotNumber = preferredSlot;
			return preferredSlot;
		}

		for (let seat = 2; seat <= room.slotCount; seat++) {
			if (!occupied.has(seat)) {
				viewer.isGuest = true;
				viewer.slotNumber = seat;
				return seat;
			}
		}
		return null;
	}

	/** Clears a guest's seat (e.g. demote / leave). Host seat is never freed this way. */
	freeSlot(roomName: string, userId: string): void {
		const viewer = this.getViewer(roomName, userId);
		if (!viewer) return;
		if (viewer.slotNumber === 1) return;
		viewer.slotNumber = null;
		viewer.isGuest = false;
		// Drop their beauty look so late joiners don't keep a stale filter.
		this.rooms.get(roomName)?.participantFilters.delete(userId);
	}

	/** How many viewers are currently co-hosting - see [getMaxGuests]. */
	countGuests(roomName: string): number {
		const room = this.rooms.get(roomName);
		if (!room) return 0;
		let count = 0;
		for (const viewer of room.viewers.values()) {
			if (viewer.isGuest) count++;
		}
		return count;
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

	/** Host convenience — stores under the room host's userId. */
	setVideoFilter(roomName: string, filter: RoomFilterState | null): void {
		const room = this.getOrCreateRoom(roomName);
		const hostId = room.hostUserId;
		if (!hostId) return;
		if (filter == null) {
			room.participantFilters.delete(hostId);
		} else {
			room.participantFilters.set(hostId, filter);
		}
	}

	getVideoFilter(roomName: string): RoomFilterState | null {
		const room = this.rooms.get(roomName);
		if (!room?.hostUserId) return null;
		return room.participantFilters.get(room.hostUserId) ?? null;
	}

	setParticipantFilter(
		roomName: string,
		userId: string,
		filter: RoomFilterState | null
	): void {
		const room = this.getOrCreateRoom(roomName);
		if (filter == null) {
			room.participantFilters.delete(userId);
		} else {
			room.participantFilters.set(userId, filter);
		}
	}

	getParticipantFilter(
		roomName: string,
		userId: string
	): RoomFilterState | null {
		return this.rooms.get(roomName)?.participantFilters.get(userId) ?? null;
	}

	listParticipantFilters(
		roomName: string
	): { userId: string; filter: RoomFilterState }[] {
		const room = this.rooms.get(roomName);
		if (!room) return [];
		return Array.from(room.participantFilters.entries()).map(
			([userId, filter]) => ({ userId, filter })
		);
	}

	/** Drop in-memory state for a room (after host deletes it). */
	destroyRoom(roomName: string): void {
		this.rooms.delete(roomName);
	}
}

// Single shared instance for the whole process.
export const roomStateManager = new RoomStateManager();
