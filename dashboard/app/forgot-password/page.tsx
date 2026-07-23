import { ForgotPasswordForm } from "@/components/auth/forgot-password";
import { appName } from "@/utils/config";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = `Forgot Password | ${appName}`;
	const description = "Recover your account";

	return {
		title,
		description,
	};
}

const ForgotPassword = () => {
	return (
		<div>
			<ForgotPasswordForm />
		</div>
	);
};
export default ForgotPassword;
