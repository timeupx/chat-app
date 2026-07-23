import { UserList } from "@/components/dashboard/users-list";
import { Metadata } from "next";
export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "User Management";
	const description = "Manage user accounts, roles, and permissions.";

	return {
		title,
		description,
	};
}
const UsersPage = () => {
	return (
		<div className="p-4 md:p-6">
			<UserList />
		</div>
	);
};
export default UsersPage;
