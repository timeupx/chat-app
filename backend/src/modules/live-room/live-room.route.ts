import express from "express";
import auth from "../../middleware/auth";
import { uploadRoomImage } from "../../middleware/upload";
import validateRequest from "../../middleware/validateRequest";
import { LiveRoomControllers } from "./live-room.controller";
import { CreateLiveRoomSchema } from "./live-room.validation";

const router = express.Router();

// Api prefix /api/live-rooms

// Upload a room image (multipart/form-data, field name "image") -
// CreateLiveRoomScreen calls this BEFORE creating the room itself, then
// includes the returned URL as `roomImage` in the create-room payload.
router.post("/upload-image", auth("ADMIN", "USER"), uploadRoomImage, LiveRoomControllers.uploadImage);

// Create a room (does not go live automatically - see /go-live below).
router.post(
	"/",
	validateRequest(CreateLiveRoomSchema),
	auth("ADMIN", "USER"),
	LiveRoomControllers.createRoom
);

// List all rooms for the Bigo-style grid.
router.get("/", auth("ADMIN", "USER"), LiveRoomControllers.listRooms);

// Room detail - includes the server-computed `isHost` flag the Flutter
// app uses to decide whether to render the "GO LIVE" button.
router.get("/:id", auth("ADMIN", "USER"), LiveRoomControllers.getRoomDetail);

// Host-only: flip the room live/offline.
router.patch("/:id/go-live", auth("ADMIN", "USER"), LiveRoomControllers.goLive);
router.patch("/:id/end-live", auth("ADMIN", "USER"), LiveRoomControllers.endLive);

// Last 50 chat messages for the room.
router.get("/:id/messages", auth("ADMIN", "USER"), LiveRoomControllers.getMessages);

export const LiveRoomRoutes = router;
