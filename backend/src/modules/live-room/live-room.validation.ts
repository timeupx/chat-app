import { z } from "zod";

/** Room creation only requires a name and image. Optional fields keep
 * backward compatibility with older clients that still send them. */
export const CreateLiveRoomSchema = z.object({
	roomName: z.string().min(1, "Room name is required"),
	roomImage: z.string().min(1, "Room image is required"),
	is18Plus: z.boolean().optional().default(false),
	roomRules: z.string().optional().default(""),
});

export type TCreateLiveRoom = z.infer<typeof CreateLiveRoomSchema>;
