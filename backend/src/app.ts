import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import bodyParser from "body-parser";
import cookieParser from "cookie-parser";

import { globalErrorHandler } from "./middleware/globalErrorHandler";
import { AuthRoutes } from "./modules/auth/auth.route";
import { UserRoutes } from "./modules/user/user.route";
import { PageRoutes } from "./modules/page/page.route";
import { SystemSettingsRoute } from "./modules/system-settings/system.route";
import { ContactRoutes } from "./modules/contact/contact.route";

dotenv.config();

const app = express();

// Cors policy and middlewares
app.use(
	cors({
		origin: [
			"http://localhost:3000",
			"https://express-nextjs-dashboard-starter.vercel.app",
		],
		credentials: true,
	})
);
app.use(express.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(cookieParser());

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
