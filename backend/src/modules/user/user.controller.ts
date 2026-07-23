import { JwtPayload } from "jsonwebtoken";
import catchAsync from "../../utils/catchAsync";
import sendResponse from "../../utils/sendResponse";
import { UserServices } from "./user.service";

// Create user by admin
const createUser = catchAsync(async (req, res) => {
	const payload = req.body;
	const result = await UserServices.createUser(payload);

	sendResponse(res, {
		success: true,
		statusCode: 201,
		message: "User created successfully!",
		data: result,
	});
});
// Get all user
const getAllUsers = catchAsync(async (req, res) => {
	const users = await UserServices.getAllUsers();

	sendResponse(res, {
		success: true,
		statusCode: 200,
		message: "All users retrived successfully!",
		data: users,
	});
});

// Get user by id
const getUserById = catchAsync(async (req, res) => {
	const userId = req.params.id;
	const user = await UserServices.getUserById(userId);
	sendResponse(res, {
		success: true,
		statusCode: 200,
		message: "User retrived successfully!",
		data: user,
	});
});

// Update user
export const updateUser = catchAsync(async (req, res) => {
	const userId = req.params.id;
	const updatedUser = await UserServices.updateUser(userId, req.body);

	sendResponse(res, {
		success: true,
		statusCode: 200,
		message: "User updated successfully!",
		data: updatedUser,
	});
});

// Delete user
const deleteUsers = catchAsync(async (req, res) => {
	const userId = req.params.id;
	const deletedUser = await UserServices.deleteUser(userId);
	sendResponse(res, {
		success: true,
		statusCode: 200,
		message: "User deleted successfully!",
		data: deletedUser,
	});
});

// user profile
const myProfile = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	const profile = await UserServices.myProfile(userId);

	sendResponse(res, {
		success: true,
		statusCode: 200,
		message: "User profile retrived successfully!",
		data: profile,
	});
});

// Update user profile by user

const updateProfile = catchAsync(async (req, res) => {
	const payload = req.body;
	const { userId } = req.user as JwtPayload;

	const result = await UserServices.updateProfile(userId, payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Profile updated successfully",
		data: result,
	});
});

// Delete profile
const deleteProfile = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	const { password } = req.body;
	await UserServices.deleteProfile(userId, password);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Account deleted successfully!",
		data: null,
	});
});

export const UserControllers = {
	getAllUsers,
	getUserById,
	updateUser,
	deleteUsers,
	myProfile,
	updateProfile,
	createUser,
	deleteProfile,
};
