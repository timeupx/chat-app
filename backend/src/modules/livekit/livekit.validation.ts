import { z } from "zod";

// Note: identity/displayName are NOT accepted here - the real identity and
// name come from the caller's verified JWT (req.user), never from the
// request body. Trusting a client-supplied identity would let a banned
// user simply mint a token under a different name and bypass the ban.
export const CreateLiveKitTokenSchema = z.object({
	roomName: z.string().min(1),
	role: z.enum(["host", "viewer", "guest"]),
});

export type TCreateLiveKitToken = z.infer<typeof CreateLiveKitTokenSchema>;
