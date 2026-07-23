import db from "../../config/prisma";
import ApiError from "../../utils/apiError";
import excludeFields from "../../utils/excludeFields";
import { TUser } from "../auth/auth.validation";
import { TUpdateUser } from "./user.validation";
import bcrypt from "bcrypt";

// Create user by admin
const createUser = async (payload: TUser) => {
	const existingUser = await db.user.findUnique({
		where: {
			email: payload.email,
		},
	});

	if (existingUser) {
		throw new ApiError(409, "User with this email or phone already exists");
	}

	// Hash the password
	const salt = await bcrypt.genSalt(10);
	const hashedPassword = await bcrypt.hash(payload.password, salt);

	const user = await db.user.create({
		data: {
			...payload,
			password: hashedPassword,
			status: "ACTIVE",
			phoneVerified: true,
			emailVerified: true,
		},
		select: {
			id: true,
			name: true,
			email: true,
			phone: true,
			role: true,
			status: true,
			emailVerified: true,
			phoneVerified: true,
			mfaEnabled: true,
		},
	});

	return user;
};
// Get all users
const getAllUsers = async () => {
	const result = await db.user.findMany({ where: { isDeleted: false } });
	const users = result.map((user) => excludeFields(user, ["password"]));

	return users;
};

// Get user by id
const getUserById = async (id: string) => {
	const result = await db.user.findUnique({
		where: { id },
	});
	const user = excludeFields(result!, ["password"]);

	return user;
};

// Update user
const updateUser = async (id: string, payload: TUpdateUser) => {
	const result = await db.user.update({
		where: { id },
		data: {
			...payload,
		},
	});
	const user = excludeFields(result!, ["password"]);

	return user;
};

const deleteUser = async (id: string) => {
	const result = await db.user.update({
		where: { id },
		data: { status: "INACTIVE", isDeleted: true },
	});
	return result;
};

const myProfile = async (userId: string) => {
	const result = await db.user.findUnique({
		where: { id: userId },
	});
	const user = excludeFields(result!, ["password"]);

	return user;
};

const updateProfile = async (userId: string, payload: TUpdateUser) => {
	const result = await db.user.update({
		where: { id: userId },
		data: {
			...payload,
		},
	});
	const user = excludeFields(result!, ["password"]);

	return user;
};

const deleteProfile = async (userId: string, password: string) => {
	const user = await db.user.findUnique({ where: { id: userId } });

	if (!user) {
		throw new ApiError(404, "User not found");
	}

	const passwordMatches = await bcrypt.compare(password, user.password);
	if (!passwordMatches) throw new ApiError(401, "Incorrect password");

	await db.user.update({
		where: { id: userId },
		data: {
			isDeleted: true,
		},
	});

	return;
};
export const UserServices = {
	getAllUsers,
	getUserById,
	updateUser,
	deleteUser,
	myProfile,
	updateProfile,
	createUser,
	deleteProfile,
};
