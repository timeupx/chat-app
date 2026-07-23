import { DashboardCards } from "@/components/dashboard/dashboard-cards";
import { MonthlySalesTrend } from "@/components/dashboard/monthly-sales-chart";
import { Metadata } from "next";

export async function generateMetadata(): Promise<Metadata> {
	// Todo: Call from db
	const title = "Dashboard";
	const description = "Your dynamic dashboard overview.";

	return {
		title,
		description,
	};
}
export default function Home() {
	return (
		<div className="flex flex-1 flex-col">
			<div className="@container/main flex flex-1 flex-col gap-2">
				<div className="flex flex-col gap-4 py-4 md:gap-6 md:py-6">
					<DashboardCards />
					<MonthlySalesTrend />
				</div>
			</div>
		</div>
	);
}
