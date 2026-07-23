import IntigrationsForm from "@/components/system-settings/intigrations";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Intigrations";
	const description = "Intigrate third party services.";

	return {
		title,
		description,
	};
}

const IntigrationSettings = () => {
	return (
		<div className="px-0 md:px-2">
			<IntigrationsForm />
		</div>
	);
};
export default IntigrationSettings;
