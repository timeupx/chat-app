import { z } from "zod";

export const systemSettingsPatchSchema = z.object({
	metaTitle: z.string().optional(),
	metaDescription: z.string().optional(),
	allowSignup: z.boolean().optional(),
	maintenanceMode: z.boolean().optional(),

	contact: z
		.object({
			email: z.string().email().optional(),
			phone: z.string().optional(),
			address: z.string().optional(),
			facebook: z.string().url().optional(),
			x: z.string().url().optional(),
			instagram: z.string().url().optional(),
			youtube: z.string().url().optional(),
		})
		.optional(),

	intigration: z
		.object({
			smsApiKey: z.string().optional(),
			emailApiKey: z.string().optional(),
		})
		.optional(),

	analyticsSeo: z
		.object({
			gatId: z.string().optional(),
			gtmId: z.string().optional(),
			pixelId: z.string().optional(),
		})
		.optional(),
});

export type TSystemSettings = z.infer<typeof systemSettingsPatchSchema>;
