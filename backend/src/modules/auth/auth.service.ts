import bcrypt from "bcrypt";
import db from "../../config/prisma";
import crypto from "crypto";
import { generateVerificationCode } from "../../utils/generateOtp";
import { sendMail } from "../../utils/sendMails";
import {
	TAddPhoneNumber,
	TChangePassword,
	TEmailVerification,
	TEnableOrDisableMfa,
	TForgotPassword,
	TLogin,
	TMfaVerification,
	TResendOTPSchema,
	TResetPassword,
	TUser,
	TVerifyAuthority,
	TVerifyPhoneNumber,
} from "./auth.validation";
import { createLoginHistory } from "../../utils/createLoginHistory";
import jwt, { JwtPayload } from "jsonwebtoken";
import { DeviceInfo, LocationInfo } from "../../utils/ipLocationInfo";
import { sendSms } from "../../utils/sendSms";
import ApiError from "../../utils/apiError";
import { generateSmsOtp } from "../../utils/generateSmsOTP";
import { VerificationCodeType } from "../../../generated/prisma";

// user registration
const registerUser = async (payload: TUser) => {
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

	// Generate verification code
	const code = generateVerificationCode();
	const expiresAt = new Date(Date.now() + 1000 * 60 * 10); // 10 minutes

	// Create user, profile, and verification code in a single transaction
	const result = await db.$transaction(async (tx) => {
		// Create the user
		const user = await tx.user.create({
			data: {
				...payload,
				password: hashedPassword,
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

		// Create verification record
		await tx.verification.create({
			data: {
				userId: user.id,
				code,
				type: "ACCOUNT_ACTIVATION",
				expiresAt,
			},
		});

		// Return the user data
		return user;
	});

	// Send verification email outside the transaction
	await sendMail.verificationEmail(result.email, code, "Create account");

	return result;
};

// login user
const loginUser = async (
	payload: TLogin,
	ipAddress: string,
	device: DeviceInfo,
	location: LocationInfo | null,
	trustedDeviceToken: string
) => {
	// Security information
	const deviceData = `${device.deviceVendor} ${device.device}`;
	const browserData = `${device.browser} ${device.brwoserVersion} on ${device.os}`;
	const locationData = `${location?.city},${location?.region},${location?.country}`;
	const rawDeviceToken = crypto.randomBytes(32).toString("hex");

	// check if the user exists
	const user = await db.user.findUnique({
		where: {
			email: payload.email,
		},
	});

	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// compare password
	const isMatch = await bcrypt.compare(payload.password, user.password);
	if (!isMatch) {
		await createLoginHistory({
			userId: user.id,
			ipAddress,
			device: deviceData,
			browser: browserData,
			location: locationData,
			successful: false,
		});
		throw new ApiError(401, "Invalid credentials");
	}

	// check if the user is verified
	if (!user.emailVerified) {
		await createLoginHistory({
			userId: user.id,
			ipAddress,
			device: deviceData,
			browser: browserData,
			location: locationData,
			successful: false,
		});
		throw new ApiError(403, "Account not verified");
	}

	// check if the account is active
	if (user.status !== "ACTIVE") {
		await createLoginHistory({
			userId: user.id,
			ipAddress,
			device: deviceData,
			browser: browserData,
			location: locationData,
			successful: false,
		});
		throw new ApiError(
			403,
			`Your account is ${user.status.toLocaleLowerCase()}`
		);
	}
	// check if user is deleted
	if (user.isDeleted) {
		await createLoginHistory({
			userId: user.id,
			ipAddress,
			device: deviceData,
			browser: browserData,
			location: locationData,
			successful: false,
		});
		throw new ApiError(404, "User not found");
	}
	// Check if device is trusted
	let savedDevice;
	if (trustedDeviceToken) {
		savedDevice = await db.trustedDevice.findFirst({
			where: {
				userId: user.id,
				deviceToken: trustedDeviceToken,
				expiresAt: { gt: new Date() },
			},
		});
	}
	// If MFA is enabled and new device, send OTP
	if (user.mfaEnabled && !savedDevice) {
		const code = generateVerificationCode();
		await db.verification.create({
			data: {
				userId: user.id,
				code,
				type: "MFA_AUTH",
				status: "PENDING",
				expiresAt: new Date(Date.now() + 1000 * 60 * 5),
			},
		});

		// Send OTP via SMS
		await sendSms(
			user.phone!,
			`Your Nexweb OTP is ${code}. OTP will expire in 5 minutes`
		);

		// Create a temp JWT for OTP verification
		// const mfaVerifyToken = jwt.sign(
		// 	{ id: user.id, code, step: "MFA_PENDING" },
		// 	process.env.JWT_MFA_SECRET!,
		// 	{ expiresIn: "5m" }
		// );

		// return { mfaVerifyToken, rememberDevice: payload.rememberDevice };
		return { mfaPending: true };
	}

	// Save to trusted device
	if (payload.rememberDevice) {
		await db.trustedDevice.create({
			data: {
				userId: user.id,
				deviceToken: rawDeviceToken,
				ip: ipAddress,
				userAgent: deviceData,
				location: locationData,
				browser: browserData,
				expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30), // 30 days
			},
		});
	}
	// generate access token
	const accessToken = jwt.sign(
		{
			userId: user.id,
			name: user.name,
			role: user.role,
			email: user.email,
			phone: user.phone,
			status: user.status,
		},
		process.env.JWT_ACCESS_SECRET as string,
		{ expiresIn: "1h" }
	);
	// generate refresh token
	const refreshToken = jwt.sign(
		{
			userId: user.id,
			name: user.name,
			role: user.role,
			email: user.email,
			phone: user.phone,
			status: user.status,
		},
		process.env.JWT_REFRESH_SECRET as string,
		{ expiresIn: "30d" }
	);

	await createLoginHistory({
		userId: user.id,
		ipAddress,
		device: deviceData,
		browser: browserData,
		location: locationData,
		successful: true,
	});

	// Send new login alert if device is not saved
	if (!savedDevice) {
		await sendMail.newLoginAlertEmail(
			user.email,
			user.name,
			ipAddress,
			deviceData,
			browserData,
			locationData,
			"Login page"
		);
	}

	return payload.rememberDevice
		? { accessToken, refreshToken, rawDeviceToken }
		: { accessToken, refreshToken };
};

// Verify email
const verifyEmail = async (payload: TEmailVerification) => {
	// check if the user with email exists
	const user = await db.user.findUnique({
		where: { email: payload.email },
	});
	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// find the verification code
	const verificationCode = await db.verification.findFirst({
		where: {
			userId: user.id,
			code: payload.code,
		},
	});
	if (!verificationCode) {
		throw new ApiError(400, "Invalid varification code");
	}

	// if the code has expired
	if (verificationCode.expiresAt < new Date()) {
		throw new ApiError(400, "Verification code expired");
	}

	// if the code is already used
	if (verificationCode.status === "USED") {
		throw new ApiError(400, "Verification code is already used");
	}

	// check varification type
	if (verificationCode.type !== "ACCOUNT_ACTIVATION") {
		throw new ApiError(400, "Invalid activation code");
	}

	// Update user status to verified and verification code to used
	await db.$transaction([
		db.user.update({
			where: { id: user.id },
			data: { emailVerified: true, status: "ACTIVE" },
		}),
		db.verification.update({
			where: { id: verificationCode.id },
			data: { status: "USED", verifiedAt: new Date() },
		}),
	]);

	// send success email
	await sendMail.verificationSuccessEmail(
		user.email,
		user.name,
		"Confirmed account"
	);

	return;
};

// Enable MFA
const enableOrDisableMfa = async (
	userData: JwtPayload,
	payload: TEnableOrDisableMfa
) => {
	// check user
	const user = await db.user.findUnique({ where: { id: userData.userId } });

	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// if user have a phone number
	if (!user.phone) {
		throw new ApiError(404, "User does not have a phone number");
	}

	// if phone number is verified
	if (!user.phoneVerified) {
		throw new ApiError(403, "Phone number is not verified");
	}
	// check if MFA is already enabled
	if (payload.mfaEnabled && user.mfaEnabled) {
		throw new ApiError(409, "MFA is already enabled");
	}
	// enable MFA
	await db.user.update({ where: { id: user.id }, data: { ...payload } });

	// Notify user if MFA Disabled
	if (!payload.mfaEnabled) {
		await sendMail.mfaDisabledEmail(user.email, user.name, "MFA Disabled");
	}
	// Notify user if MFA enabled
	await sendMail.mfaEnabledEmail(user.email, user.name, "MFA Enabled");

	return;
};
// Verify MFA Token
const verifyMfaToken = async (
	payload: TMfaVerification,
	ipAddress: string,
	device: DeviceInfo,
	location: LocationInfo | null
) => {
	// Security information
	const deviceData = `${device.deviceVendor} ${device.device}`;
	const browserData = `${device.browser} ${device.brwoserVersion} on ${device.os}`;
	const locationData = `${location?.city},${location?.region},${location?.country}`;
	const rawDeviceToken = crypto.randomBytes(32).toString("hex");

	// Verify jwt
	// const token = jwt.verify(
	// 	payload.token,
	// 	process.env.JWT_MFA_SECRET!
	// ) as JwtPayload;

	// if (!token) {
	// 	throw new ApiError(401, "Invalid MFA token");
	// }
	const { email, code } = payload;

	// check if the user with id exists
	const user = await db.user.findUnique({
		where: { email },
	});
	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// find the verification code
	const verificationCode = await db.verification.findFirst({
		where: {
			userId: user.id,
			code,
			type: "MFA_AUTH",
		},
	});
	if (!verificationCode) {
		throw new ApiError(401, "Invalid varification code");
	}

	// if the code has expired
	if (verificationCode.expiresAt < new Date()) {
		throw new ApiError(401, "Verification code expired");
	}

	// if the code is already used
	if (verificationCode.status === "USED") {
		throw new ApiError(400, "Verification code is already used");
	}

	// check varification type
	if (verificationCode.type !== "MFA_AUTH") {
		throw new ApiError(401, "Invalid activation code");
	}

	// Update verification code to used
	await db.verification.update({
		where: { id: verificationCode.id },
		data: { status: "USED", verifiedAt: new Date() },
	});

	// Save to trusted device
	if (payload.rememberDevice) {
		await db.trustedDevice.create({
			data: {
				userId: user.id,
				deviceToken: rawDeviceToken,
				ip: ipAddress,
				userAgent: deviceData,
				location: locationData,
				browser: browserData,
				expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30), // 30 days
			},
		});
	}
	// generate access token
	const accessToken = jwt.sign(
		{
			userId: user.id,
			role: user.role,
			email: user.email,
			phone: user.phone,
			status: user.status,
		},
		process.env.JWT_ACCESS_SECRET as string,
		{ expiresIn: "1h" }
	);
	// generate refresh token
	const refreshToken = jwt.sign(
		{
			userId: user.id,
			role: user.role,
			email: user.email,
			phone: user.phone,
			status: user.status,
		},
		process.env.JWT_REFRESH_SECRET as string,
		{ expiresIn: "30d" }
	);

	await createLoginHistory({
		userId: user.id,
		ipAddress,
		device: deviceData,
		browser: browserData,
		location: locationData,
		successful: true,
	});

	await sendMail.newLoginAlertEmail(
		user.email,
		user.name,
		ipAddress,
		deviceData,
		browserData,
		locationData,
		"Login MFA page"
	);

	return payload.rememberDevice
		? { accessToken, refreshToken, rawDeviceToken }
		: { accessToken, refreshToken };
};
// Forgot password
const requestPasswordReset = async (payload: TForgotPassword) => {
	// check if the user exists
	const user = await db.user.findUnique({
		where: {
			email: payload.email,
		},
	});

	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// check if the user is verified
	if (!user.emailVerified) {
		throw new ApiError(403, "Account not verified");
	}

	// check if the account is active
	if (user.status !== "ACTIVE") {
		throw new ApiError(403, "Account not active");
	}

	// Generate verification code
	const code = generateVerificationCode();
	const expiresAt = new Date(Date.now() + 1000 * 60 * 5); // 5 minutes

	// Create verification code
	await db.verification.create({
		data: {
			userId: user.id,
			code,
			type: "PASSWORD_RESET",
			expiresAt: expiresAt,
		},
	});

	// Send verification code
	await sendMail.forgotPasswordEmail(
		user.email,
		user.name,
		code,
		"Forgot password"
	);

	return;
};

// Verify reset otp
const verifyResetCode = async (payload: TEmailVerification) => {
	// check if the user with email exists
	const user = await db.user.findUnique({
		where: { email: payload.email },
	});
	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// find the verification code
	const verificationCode = await db.verification.findFirst({
		where: {
			userId: user.id,
			code: payload.code,
		},
	});
	if (!verificationCode) {
		throw new ApiError(401, "Invalid varification code");
	}

	// if the code has expired
	if (verificationCode.expiresAt < new Date()) {
		throw new ApiError(401, "Verification code expired");
	}

	// if the code is already used
	if (verificationCode.status === "USED") {
		throw new ApiError(400, "Verification code is already used");
	}

	// check varification type
	if (verificationCode.type !== "PASSWORD_RESET") {
		throw new ApiError(401, "Invalid reset code");
	}

	// Update verification code to used
	await db.verification.update({
		where: { id: verificationCode.id },
		data: { status: "USED", verifiedAt: new Date() },
	});

	// Issue reset token
	const resetToken = jwt.sign(
		{ userId: user.id, email: user.email },
		process.env.RESET_PASSWORD_SECRET as string,
		{ expiresIn: "5m" } // 5 minutes
	);

	return resetToken;
};

// Reset password
const resetPassword = async (
	payload: TResetPassword,
	device: DeviceInfo,
	location: LocationInfo | null
) => {
	// Security information
	const deviceData = `${device.deviceVendor} ${device.device}`;
	const browserData = `${device.browser} ${device.brwoserVersion} on ${device.os}`;
	const locationData = `${location?.city},${location?.region},${location?.country}`;
	const ip = location?.ip || "";

	// Verify reset token
	const token = jwt.verify(
		payload.resetToken,
		process.env.RESET_PASSWORD_SECRET as string
	) as JwtPayload;

	if (!token) {
		throw new ApiError(401, "Invalid reset token");
	}

	const user = await db.user.findUnique({ where: { id: token.userId } });

	if (!user || user.email !== token.email) {
		throw new ApiError(404, "User not found");
	}

	const hashedPassword = await bcrypt.hash(payload.newPassword, 10);

	await db.user.update({
		where: { id: user.id },
		data: { password: hashedPassword, passChangedAt: new Date(Date.now()) },
	});

	// Send email
	await sendMail.passwordChangeEmail(
		user.email,
		user.name,
		ip,
		deviceData,
		browserData,
		locationData,
		"Reset password"
	);

	return;
};

// Change password

const changePassword = async (
	userData: JwtPayload,
	payload: TChangePassword,
	device: DeviceInfo,
	location: LocationInfo | null
) => {
	// Security information
	const deviceData = `${device.deviceVendor} ${device.device}`;
	const browserData = `${device.browser} ${device.brwoserVersion} on ${device.os}`;
	const locationData = `${location?.city},${location?.region},${location?.country}`;
	const ip = location?.ip || "";

	const user = await db.user.findUnique({ where: { id: userData.userId } });
	if (!user) throw new ApiError(404, "User not found");

	const passwordMatches = await bcrypt.compare(
		payload.oldPassword,
		user.password
	);
	if (!passwordMatches) throw new ApiError(401, "Old password is incorrect");

	const hashedPassword = await bcrypt.hash(payload.newPassword, 10);

	await db.user.update({
		where: { id: userData.userId },
		data: {
			password: hashedPassword,
			passChangedAt: new Date(Date.now()),
			needsPasswordChange: false,
			emailVerified: true,
		},
	});

	// Send email
	await sendMail.passwordChangeEmail(
		user.email,
		user.name,
		ip,
		deviceData,
		browserData,
		locationData,
		"Change password"
	);
	return;
};

// Refresh token
const refreshToken = async (token: string) => {
	// checking if the given token is valid
	const decoded = jwt.verify(
		token,
		process.env.JWT_REFRESH_SECRET as string
	) as JwtPayload;

	const { userId, iat } = decoded;

	// checking if the user is exist
	const user = await db.user.findUnique({
		where: { id: userId },
	});

	if (!user) {
		throw new ApiError(404, "User is not found !");
	}

	// checking if the user is active

	if (user.status !== "ACTIVE") {
		throw new ApiError(403, "User account is not active!");
	}

	// Check password update time
	if (
		user.passChangedAt &&
		new Date(user.passChangedAt) > new Date(decoded.iat! * 1000)
	) {
		throw new ApiError(401, "Token expired. Please login again");
	}

	// generate access token
	const accessToken = jwt.sign(
		{
			userId: user.id,
			name: user.name,
			role: user.role,
			email: user.email,
			phone: user.phone,
			status: user.status,
		},
		process.env.JWT_ACCESS_SECRET as string,
		{ expiresIn: "1h" }
	);

	return {
		accessToken,
	};
};

// Verify phone number
const requestAddPhoneNumber = async (
	userData: JwtPayload,
	payload: TAddPhoneNumber
) => {
	// check if user exist
	const user = await db.user.findUnique({ where: { id: userData.userId } });
	if (!user) {
		throw new ApiError(404, "User not found");
	}
	// check if phone number already exist
	const isPhoneNumberExist = await db.user.findUnique({
		where: { phone: payload.phoneNumber },
	});

	if (isPhoneNumberExist) {
		throw new ApiError(409, "Phone number already exist in another account");
	}

	// Generate verification code
	const code = generateVerificationCode();
	const expiresAt = new Date(Date.now() + 1000 * 60 * 5); // 5 minutes

	// Create verification code
	await db.verification.create({
		data: {
			userId: user.id,
			code,
			type: "PHONE_CHANGE",
			expiresAt: expiresAt,
		},
	});

	// Send OTP via SMS
	await sendSms(
		payload.phoneNumber!,
		`Your Nexweb verification code is ${code}`
	);
	return;
};

// Verify adding phone number
const verifyAddPhoneNumber = async (
	userData: JwtPayload,
	payload: TVerifyPhoneNumber
) => {
	const user = await db.user.findUnique({ where: { id: userData.userId } });
	if (!user) {
		throw new ApiError(404, "User not found");
	}
	// find the verification code
	const verificationCode = await db.verification.findFirst({
		where: {
			userId: user.id,
			code: payload.code,
			type: "PHONE_CHANGE",
		},
	});
	if (!verificationCode) {
		throw new ApiError(401, "Invalid varification code");
	}

	// if the code has expired
	if (verificationCode.expiresAt < new Date()) {
		throw new ApiError(401, "Verification code expired");
	}

	// if the code is already used
	if (verificationCode.status === "USED") {
		throw new ApiError(401, "Verification code is already used");
	}

	// Validate code
	if (verificationCode.code !== payload.code) {
		throw new ApiError(401, "Invalid verification code");
	}
	// update user phone number
	await db.user.update({
		where: { id: user.id },
		data: { phone: payload.phone, phoneVerified: true },
	});

	// Update verification code to used
	await db.verification.update({
		where: { id: verificationCode.id },
		data: { status: "USED", verifiedAt: new Date() },
	});
	return;
};

// Resend verification code
const resendVerificationCode = async (payload: TResendOTPSchema) => {
	const user = await db.user.findUnique({ where: { email: payload.email } });
	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// Check if there is an existing code
	const existingCode = await db.verification.findFirst({
		where: {
			userId: user.id,
			type: payload.type,
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

	// Create new otp
	const code = generateVerificationCode();
	const expiresAt = new Date(Date.now() + 1000 * 60 * 10); // 10 minutes

	await db.verification.create({
		data: {
			userId: user.id,
			code,
			type: payload.type,
			expiresAt,
		},
	});

	// Send otp based on provided method

	// Send otp via email
	if (payload.email) {
		await sendMail.verificationEmail(payload.email, code, "Resend OTP");
	}

	return;
};

// Initiate authority check
const initAuthorityCheckBySms = async (
	userId: string,
	otpType: VerificationCodeType
) => {
	// Find user
	const user = await db.user.findUnique({ where: { id: userId } });
	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// Generate and send otp to the user
	await generateSmsOtp(user.id, user.phone!, otpType);

	return;
};

// Verify authority
const verifyAuthority = async (userId: string, payload: TVerifyAuthority) => {
	const user = await db.user.findUnique({ where: { id: userId } });
	if (!user) {
		throw new ApiError(404, "User not found");
	}
	// find the verification code
	const verificationCode = await db.verification.findFirst({
		where: {
			userId: user.id,
			code: payload.code,
			type: "AUTHORITY_CHECK",
		},
	});
	if (!verificationCode) {
		throw new ApiError(401, "Invalid varification code");
	}

	// if the code has expired
	if (verificationCode.expiresAt < new Date()) {
		throw new ApiError(401, "Verification code expired");
	}

	// if the code is already used
	if (verificationCode.status === "USED") {
		throw new ApiError(401, "Verification code is already used");
	}

	// Validate code
	if (verificationCode.code !== payload.code) {
		throw new ApiError(401, "Invalid verification code");
	}

	// Update verification code to used
	await db.verification.update({
		where: { id: verificationCode.id },
		data: { status: "USED", verifiedAt: new Date() },
	});
	return;
};

// Resend phone_change or authority_check otp over sms
const resendOtpSms = async (userId: string, otpType: VerificationCodeType) => {
	// Find user
	const user = await db.user.findUnique({ where: { id: userId } });
	if (!user) {
		throw new ApiError(404, "User not found");
	}

	// Generate and send otp to the user
	await generateSmsOtp(user.id, user.phone!, otpType);

	return;
};

const resendMFACode = async (email: string) => {
	const user = await db.user.findUnique({ where: { email } });
	if (!user) {
		throw new ApiError(404, "User not found");
	}

	await generateSmsOtp(user.id, user.phone!, "MFA_AUTH");

	return;
};

const getTrustedDevices = async (userId: string) => {
	const devices = await db.trustedDevice.findMany({ where: { userId } });

	return devices;
};

const deleteDevice = async (id: string) => {
	const deleteDevice = await db.trustedDevice.delete({ where: { id } });
	return deleteDevice;
};

const loginHistory = async (userId: string) => {
	const result = await db.loginHistory.findMany({
		where: { userId },
		orderBy: { createdAt: "desc" },
		take: 20,
	});

	return result;
};
export const AuthServices = {
	registerUser,
	loginUser,
	verifyEmail,
	requestPasswordReset,
	verifyResetCode,
	resetPassword,
	changePassword,
	refreshToken,
	verifyMfaToken,
	requestAddPhoneNumber,
	verifyAddPhoneNumber,
	enableOrDisableMfa,
	resendVerificationCode,
	initAuthorityCheckBySms,
	verifyAuthority,
	resendOtpSms,
	resendMFACode,
	getTrustedDevices,
	deleteDevice,
	loginHistory,
};
