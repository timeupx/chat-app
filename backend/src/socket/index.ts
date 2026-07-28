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
	if (/^http:\/\/localhost:\d+$/.test(origin)) return true;
	// Same-Wi‑Fi LAN testing (phone / another laptop hitting this Mac).
	if (/^http:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin)) return true;
	if (/^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin)) return true;
	return false;
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
