"use client";

import { Blocks, MapPinned, Palette, Settings, TrendingUp } from "lucide-react";

import {
	Sidebar,
	SidebarContent,
	SidebarGroup,
	SidebarGroupContent,
	SidebarMenu,
	SidebarMenuButton,
	SidebarMenuItem,
	SidebarProvider,
} from "@/components/ui/sidebar";
import Link from "next/link";
import { usePathname } from "next/navigation";

const data = {
	nav: [
		{ name: "System settings", url: "/system-settings", icon: Settings },
		{ name: "Contact", url: "/system-settings/contact", icon: MapPinned },
		{
			name: "Intigrations",
			url: "/system-settings/intigrations",
			icon: Blocks,
		},
		{
			name: "Appearance",
			url: "/system-settings/appearance",
			icon: Palette,
		},
		{
			name: "Analytics & SEO",
			url: "/system-settings/seo",
			icon: TrendingUp,
		},
	],
};

export default function SettingsLayout({
	children,
}: Readonly<{
	children: React.ReactNode;
}>) {
	const pathname = usePathname();
	return (
		<div className="max-h-[82vh] overflow-hidden">
			<SidebarProvider className="items-start flex gap-8">
				<Sidebar
					collapsible="none"
					className="hidden md:flex bg-transparent pt-4 w-[12rem]"
				>
					<SidebarContent>
						<SidebarGroup>
							<SidebarGroupContent>
								<SidebarMenu>
									{data.nav.map((item) => (
										<SidebarMenuItem key={item.name}>
											<SidebarMenuButton
												className="px-4 py-5"
												asChild
												isActive={pathname === item.url}
											>
												<Link href={item.url}>
													<item.icon />
													<span>{item.name}</span>
												</Link>
											</SidebarMenuButton>
										</SidebarMenuItem>
									))}
								</SidebarMenu>
							</SidebarGroupContent>
						</SidebarGroup>
					</SidebarContent>
				</Sidebar>
				<main className="flex h-[82vh] flex-1 flex-col overflow-hidden">
					{/* <header className="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-[[data-collapsible=icon]]/sidebar-wrapper:h-12"> */}
					<div className="p-4 md:p-6">
						{pathname === "/system-settings" && (
							<>
								<h2 className="text-xl flex gap-2 items-center">
									<Settings size={20} /> System settings
								</h2>
								<p className="text-sm pt-1">Update system settings.</p>
							</>
						)}
						{pathname === "/system-settings/intigrations" && (
							<>
								<h2 className="text-xl flex gap-2 items-center">
									<Blocks size={20} /> Intigrations
								</h2>
								<p className="text-sm pt-1">Intigrate third party services.</p>
							</>
						)}
						{pathname === "/system-settings/contact" && (
							<>
								<h2 className="text-xl flex gap-2 items-center">
									<MapPinned size={20} /> Contact
								</h2>
								<p className="text-sm pt-1">
									Update contact informations and social media
								</p>
							</>
						)}
						{pathname === "/system-settings/appearance" && (
							<>
								<h2 className="text-xl flex gap-2 items-center">
									<Palette size={20} /> Appearance
								</h2>
								<p className="text-sm pt-1">
									Configure your site&apos;s branding and appearance
									preferences.
								</p>
							</>
						)}
						{pathname === "/system-settings/seo" && (
							<>
								<h2 className="text-xl flex gap-2 items-center">
									<TrendingUp size={20} /> Analytics & SEO
								</h2>
								<p className="text-sm pt-1">Update SEO settings </p>
							</>
						)}
						{/* <Breadcrumb>
								<BreadcrumbList>
									<BreadcrumbItem className="hidden md:block">
										<BreadcrumbLink href="#">Settings</BreadcrumbLink>
									</BreadcrumbItem>
									<BreadcrumbSeparator className="hidden md:block" />
									<BreadcrumbItem>
										<BreadcrumbPage>Messages & media</BreadcrumbPage>
									</BreadcrumbItem>
								</BreadcrumbList>
							</Breadcrumb> */}
					</div>
					{/* </header> */}
					<div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4 pt-0">
						{children}
					</div>
				</main>
			</SidebarProvider>
		</div>
	);
}
