import { z } from "zod";

const FILTER_NAMES = ["Natural", "Smooth", "Bright", "Vivid", "Cool"] as const;
const SLOT_COUNTS = [3, 6, 9] as const;

/** Room creation only requires a name. Cover defaults to the host's profile
 * photo on the server when `roomImage` is omitted. */
export const CreateLiveRoomSchema = z.object({
	roomName: z.string().min(1, "Room name is required"),
	roomImage: z.string().optional(),
	is18Plus: z.boolean().optional().default(false),
	roomRules: z.string().optional().default(""),
	filterName: z.enum(FILTER_NAMES).optional().default("Natural"),
	slotCount: z
		.number()
		.int()
		.refine((n): n is (typeof SLOT_COUNTS)[number] => (SLOT_COUNTS as readonly number[]).includes(n), {
			message: "slotCount must be 3, 6, or 9",
		})
		.optional()
		.default(6),
});

export type TCreateLiveRoom = z.infer<typeof CreateLiveRoomSchema>;
