import { Server } from "socket.io";

// Holds the single Socket.io server instance so non-socket modules (e.g.
// live-room.service.ts) can emit global broadcasts without importing
// socket/index.ts directly, which would create a circular import
// (index.ts -> roomSocket.ts -> live-room.service.ts -> index.ts).
let io: Server | null = null;

export function setIO(instance: Server): void {
	io = instance;
}

export function getIO(): Server | null {
	return io;
}
