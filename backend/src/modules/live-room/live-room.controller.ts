import { JwtPayload } from "jsonwebtoken";
import ApiError from "../../utils/apiError";
import catchAsync from "../../utils/catchAsync";
import sendResponse from "../../utils/sendResponse";
import { LiveRoomService } from "./live-room.service";
import { CreateLiveRoomSchema } from "./live-room.validation";

const createRoom = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	// Re-parse so Zod defaults (is18Plus / roomRules) are applied — the
	// validateRequest middleware only checks the shape and does not write
	// defaults back onto req.body.
	const payload = CreateLiveRoomSchema.parse(req.body);
	const room = await LiveRoomService.createRoom(userId, payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Room created successfully!",
		data: room,
	});
});

const listRooms = catchAsync(async (req, res) => {
	const rooms = await LiveRoomService.listRooms();

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Rooms retrieved successfully!",
		data: rooms,
	});
});

const getRoomDetail = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	const room = await LiveRoomService.getRoomDetail(req.params.id, userId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Room retrieved successfully!",
		data: room,
	});
});

const goLive = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	const room = await LiveRoomService.setLive(req.params.id, userId, true);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "You are now live!",
		data: room,
	});
});

const endLive = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	// Intentional host exit deletes the room + chat (not just isLive=false).
	const result = await LiveRoomService.deleteRoom(req.params.id, userId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Live room deleted",
		data: result,
	});
});

const getMessages = catchAsync(async (req, res) => {
	const messages = await LiveRoomService.getMessages(req.params.id);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Messages retrieved successfully!",
		data: messages,
	});
});

const uploadImage = catchAsync(async (req, res) => {
	if (!req.file) {
		throw new ApiError(400, "No image file uploaded");
	}

	const url = `${req.protocol}://${req.get("host")}/uploads/rooms/${req.file.filename}`;

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Image uploaded successfully!",
		data: { url },
	});
});

export const LiveRoomControllers = {
	createRoom,
	listRooms,
	getRoomDetail,
	goLive,
	endLive,
	getMessages,
	uploadImage,
};
