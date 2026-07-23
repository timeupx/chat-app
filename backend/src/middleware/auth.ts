import jwt, { JwtPayload } from "jsonwebtoken";
import catchAsync from "../utils/catchAsync";
import db from "../config/prisma";
import ApiError from "../utils/apiError";

const auth = (...userRoles: ("ADMIN" | "USER")[]) => {
	return catchAsync(async (req, res, next) => {
		const token = req.headers.authorization;
		if (!token) {
			throw new ApiError(404, "Token not found");
		}

		const decoded = jwt.verify(
			token,
			process.env.JWT_ACCESS_SECRET as string
		) as JwtPayload;

		if (!decoded) {
			throw new ApiError(401, "Invalid token");
		}

		const { userId, role } = decoded;

		// check if user is exist
		const user = await db.user.findUnique({
			where: { id: userId },
		});

		if (!user) {
			throw new ApiError(404, "User not found");
		}

		// check user status

		if (user.status !== "ACTIVE") {
			throw new ApiError(403, "User account is not active");
		}
		if (user.isDeleted) {
			throw new ApiError(404, "User not found");
		}

		// Check password update time
		if (
			user.passChangedAt &&
			new Date(user.passChangedAt) > new Date(decoded.iat! * 1000)
		) {
			throw new ApiError(401, "Token expired. Please login again");
		}

		// Check user role have access to the resource or not
		if (userRoles && !userRoles.includes(role)) {
			throw new ApiError(403, "Access unauthorized");
		}

		req.user = decoded as JwtPayload;

		next();
	});
};

export default auth;
