import { Socket } from "socket.io";
import jwt, { JwtPayload } from "jsonwebtoken";

export interface SocketUser {
	userId: string;
	name: string;
	role: "ADMIN" | "USER";
}

// Augment the data bag every connected socket carries so the rest of the
// socket layer can read `socket.data.user` with proper types.
declare module "socket.io" {
	interface SocketData {
		user: SocketUser;
	}
}

/**
 * Socket.io connection middleware: verifies the same access token used for
 * REST requests (sent via the client's `auth: { token }` handshake option)
 * and attaches the decoded identity to `socket.data.user`.
 *
 * Every room-moderation action (ban, mute, warn, invite, ...) trusts
 * `socket.data.user.userId` as the authoritative identity - never a
 * client-supplied field - so a user can't spoof another participant.
 */
export const socketAuthMiddleware = (
	socket: Socket,
	next: (err?: Error) => void
) => {
	try {
		const token = socket.handshake.auth?.token as string | undefined;
		if (!token) {
			return next(new Error("Authentication token missing"));
		}

		const decoded = jwt.verify(
			token,
			process.env.JWT_ACCESS_SECRET as string
		) as JwtPayload;

		socket.data.user = {
			userId: decoded.userId,
			name: decoded.name,
			role: decoded.role,
		};

		next();
	} catch {
		next(new Error("Invalid or expired token"));
	}
};
