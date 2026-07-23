import GeneralSettings from "@/components/system-settings/general-settings";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "System Settings";
	const description = "Update system settings.";

	return {
		title,
		description,
	};
}

const SystemSettings = () => {
	return (
		<div className="px-0 md:px-2">
			<GeneralSettings />
		</div>
	);
};
export default SystemSettings;
