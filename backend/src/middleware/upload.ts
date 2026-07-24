import crypto from "crypto";
import path from "path";
import multer from "multer";
import ApiError from "../utils/apiError";

// Room images are written to disk under backend/uploads/rooms and served
// back out via `express.static` (see app.ts). Filenames are randomized so
// two hosts uploading "photo.jpg" at the same moment never collide.
const storage = multer.diskStorage({
	destination: (_req, _file, cb) => {
		cb(null, path.join(__dirname, "../../uploads/rooms"));
	},
	filename: (_req, file, cb) => {
		const uniqueName = `${Date.now()}-${crypto.randomBytes(8).toString("hex")}`;
		cb(null, `${uniqueName}${path.extname(file.originalname)}`);
	},
});

const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);

export const uploadRoomImage = multer({
	storage,
	limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
	fileFilter: (_req, file, cb) => {
		if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
			// An ApiError (not a plain Error) so globalErrorHandler returns a
			// clean 400 instead of falling through to its generic 500 branch.
			cb(
				new ApiError(
					400,
					`Only JPEG, PNG, WEBP, or GIF images are allowed (got "${file.mimetype}")`
				)
			);
			return;
		}
		cb(null, true);
	},
}).single("image");
