import { Request, Response, NextFunction } from "express";
import { ZodError } from "zod";
import { JsonWebTokenError, TokenExpiredError } from "jsonwebtoken";
import { MulterError } from "multer";
import sendResponse from "../utils/sendResponse";
import { Prisma } from "../../generated/prisma";
import ApiError from "../utils/apiError";

export const globalErrorHandler = (
	err: unknown,
	req: Request,
	res: Response,
	next: NextFunction
): void => {
	console.error(err);

	// Zod validation error
	if (err instanceof ZodError) {
		const messages = err.errors.map((e) => `${e.path.join(".")}: ${e.message}`);
		sendResponse(res, {
			statusCode: 400,
			success: false,
			message: "Validation error",
			data: messages.join(", "),
		});
		return;
	}

	// Prisma validation error
	if (err instanceof Prisma.PrismaClientValidationError) {
		sendResponse(res, {
			statusCode: 400,
			success: false,
			message: "Prisma validation error",
			data: err.message,
		});
		return;
	}

	// Duplicate value error
	if (err instanceof Prisma.PrismaClientKnownRequestError) {
		let message = "Database error";

		if (err.code === "P2002") {
			message = "Duplicate field value entered";
		}

		sendResponse(res, {
			statusCode: 400,
			success: false,
			message,
			data: err.message,
		});
		return;
	}

	// JWT errors
	if (err instanceof JsonWebTokenError) {
		sendResponse(res, {
			statusCode: 401,
			success: false,
			message: "Invalid token",
			data: null,
		});
		return;
	}

	if (err instanceof TokenExpiredError) {
		sendResponse(res, {
			statusCode: 401,
			success: false,
			message: "Token expired",
			data: null,
		});
		return;
	}

	// Multer upload errors (file too large, too many files, ...)
	if (err instanceof MulterError) {
		sendResponse(res, {
			statusCode: 400,
			success: false,
			message: err.code === "LIMIT_FILE_SIZE" ? "Image must be 5MB or smaller" : err.message,
			data: null,
		});
		return;
	}

	// Custom ApiError
	if (err instanceof ApiError) {
		sendResponse(res, {
			statusCode: err.statusCode,
			success: false,
			message: err.message,
			data: null,
		});
		return;
	}
	// Default server error
	sendResponse(res, {
		statusCode: 500,
		success: false,
		message: "Server Error",
		data:
			process.env.NODE_ENV === "development" && err instanceof Error
				? err.message
				: "Something went wrong",
	});
};
