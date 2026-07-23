import ContactSettingsForm from "@/components/system-settings/contact";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Contact Settings";
	const description = "Update contact informations and social media";

	return {
		title,
		description,
	};
}

const ContactSettings = () => {
	return (
		<div className="px-0 md:px-2">
			<ContactSettingsForm />
		</div>
	);
};
export default ContactSettings;
