import { EmailLogs } from "@/components/email-logs";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Email Logs";
	const description =
		"Monitor and track all email communications sent from your system.";

	return {
		title,
		description,
	};
}
const EmailLogsPage = () => {
	return (
		<div className="p-4 md:p-6">
			<EmailLogs />
		</div>
	);
};
export default EmailLogsPage;
