import { JwtPayload } from "jsonwebtoken";
import catchAsync from "../../utils/catchAsync";
import sendResponse from "../../utils/sendResponse";
import { StoreMessageServices } from "./contact.service";

// Create message
const handleCreateStoreContactMessage = catchAsync(async (req, res) => {
	// const host = req.hostname;
	const result = await StoreMessageServices.createMessage(req.body);

	sendResponse(res, {
		statusCode: 201,
		success: true,
		message: "Message sent successfully!",
		data: result,
	});
});

// get all messages
const handleGetAllMessages = catchAsync(async (req, res) => {
	const { storeId } = req.user as JwtPayload;

	const result = await StoreMessageServices.getAllMessages(storeId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Messages retrived successfully",
		data: result,
	});
});

// Get individual message
const handleGetMessage = catchAsync(async (req, res) => {
	const id = req.params.id;
	const { storeId } = req.user as JwtPayload;

	const result = await StoreMessageServices.getMessage(id, storeId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Message retrived successfully",
		data: result,
	});
});
// Mark as read
const handleMarkMessageAsRead = catchAsync(async (req, res) => {
	const id = req.params.id;
	const { storeId } = req.user as JwtPayload;

	const result = await StoreMessageServices.markMessageAsRead(id, storeId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Message marked as read",
		data: result,
	});
});

// Delete message
const handleDeleteContactMessage = catchAsync(async (req, res) => {
	const id = req.params.id;
	const { storeId } = req.user as JwtPayload;

	const result = await StoreMessageServices.deleteContactMessage(id, storeId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Message deleted successfully!",
		data: result,
	});
});

export const StoreMessageControllers = {
	handleCreateStoreContactMessage,
	handleDeleteContactMessage,
	handleMarkMessageAsRead,
	handleGetAllMessages,
	handleGetMessage,
};
