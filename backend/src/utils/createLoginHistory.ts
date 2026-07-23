import db from "../config/prisma";

type LoginHistory = {
	userId: string;
	device: string;
	ipAddress: string;
	location: string;
	successful: boolean;
	browser: string;
};

export const createLoginHistory = async (info: LoginHistory) => {
	await db.loginHistory.create({
		data: {
			userId: info.userId,
			device: info.device,
			ipAddress: info.ipAddress,
			browser: info.browser,
			location: info.location,
			successful: info.successful,
		},
	});
};
