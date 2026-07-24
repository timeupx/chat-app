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

const isPrivateOrLoopbackIp = (ip: string): boolean => {
	if (!ip) return true;
	return (
		ip === "::1" ||
		ip === "127.0.0.1" ||
		ip.startsWith("::ffff:127.") ||
		ip.startsWith("192.168.") ||
		ip.startsWith("10.")
	);
};

export const getGeoLocation = async (
	ip: string
): Promise<LocationInfo | null> => {
	// Local/loopback IPs (e.g. developing against localhost) can't be
	// geolocated and would otherwise wait on the request below.
	if (isPrivateOrLoopbackIp(ip)) return null;

	try {
		const { data } = await axios.get<LocationInfo>(
			`https://ipapi.co/${ip}/json/`,
			{ timeout: 5000 }
		);
		return data;
	} catch (err) {
		console.error("Geo IP lookup failed:", (err as Error).message);
		return null;
	}
};
