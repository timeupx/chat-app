import axios from "axios";
import { UAParser } from "ua-parser-js";

export interface DeviceInfo {
	browser: string;
	brwoserVersion: string;
	os: string;
	device: string;
	deviceVendor: string;
}

export interface LocationInfo {
	ip: string;
	city?: string;
	region?: string;
	country?: string;
	org?: string;
	[key: string]: any;
}

export const getDeviceInfo = (userAgent: string): DeviceInfo => {
	const parser = new UAParser(userAgent);
	const result = parser.getResult();

	return {
		browser: result.browser.name || "Unknown",
		brwoserVersion: result.browser.version || "",
		os: result.os.name || "Unknown",
		device: result.device.model || "",
		deviceVendor: result.device.vendor || "",
	};
};

export const getGeoLocation = async (
	ip: string
): Promise<LocationInfo | null> => {
	try {
		const { data } = await axios.get<LocationInfo>(
			`https://ipapi.co/${ip}/json/`
		);
		return data;
	} catch (err) {
		console.error("Geo IP lookup failed:", (err as Error).message);
		return null;
	}
};
