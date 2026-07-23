import express from "express";
import validateRequest from "../../middleware/validateRequest";
import { systemSettingsPatchSchema } from "./system.validation";
import auth from "../../middleware/auth";
import { SystemSettingsController } from "./system.controller";

const router = express.Router();

// Add or update settings
router.patch(
	"/",
	validateRequest(systemSettingsPatchSchema),
	auth("ADMIN"),
	SystemSettingsController.upsertSettingsHandler
);

// Get settings
router.get("/", SystemSettingsController.getSettingsHandler);

export const SystemSettingsRoute = router;
