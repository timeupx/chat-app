import { z } from "zod";

export const CreateLiveRoomSchema = z.object({
	roomName: z.string().min(1, "Room name is required"),
	roomImage: z.string().min(1, "Room image is required"),
	is18Plus: z.boolean().default(false),
	roomRules: z.string().default(""),
});

export type TCreateLiveRoom = z.infer<typeof CreateLiveRoomSchema>;
