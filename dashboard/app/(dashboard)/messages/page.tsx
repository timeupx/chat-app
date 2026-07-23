import { ContactMessages } from "@/components/dashboard/contact-messages";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Messages";
	const description =
		"Manage and respond to contact form submissions from your website.";

	return {
		title,
		description,
	};
}
const Messages = () => {
	return (
		<div className="p-4 md:p-6">
			<ContactMessages />
		</div>
	);
};
export default Messages;
