import express from "express";
import { UserControllers } from "./user.controller";
import validateRequest from "../../middleware/validateRequest";
import { UpdateUserSchema } from "./user.validation";
import auth from "../../middleware/auth";
import { CreateUserSchema } from "../auth/auth.validation";
const router = express.Router();
// Api endpoint prefix /api/user

// Create user by admin
router.post(
	"/create",
	validateRequest(CreateUserSchema),
	UserControllers.createUser
);
// profile
router.get("/profile", auth("ADMIN", "USER"), UserControllers.myProfile);

// update profile by user
router.patch(
	"/profile",
	auth("ADMIN", "USER"),
	validateRequest(UpdateUserSchema),
	UserControllers.updateProfile
);

// Delete profile by user
router.delete("/profile", auth("ADMIN", "USER"), UserControllers.deleteProfile);

// Get all user
router.get("/", auth("ADMIN"), UserControllers.getAllUsers);

// Get user by id
router.get("/:id", auth("ADMIN"), UserControllers.getUserById);

// Update user
router.patch(
	"/:id",
	auth("ADMIN"),
	validateRequest(UpdateUserSchema),
	UserControllers.updateUser
);

// Delete user
router.delete("/:id", auth("ADMIN"), UserControllers.deleteUsers);

export const UserRoutes = router;
