import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import bodyParser from "body-parser";
import cookieParser from "cookie-parser";
import path from "path";

import { globalErrorHandler } from "./middleware/globalErrorHandler";
import { AuthRoutes } from "./modules/auth/auth.route";
import { UserRoutes } from "./modules/user/user.route";
import { PageRoutes } from "./modules/page/page.route";
import { SystemSettingsRoute } from "./modules/system-settings/system.route";
import { ContactRoutes } from "./modules/contact/contact.route";
import { LiveKitRoutes } from "./modules/livekit/livekit.route";
import { LiveRoomRoutes } from "./modules/live-room/live-room.route";

dotenv.config();

const app = express();

// Cors policy and middlewares
const allowedOrigins = [
	"http://localhost:3000",
	"https://express-nextjs-dashboard-starter.vercel.app",
];

app.use(
	cors({
		origin: (origin, callback) => {
			// No Origin header (curl, mobile apps, server-to-server) - allow.
			if (!origin) return callback(null, true);

			// Any http://localhost:<port> is allowed so Flutter Web (which
			// picks a random dev port each run) always works locally.
			const isLocalDevOrigin = /^http:\/\/localhost:\d+$/.test(origin);
			// Same-Wi‑Fi LAN origins (physical devices / other machines).
			const isLanOrigin =
				/^http:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin) ||
				/^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin);

			if (allowedOrigins.includes(origin) || isLocalDevOrigin || isLanOrigin) {
				return callback(null, true);
			}

			return callback(new Error(`CORS blocked for origin: ${origin}`));
		},
		credentials: true,
	})
);
app.use(express.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(cookieParser());

// Serves uploaded room images back out, e.g. GET /uploads/rooms/<file>.
app.use("/uploads", express.static(path.join(__dirname, "../uploads")));

// Health route
app.get("/", (req, res) => {
	res.send("Server is running..");
});

// Auth Routes
app.use("/api/auth", AuthRoutes);

// User routes
app.use("/api/user", UserRoutes);

// Page routes
app.use("/api/page", PageRoutes);

// System settings
app.use("/api/system-settings", SystemSettingsRoute);

// Contact routes
app.use("/api/contact", ContactRoutes);

// LiveKit routes
app.use("/api/livekit", LiveKitRoutes);

// Live room routes
app.use("/api/live-rooms", LiveRoomRoutes);

// Not found
app.use((req, res, next) => {
	res.status(404).json({
		success: false,
		message: "API endpoint not found.",
	});
});

// Global Error handler
app.use(globalErrorHandler);

export default app;
