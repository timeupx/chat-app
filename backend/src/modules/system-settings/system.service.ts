import db from "../../config/prisma";
import { TSystemSettings } from "./system.validation";

// Add or update system settings
const upsertSystemSettings = async (data: TSystemSettings) => {
	const existing = await db.systemSettings.findFirst({
		include: {
			contact: true,
			intigration: true,
			analyticsSeo: true,
		},
	});

	if (!existing) {
		return await db.systemSettings.create({
			data: {
				metaTitle: data.metaTitle,
				metaDescription: data.metaDescription,
				allowSignup: data.allowSignup ?? true,
				maintenanceMode: data.maintenanceMode ?? false,
				contact: data.contact ? { create: data.contact } : undefined,
				intigration: data.intigration
					? { create: data.intigration }
					: undefined,
				analyticsSeo: data.analyticsSeo
					? { create: data.analyticsSeo }
					: undefined,
			},
			include: {
				contact: true,
				intigration: true,
				analyticsSeo: true,
			},
		});
	}

	return await db.systemSettings.update({
		where: { id: existing.id },
		data: {
			...(data.metaTitle !== undefined && { metaTitle: data.metaTitle }),
			...(data.metaDescription !== undefined && {
				metaDescription: data.metaDescription,
			}),
			...(data.allowSignup !== undefined && { allowSignup: data.allowSignup }),
			...(data.maintenanceMode !== undefined && {
				maintenanceMode: data.maintenanceMode,
			}),

			contact: data.contact
				? {
						upsert: {
							create: data.contact,
							update: data.contact,
						},
				  }
				: undefined,

			intigration: data.intigration
				? {
						upsert: {
							create: data.intigration,
							update: data.intigration,
						},
				  }
				: undefined,

			analyticsSeo: data.analyticsSeo
				? {
						upsert: {
							create: data.analyticsSeo,
							update: data.analyticsSeo,
						},
				  }
				: undefined,
		},
		include: {
			contact: true,
			intigration: true,
			analyticsSeo: true,
		},
	});
};

// Get system settings
const getSystemSettings = async () => {
	return await db.systemSettings.findFirst({
		include: {
			contact: true,
			intigration: true,
			analyticsSeo: true,
		},
	});
};
export const SystemSettingsServices = {
	upsertSystemSettings,
	getSystemSettings,
};
