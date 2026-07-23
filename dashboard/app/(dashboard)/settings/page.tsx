import UpdateProfileForm from "@/components/account-settings/profile-settings";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Account Settings";
	const description = "Update your personal information and profile settings.";

	return {
		title,
		description,
	};
}
const Settings = () => {
	return (
		<div>
			<UpdateProfileForm />
		</div>
	);
};
export default Settings;
