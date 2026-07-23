import { DeleteAccount } from "@/components/account-settings/delete-account";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Delete account";
	const description =
		"Permanently delete your account and all associated data. This action cannot be undone.";

	return {
		title,
		description,
	};
}
export default function DeleteAccountPage() {
	return (
		<div className="max-w-4xl pt-4 space-y-8">
			{/* <div>
				<h1 className="text-3xl font-bold">Security Settings</h1>
				<p className="text-muted-foreground mt-2">
					Manage your account security and monitor login activity.
				</p>
			</div> */}

			<div className="grid gap-8">
				<DeleteAccount />
			</div>
		</div>
	);
}
