import { AppSidebar } from "@/components/app-sidebar";
import { DynamicBreadcrumb } from "@/components/dashboard/dynamic-breadcrumb";
import { ThemeSwitcher } from "@/components/theme-switcher";

import { Separator } from "@/components/ui/separator";
import {
	SidebarInset,
	SidebarProvider,
	SidebarTrigger,
} from "@/components/ui/sidebar";
import AuthGuard from "@/utils/auth-guard";

export default function DashboardLayout({
	children,
}: Readonly<{
	children: React.ReactNode;
}>) {
	return (
		<AuthGuard>
			<SidebarProvider>
				<AppSidebar />
				<SidebarInset className="pt-12">
					<header className="fixed w-full pr-[1rem] lg:pr-[17rem] top-0 z-40 flex h-16 items-center justify-between gap-2 border-b px-4 bg-background">
						<div className="flex items-center gap-2 overflow-hidden">
							<SidebarTrigger className="-ml-1" />
							<Separator
								orientation="vertical"
								className="mr-2 data-[orientation=vertical]:h-4"
							/>
							<DynamicBreadcrumb />
						</div>
						<div className="shrink-0">
							<ThemeSwitcher />
						</div>
					</header>

					<div className="flex flex-1 flex-col gap-4 p-4">{children}</div>
				</SidebarInset>
			</SidebarProvider>
		</AuthGuard>
	);
}
