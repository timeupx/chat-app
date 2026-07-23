import AppearanceSettingsForm from "@/components/system-settings/appearance";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Appearance Settings";
	const description =
		"Configure your site's branding and appearance preferences.";

	return {
		title,
		description,
	};
}

const AppearanceSettings = () => {
	return (
		<div className="px-0 md:px-2">
			<AppearanceSettingsForm />
		</div>
	);
};
export default AppearanceSettings;
