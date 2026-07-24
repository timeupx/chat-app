import { Server as HttpServer } from "http";
import { Server } from "socket.io";
import { socketAuthMiddleware } from "./socketAuth";
import { registerRoomSocketHandlers } from "./roomSocket";
import { setIO } from "./ioInstance";

// Mirrors the Express CORS policy in app.ts: named production origins plus
// any http://localhost:<port> for local Flutter Web dev.
const allowedOrigins = [
	"http://localhost:3000",
	"https://express-nextjs-dashboard-starter.vercel.app",
];

function isOriginAllowed(origin: string | undefined): boolean {
	if (!origin) return true;
	if (allowedOrigins.includes(origin)) return true;
	return /^http:\/\/localhost:\d+$/.test(origin);
}

export function initSocket(httpServer: HttpServer): Server {
	const io = new Server(httpServer, {
		cors: {
			origin: (origin, callback) => {
				if (isOriginAllowed(origin)) return callback(null, true);
				callback(new Error(`CORS blocked for origin: ${origin}`));
			},
			credentials: true,
		},
	});

	io.use(socketAuthMiddleware);

	io.on("connection", (socket) => {
		registerRoomSocketHandlers(io, socket);
	});

	setIO(io);
	return io;
}
