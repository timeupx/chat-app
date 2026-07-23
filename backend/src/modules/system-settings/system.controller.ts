import catchAsync from "../../utils/catchAsync";
import sendResponse from "../../utils/sendResponse";
import { SystemSettingsServices } from "./system.service";

// Get system settings
const getSettingsHandler = catchAsync(async (req, res) => {
	const result = await SystemSettingsServices.getSystemSettings();
	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "System settings retrived successfully!",
		data: result,
	});
});

// Add or update settings
export const upsertSettingsHandler = catchAsync(async (req, res) => {
	const data = req.body;
	const result = await SystemSettingsServices.upsertSystemSettings(data);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Settings updated successfully!",
		data: result,
	});
});

export const SystemSettingsController = {
	upsertSettingsHandler,
	getSettingsHandler,
};
