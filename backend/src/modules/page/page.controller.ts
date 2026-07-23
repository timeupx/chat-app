import { JwtPayload } from "jsonwebtoken";
import catchAsync from "../../utils/catchAsync";
import { PageService } from "./page.service";
import sendResponse from "../../utils/sendResponse";
import ApiError from "../../utils/apiError";

// Create or update page
const handleCreateOrUpdatePage = catchAsync(async (req, res) => {
	const { storeId } = req.user as JwtPayload;
	const payload = req.body;
	const result = await PageService.createOrUpdatePage(storeId, payload);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Page content updated",
		data: result,
	});
});

// Get all pages
const handleGetAllPages = catchAsync(async (req, res) => {
	const { storeId } = req.user as JwtPayload;

	const result = await PageService.getAllPages(storeId);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Pages retrived successfully",
		data: result,
	});
});

// Get page by slug
const handleGetPageBySlug = catchAsync(async (req, res) => {
	const { slug } = req.params;
	const { storeId } = req.user as JwtPayload;

	if (!slug || typeof slug !== "string") {
		throw new ApiError(400, "Slug must be a string");
	}
	const result = await PageService.getPageBySlug(storeId, slug);

	sendResponse(res, {
		statusCode: 200,
		success: true,
		message: "Page data retrived successfully",
		data: result,
	});
});
export const PageController = {
	handleCreateOrUpdatePage,
	handleGetAllPages,
	handleGetPageBySlug,
};
