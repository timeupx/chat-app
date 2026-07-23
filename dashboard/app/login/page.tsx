import { LoginForm } from "@/components/auth/login-form";
import { appName } from "@/utils/config";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = `Login | ${appName}`;
	const description = "Sign in to access the account area";

	return {
		title,
		description,
	};
}
const LoginPage = () => {
	return (
		<div className="flex flex-col items-center justify-center h-[100vh] gap-5">
			<div className="w-full md:w-sm text-center space-y-5 p-4 md:p-0">
				{/* <div className="w-[70px] mx-auto border rounded-md p-3 flex flex-col items-center justify-center">
					<Bolt size="40" />
				</div> */}
				<div>
					<h2 className="text-2xl font-semibold">Welcome back!</h2>
					<p>Sign in to access the account area</p>
				</div>
				<LoginForm />
			</div>
		</div>
	);
};
export default LoginPage;
