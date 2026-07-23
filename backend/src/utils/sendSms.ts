import axios from "axios";
import ApiError from "./apiError";

export const sendSms = async (number: string, message: string) => {
	try {
		const data = {
			api_key: process.env.SMS_API_KEY,
			senderid: process.env.SMS_SENDER_ID,
			number,
			message,
		};

		const response = await axios.post("http://bulksmsbd.net/api/smsapi", data);

		if (response.data?.response_code !== 202) {
			console.error("SMS sending failed:", response.data);
			throw new ApiError(response.data?.response_code, "Failed to send SMS");
		}
	} catch (error) {
		console.error("SMS error:", error);
		throw new ApiError(500, "SMS sending error");
	}
};
