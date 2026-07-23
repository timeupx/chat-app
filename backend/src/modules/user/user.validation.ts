import { z } from "zod";
import { VerificationCodeType } from "../../../generated/prisma";

export const UpdateUserSchema = z.object({
	name: z.string().optional(),
	photo: z.string().optional().nullable().optional(),
	address: z.string().optional().nullable().optional(),
	bio: z.string().optional().nullable().optional(),
});
// export const UpdateUserSchema = z.object({
// 	name: z.string().optional(),
// 	email: z.string().email().optional(),
// 	phone: z.string().min(10).max(15).optional().nullable(),
// 	role: z.nativeEnum(Role).optional(),
// 	status: z.nativeEnum(AccountStatus).optional(),
// 	mfa_enabled: z.boolean().optional(),
// 	email_verified: z.boolean().optional(),
// 	phone_verified: z.boolean().optional(),
// 	photo: z.string().optional().nullable().optional(),
// 	address: z.string().optional().nullable().optional(),
// 	bio: z.string().optional().nullable().optional(),
// });

export type TUpdateUser = z.infer<typeof UpdateUserSchema>;
