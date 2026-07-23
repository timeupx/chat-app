import express from "express";
import validateRequest from "../../middleware/validateRequest";
import { StoreContactMessageSchema } from "./contact.validation";
import { StoreMessageControllers } from "./contact.controller";
import auth from "../../middleware/auth";
const router = express.Router();

// Create message
router.post(
	"/",
	validateRequest(StoreContactMessageSchema),
	StoreMessageControllers.handleCreateStoreContactMessage
);

// Get all messages
router.get("/", auth("ADMIN"), StoreMessageControllers.handleGetAllMessages);

// Get individual message
router.get("/:id", auth("ADMIN"), StoreMessageControllers.handleGetMessage);

// Mark as read
router.patch(
	"/:id/read",
	auth("ADMIN"),
	StoreMessageControllers.handleMarkMessageAsRead
);

// Delete message
router.delete(
	"/:id/delete",
	auth("ADMIN"),
	StoreMessageControllers.handleDeleteContactMessage
);

export const ContactRoutes = router;
