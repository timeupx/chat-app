import { NextFunction, Request, Response } from "express";
import { AnyZodObject, ZodTypeAny } from "zod";
import catchAsync from "../utils/catchAsync";

const validateRequest = (schema: ZodTypeAny) => {
	return catchAsync(async (req: Request, res: Response, next: NextFunction) => {
		await schema.parseAsync({
			...req.body,
			cookies: req.cookies,
		});

		next();
	});
};

export default validateRequest;
