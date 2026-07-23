import db from "../config/prisma";
import { VerificationCodeType } from "../../generated/prisma";
import { generateVerificationCode } from "./generateOtp";
import { sendSms } from "./sendSms";
import ApiError from "./apiError";

export const generateSmsOtp = async (
	userId: string,
	phone: string,
	type: VerificationCodeType
) => {
	// Check if there is an existing code
	const existingCode = await db.verification.findFirst({
		where: {
			userId,
			type,
			status: {
				not: "USED",
			},
		},
	});

	// Check if the token was issued less than 3 mintures
	if (
		existingCode &&
		Date.now() - new Date(existingCode.issuedAt).getTime() < 3 * 60 * 1000
	) {
		throw new ApiError(429, "Please wait 3 minutes before sending new OTP");
	}

	// Generate verification code
	const code = generateVerificationCode();
	const expiresAt = new Date(Date.now() + 1000 * 60 * 5); // 5 minutes

	await db.verification.create({
		data: {
			userId,
			code,
			type,
			expiresAt,
		},
	});

	// Send OTP via SMS
	await sendSms(phone, `Your Nexweb verification code is ${code}`);
	return;
};
