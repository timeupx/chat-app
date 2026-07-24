import { JwtPayload } from "jsonwebtoken";
import catchAsync from "../../utils/catchAsync";
import sendResponse from "../../utils/sendResponse";
import { LiveKitServices } from "./livekit.service";

const createToken = catchAsync(async (req, res) => {
	const { roomName, role } = req.body;
	const { userId, name } = req.user as JwtPayload;

	const token = await LiveKitServices.createToken({ roomName, role, userId, name });

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "LiveKit token generated successfully!",
		data: { token },
	});
});

export const LiveKitControllers = { createToken };
