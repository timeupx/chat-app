import { JwtPayload } from "jsonwebtoken";
import catchAsync from "../../utils/catchAsync";
import { getDeviceInfo, getGeoLocation } from "../../utils/ipLocationInfo";
import sendResponse from "../../utils/sendResponse";
import { AuthServices } from "./auth.service";

// Register user
const registerUser = catchAsync(async (req, res) => {
	const payload = req.body;

	const result = await AuthServices.registerUser(payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "User created successfully!",
		data: result,
	});
});

// Login user
const loginUser = catchAsync(async (req, res) => {
	const payload = req.body;
	const { trustedDevice } = req.cookies;

	const ipAddress =
		(req.headers["x-forwarded-for"] as string)?.split(",")[0] ||
		req.socket.remoteAddress ||
		req.ip ||
		"";

	const userAgent = req.headers["user-agent"] || "";
	const device = getDeviceInfo(userAgent);
	const location = await getGeoLocation(ipAddress);

	const result = await AuthServices.loginUser(
		payload,
		ipAddress,
		device,
		location,
		trustedDevice
	);

	if ("mfaPending" in result) {
		return sendResponse(res, {
			statusCode: 200,
			success: true,
			message: "An OTP has been sent to your phone",
			data: null,
		});
	}
	const { refreshToken, accessToken, rawDeviceToken } = result;

	res.cookie("refreshToken", refreshToken, {
		secure: process.env.NODE_ENV === "production",
		httpOnly: true,
		sameSite: "none",
		maxAge: 1000 * 60 * 60 * 24 * 365,
	});

	if (rawDeviceToken) {
		res.cookie("trustedDevice", rawDeviceToken, {
			httpOnly: true,
			secure: process.env.NODE_ENV === "production",
			sameSite: "lax",
			maxAge: 1000 * 60 * 60 * 24 * 30,
		});
	}

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "User logged in successfully!",
		data: { accessToken },
	});
});

// Verify email

const verifyEmail = catchAsync(async (req, res) => {
	const payload = req.body;

	const result = await AuthServices.verifyEmail(payload);
	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Email verified successfully!",
		data: result,
	});
});

// Request password reset
const requestPasswordReset = catchAsync(async (req, res) => {
	const payload = req.body;

	const result = await AuthServices.requestPasswordReset(payload);
	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "An OTP has been sent to your email.",
		data: result,
	});
});

// Verify password reset otp
const verifyResetCode = catchAsync(async (req, res) => {
	const payload = req.body;
	const result = await AuthServices.verifyResetCode(payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "OTP verification successful",
		data: { resetToken: result },
	});
});

// Reset password
const resetPassword = catchAsync(async (req, res) => {
	const payload = req.body;

	const ipAddress =
		(req.headers["x-forwarded-for"] as string)?.split(",")[0] ||
		req.socket.remoteAddress ||
		"";

	const userAgent = req.headers["user-agent"] || "";
	const device = getDeviceInfo(userAgent);
	const location = await getGeoLocation(ipAddress);

	const result = await AuthServices.resetPassword(payload, device, location);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Password reset successful",
		data: result,
	});
});

// Change password
const changePassword = catchAsync(async (req, res) => {
	const userData = req.user as JwtPayload;
	const payload = req.body;

	const ipAddress =
		(req.headers["x-forwarded-for"] as string)?.split(",")[0] ||
		req.socket.remoteAddress ||
		"";

	const userAgent = req.headers["user-agent"] || "";
	const device = getDeviceInfo(userAgent);
	const location = await getGeoLocation(ipAddress);

	const result = await AuthServices.changePassword(
		userData,
		payload,
		device,
		location
	);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Password change successful",
		data: result,
	});
});

// refresh token
const refreshToken = catchAsync(async (req, res) => {
	const { refreshToken } = req.cookies;
	const result = await AuthServices.refreshToken(refreshToken);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Access token is generated succesfully!",
		data: result,
	});
});

// Enable MFA
const enableOrDisableMfa = catchAsync(async (req, res) => {
	const userData = req.user as JwtPayload;
	const payload = req.body;
	const result = await AuthServices.enableOrDisableMfa(userData, payload);
	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: payload?.mfaEnabled!
			? "Two-Factor Authentication Enabled succesfully!"
			: "Two-Factor Authentication Disabled",
		data: result,
	});
});
// verify MFA token when login
const verifyMfaToken = catchAsync(async (req, res) => {
	const payload = req.body;
	const ipAddress =
		(req.headers["x-forwarded-for"] as string)?.split(",")[0] ||
		req.socket.remoteAddress ||
		req.ip ||
		"";

	const userAgent = req.headers["user-agent"] || "";
	const device = getDeviceInfo(userAgent);
	const location = await getGeoLocation(ipAddress);

	const result = await AuthServices.verifyMfaToken(
		payload,
		ipAddress,
		device,
		location
	);

	const { refreshToken, accessToken, rawDeviceToken } = result;

	res.cookie("refreshToken", refreshToken, {
		secure: process.env.NODE_ENV === "production",
		httpOnly: true,
		sameSite: "none",
		maxAge: 1000 * 60 * 60 * 24 * 30,
	});
	if (rawDeviceToken) {
		res.cookie("trustedDevice", rawDeviceToken, {
			httpOnly: true,
			secure: process.env.NODE_ENV === "production",
			sameSite: "lax",
			maxAge: 1000 * 60 * 60 * 24 * 30,
		});
	}

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "User logged in successfully!",
		data: {
			accessToken,
		},
	});
});

// Request add phone number
const requestAddPhoneNumber = catchAsync(async (req, res) => {
	const payload = req.body;
	const userData = req.user as JwtPayload;
	const result = await AuthServices.requestAddPhoneNumber(userData, payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "An OTP has been send to your phone",
		data: result,
	});
});
// Request add phone number
const verifyAddPhoneNumber = catchAsync(async (req, res) => {
	const payload = req.body;
	const userData = req.user as JwtPayload;

	const result = await AuthServices.verifyAddPhoneNumber(userData, payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Phone number verification successful",
		data: result,
	});
});
//  todo
const resendVerificationCode = catchAsync(async (req, res) => {
	const payload = req.body;
	const result = await AuthServices.resendVerificationCode(payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: payload?.phone
			? "An OTP code has been sent to your phone"
			: "An OTP code has been sent to your email",
		data: result,
	});
});

// check authority for important actions
const initAuthorityCheckBySms = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	// const { otpType } = req.body;
	const result = await AuthServices.initAuthorityCheckBySms(
		userId,
		"AUTHORITY_CHECK"
	);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "An OTP has been send to your phone",
		data: result,
	});
});

// Verify authority by otp verification
const verifyAuthority = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	const payload = req.body;

	const result = await AuthServices.verifyAuthority(userId, payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Verification successfull",
		data: result,
	});
});

// Resend authority_check and phone_change otp
const resendOtpSms = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;
	const { otpType } = req.body;

	const result = await AuthServices.resendOtpSms(userId, otpType);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "An OTP has been sent to your phone",
		data: result,
	});
});

// Resend mfa top
const resendMFACode = catchAsync(async (req, res) => {
	const { email } = req.body;

	const result = await AuthServices.resendMFACode(email);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "An OTP has been sent to your phone",
		data: result,
	});
});

const getTurestedDevices = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;

	const result = await AuthServices.getTrustedDevices(userId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Devices retrived successfully!",
		data: result,
	});
});

const deleteDevice = catchAsync(async (req, res) => {
	const id = req.params.id;
	const result = await AuthServices.deleteDevice(id);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Divice deleted successfully!",
		data: result,
	});
});

// login histories
const loginHistory = catchAsync(async (req, res) => {
	const { userId } = req.user as JwtPayload;

	const result = await AuthServices.loginHistory(userId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Login histories retrived successfully!",
		data: result,
	});
});
export const AuthControllers = {
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
	getTurestedDevices,
	deleteDevice,
	loginHistory,
};
