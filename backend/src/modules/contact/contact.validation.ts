import { z } from "zod";

export const StoreContactMessageSchema = z.object({
	subject: z.string().max(300),
	name: z.string().max(100),
	email: z.string().email(),
	message: z.string(),
	phone: z.string(),
});

export type TStoreContactMessage = z.infer<typeof StoreContactMessageSchema>;
