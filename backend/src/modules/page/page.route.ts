import express from "express";
import validateRequest from "../../middleware/validateRequest";
import { CreatePageSchema } from "./page.validation";
import auth from "../../middleware/auth";
import { PageController } from "./page.controller";

const router = express.Router();

// Create or update page
router.patch(
	"/",
	validateRequest(CreatePageSchema),
	auth("ADMIN", "MERCHANT", "STAFF"),
	PageController.handleCreateOrUpdatePage
);

// Get all pages
router.get(
	"/",
	auth("ADMIN", "MERCHANT", "STAFF"),
	PageController.handleGetAllPages
);

// Get page by slug
router.get(
	"/:slug",
	auth("ADMIN", "MERCHANT", "STAFF"),
	PageController.handleGetPageBySlug
);
export const PageRoutes = router;
