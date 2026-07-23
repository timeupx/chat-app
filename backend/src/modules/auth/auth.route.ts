import express from "express";
import validateRequest from "../../middleware/validateRequest";
import { AuthControllers } from "./auth.controller";
import {
	AddPhoneNumberRequestSchema,
	ChangePasswordSchema,
	CreateUserSchema,
	EmailVerificationSchema,
	EnableOrDisableMfa,
	ForgotPasswordSchema,
	MfaVerificationSchema,
	RefreshTokenSchema,
	ResendMFACode,
	ResendOTPSchema,
	ResendOTPSms,
	ResetPasswordSchema,
	UserLoginSchema,
	VerifyAuthority,
	VerifyPhoneNumberSchema,
} from "./auth.validation";
import auth from "../../middleware/auth";

const router = express.Router();

// Api prefix api/auth

// Register user
router.post(
	"/register",
	validateRequest(CreateUserSchema),
	AuthControllers.registerUser
);

// Login user
router.post(
	"/login",
	validateRequest(UserLoginSchema),
	AuthControllers.loginUser
);

// Verify email
router.post(
	"/verify-account",
	validateRequest(EmailVerificationSchema),
	AuthControllers.verifyEmail
);

// Request password reset otp
router.post(
	"/request-password-reset",
	validateRequest(ForgotPasswordSchema),
	AuthControllers.requestPasswordReset
);

// Verify password reset otp
router.post(
	"/verify-password-reset-otp",
	validateRequest(EmailVerificationSchema),
	AuthControllers.verifyResetCode
);

// Reset password
router.post(
	"/reset-password",
	validateRequest(ResetPasswordSchema),
	AuthControllers.resetPassword
);

// Change password from account page
router.patch(
	"/change-password",
	validateRequest(ChangePasswordSchema),
	auth("ADMIN", "USER"),
	AuthControllers.changePassword
);

// Generate Refresh Token
router.post(
	"/refresh-token",
	validateRequest(RefreshTokenSchema),
	AuthControllers.refreshToken
);

// Verify MFA Token
router.post(
	"/verify-mfa-token",
	validateRequest(MfaVerificationSchema),
	AuthControllers.verifyMfaToken
);

// Request add phone number
router.post(
	"/request-add-phone",
	validateRequest(AddPhoneNumberRequestSchema),
	auth("ADMIN", "USER"),
	AuthControllers.requestAddPhoneNumber
);
router.post(
	"/verify-add-phone",
	validateRequest(VerifyPhoneNumberSchema),
	auth("ADMIN", "USER"),
	AuthControllers.verifyAddPhoneNumber
);

router.post(
	"/enable-or-disable-mfa",
	validateRequest(EnableOrDisableMfa),
	auth("ADMIN", "USER"),
	AuthControllers.enableOrDisableMfa
);

// Init authority check
router.post(
	"/init-authority-check",
	auth("ADMIN", "USER"),
	AuthControllers.initAuthorityCheckBySms
);

// Verify authority
router.post(
	"/verify-authority",
	validateRequest(VerifyAuthority),
	auth("ADMIN", "USER"),
	AuthControllers.verifyAuthority
);

// Resend account activation or reset password code over email
router.post(
	"/resend-otp-email",
	validateRequest(ResendOTPSchema),
	AuthControllers.resendVerificationCode
);

// Resend phone_change or authority_check otp over sms
router.post(
	"/resend-otp-sms",
	validateRequest(ResendOTPSms),
	auth("ADMIN", "USER"),
	AuthControllers.resendOtpSms
);

// Resend 2FA code
router.post(
	"/resend-two-fa-otp",
	validateRequest(ResendMFACode),
	AuthControllers.resendMFACode
);

// Trusted devices
router.get(
	"/devices",
	auth("ADMIN", "USER"),
	AuthControllers.getTurestedDevices
);

// Delete device
router.delete(
	"/devices/:id",
	auth("ADMIN", "USER"),
	AuthControllers.deleteDevice
);

// Login history
router.get(
	"/login-history",
	auth("ADMIN", "USER"),
	AuthControllers.loginHistory
);
export const AuthRoutes = router;
