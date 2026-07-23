import { NextFunction, Request, Response } from "express";
import { JwtPayload } from "jsonwebtoken";

// Custom Request type to include user
interface CustomRequest extends Request {
	user?: JwtPayload;
}

const catchAsync = (
	fn: (req: CustomRequest, res: Response, next: NextFunction) => Promise<any>
) => {
	return (req: CustomRequest, res: Response, next: NextFunction) => {
		Promise.resolve(fn(req, res, next)).catch((err) => next(err));
	};
};

export default catchAsync;
