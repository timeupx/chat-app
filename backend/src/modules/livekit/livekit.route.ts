import express from "express";
import auth from "../../middleware/auth";
import validateRequest from "../../middleware/validateRequest";
import { LiveKitControllers } from "./livekit.controller";
import { CreateLiveKitTokenSchema } from "./livekit.validation";

const router = express.Router();

// Api prefix /api/livekit

// Mint a LiveKit room-access token for the logged-in user (host or viewer).
router.post(
	"/token",
	validateRequest(CreateLiveKitTokenSchema),
	auth("ADMIN", "USER"),
	LiveKitControllers.createToken
);

export const LiveKitRoutes = router;
