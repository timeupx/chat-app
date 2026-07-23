import { z } from "zod";

// Define what a single Delta op looks like
const quillOpSchema = z.object({
	insert: z.union([z.string(), z.record(z.any())]),
	attributes: z.optional(z.record(z.any())),
});

// Full Quill Delta schema
const contentSchema = z.object({
	ops: z.array(quillOpSchema),
});

export const CreatePageSchema = z.object({
	title: z.string().min(1, "Title is required").optional(),
	slug: z.enum(
		[
			"about-us",
			"privacy-policy",
			"terms-and-conditions",
			"return-and-cancellation",
		],
		{
			errorMap: () => ({ message: "Invalid slug value" }),
		}
	),

	content: contentSchema.optional(),
});

// export const CreatePageSchema = z.object({
// 	title: z.string().min(1, "Title is required").optional(),
// 	slug: z
// 		.string()
// 		.min(1, "Slug is required")
// 		.regex(
// 			/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
// 			"Slug must be URL friendly (e.g., about-us)"
// 		),
// 	content: contentSchema.optional(),
// });

export type TCreatePageSchema = z.infer<typeof CreatePageSchema>;
