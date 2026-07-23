import { z } from "zod";

export const CreateUserSchema = z.object({
	name: z.string(),
	email: z.string().email(),
	phone: z.string().optional(),
	password: z.string().min(6),
});

export const UserLoginSchema = z.object({
	email: z.string().email(),
	password: z.string(),
	rememberDevice: z.boolean().default(false),
});

export const EmailVerificationSchema = z.object({
	email: z.string().email(),
	code: z.string(),
});

export const ForgotPasswordSchema = z.object({
	email: z.string().email(),
});

export const ResetPasswordSchema = z.object({
	resetToken: z.string(),
	newPassword: z.string(),
});

export const ChangePasswordSchema = z.object({
	oldPassword: z.string(),
	newPassword: z.string().min(6),
});

export const RefreshTokenSchema = z.object({
	cookies: z.object({
		refreshToken: z.string(),
	}),
});

export const MfaVerificationSchema = z.object({
	email: z.string().email(),
	code: z.string(),
	rememberDevice: z.boolean(),
});

export const AddPhoneNumberRequestSchema = z.object({
	phoneNumber: z.string().max(13),
});

export const VerifyPhoneNumberSchema = z.object({
	phone: z.string(),
	code: z.string(),
});

// Resend otp token over email (activation or reset otp)
export const ResendOTPSchema = z.object({
	email: z.string().email(),
	type: z.enum(["ACCOUNT_ACTIVATION", "PASSWORD_RESET"]),
});

export const VerifyAuthority = z.object({
	code: z.string().max(6).min(6),
});

export const EnableOrDisableMfa = z.object({
	mfaEnabled: z.boolean(),
});

export const ResendOTPSms = z.object({
	otpType: z.enum(["PHONE_CHANGE", "AUTHORITY_CHECK"]),
});

export const ResendMFACode = z.object({
	email: z.string().email(),
});
export type TUser = z.infer<typeof CreateUserSchema>;
export type TLogin = z.infer<typeof UserLoginSchema>;
export type TEmailVerification = z.infer<typeof EmailVerificationSchema>;
export type TForgotPassword = z.infer<typeof ForgotPasswordSchema>;
export type TResetPassword = z.infer<typeof ResetPasswordSchema>;
export type TChangePassword = z.infer<typeof ChangePasswordSchema>;
export type TMfaVerification = z.infer<typeof MfaVerificationSchema>;
export type TAddPhoneNumber = z.infer<typeof AddPhoneNumberRequestSchema>;
export type TVerifyPhoneNumber = z.infer<typeof VerifyPhoneNumberSchema>;
export type TResendOTPSchema = z.infer<typeof ResendOTPSchema>;
export type TVerifyAuthority = z.infer<typeof VerifyAuthority>;
export type TEnableOrDisableMfa = z.infer<typeof EnableOrDisableMfa>;
