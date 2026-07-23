import db from "../../config/prisma";
import ApiError from "../../utils/apiError";
import { sendMail } from "../../utils/sendMails";
import { TStoreContactMessage } from "./contact.validation";

// Create conact message
const createMessage = async (payload: TStoreContactMessage) => {
	const system = await db.systemSettings.findFirst({
		include: { contact: true },
	});

	const result = await db.contactMessage.create({
		data: payload,
	});

	// Send notification to store owner
	await sendMail.contactNotificationEmail(
		system?.contact?.email!,
		payload.name,
		payload.phone,
		payload.email,
		payload.subject,
		payload.message,
		"Contact Form"
	);

	// Send confirmation email to sender
	await sendMail.contactConfirmationEmail(
		payload.email,
		payload.name,
		payload.subject,
		"Contact form"
	);
	return result;
};

// Get all messages
const getAllMessages = async (storeId: string) => {
	const result = await db.contactMessage.findMany({
		where: { isDeleted: false },
	});
	return result;
};

// Get individual message
const getMessage = async (id: string, storeId: string) => {
	const result = await db.contactMessage.findUnique({
		where: { id, isDeleted: false },
	});

	return result;
};
// Mark message as read
const markMessageAsRead = async (id: string, storeId: string) => {
	const result = await db.contactMessage.update({
		where: { id },
		data: { isRead: true },
	});

	return result;
};

// Delete message
const deleteContactMessage = async (id: string, storeId: string) => {
	const result = await db.contactMessage.update({
		where: { id },
		data: { isDeleted: true },
	});

	return result;
};

export const StoreMessageServices = {
	createMessage,
	markMessageAsRead,
	deleteContactMessage,
	getAllMessages,
	getMessage,
};
