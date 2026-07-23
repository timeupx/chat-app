import AnalyticsSeoForm from "@/components/system-settings/analytics-seo";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Analytics & SEO";
	const description = "Update SEO settings";

	return {
		title,
		description,
	};
}

const SeoSettings = () => {
	return (
		<div className="px-0 md:px-2">
			<AnalyticsSeoForm />
		</div>
	);
};
export default SeoSettings;
