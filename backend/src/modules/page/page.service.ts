import db from "../../config/prisma";
import ApiError from "../../utils/apiError";
import { TCreatePageSchema } from "./page.validation";

export const createOrUpdatePage = async (
	storeId: string,
	payload: TCreatePageSchema
) => {
	if (!storeId) {
		throw new ApiError(401, "Store ID not found");
	}
	const store = await db.store.findUnique({ where: { id: storeId } });

	if (!store) {
		throw new ApiError(404, "Store not found");
	}

	const { slug, title, content } = payload;

	const result = await db.page.upsert({
		where: {
			storeId_slug: {
				storeId,
				slug,
			},
		},
		create: {
			storeId,
			slug,
			title,
			content,
		},
		update: {
			content,
		},
	});

	return result;
};

// Get all pages
const getAllPages = async (storeId: string) => {
	const store = await db.store.findUnique({ where: { id: storeId } });
	if (!store) {
		throw new ApiError(404, "Store not found");
	}
	const result = await db.page.findMany({ where: { storeId } });
	return result;
};

// Get page by slug
const getPageBySlug = async (storeId: string, slug: string) => {
	const store = await db.store.findUnique({ where: { id: storeId } });
	if (!store) {
		throw new ApiError(404, "Store not found");
	}

	const result = await db.page.findUnique({
		where: {
			storeId_slug: {
				storeId,
				slug,
			},
		},
	});

	return result;
};

export const PageService = { createOrUpdatePage, getAllPages, getPageBySlug };
