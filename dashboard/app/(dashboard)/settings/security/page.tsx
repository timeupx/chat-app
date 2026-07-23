import { LoggedInDevices } from "@/components/account-settings/logged-in-devices";
import { LoginHistory } from "@/components/account-settings/login-history";
import { PasswordChange } from "@/components/account-settings/password-change";
import { TwoFactorAuth } from "@/components/account-settings/two-factory-auth";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Security settings";
	const description = "Update your security settings";

	return {
		title,
		description,
	};
}

export default function SecuritySettings() {
	return (
		<div className="max-w-4xl pt-4 space-y-8">
			{/* <div>
				<h1 className="text-3xl font-bold">Security Settings</h1>
				<p className="text-muted-foreground mt-2">
					Manage your account security and monitor login activity.
				</p>
			</div> */}

			<div className="grid gap-8">
				<div className="flex flex-col md:flex-row gap-4">
					<PasswordChange />
					<TwoFactorAuth />
				</div>

				<LoggedInDevices />

				<LoginHistory />
			</div>
		</div>
	);
}
