"use client";

import { Shield, Trash2, User } from "lucide-react";

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
import { SettingsDropdown } from "@/components/account-settings/sidebar-dropdown";

const data = {
	nav: [
		{ name: "Profile", url: "/settings", icon: User },
		{ name: "Security", url: "/settings/security", icon: Shield },
		{ name: "Delete account", url: "/settings/delete-account", icon: Trash2 },
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
				{/* Settings tabs for mobile devices */}

				<main className="flex h-[82vh] flex-1 flex-col overflow-hidden">
					{/* <header className="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-[[data-collapsible=icon]]/sidebar-wrapper:h-12"> */}
					<div className="blcok md:hidden px-4 pt-6">
						<SettingsDropdown />
					</div>
					<div className="p-4 md:p-6">
						{pathname === "/settings" && (
							<>
								<h2 className="text-xl flex items-center gap-2">
									<User size={20} /> Profile
								</h2>
								<p className="text-sm pt-1">
									Update your personal information and profile settings.
								</p>
							</>
						)}
						{pathname === "/settings/security" && (
							<>
								<h2 className="text-xl flex items-center gap-2">
									<Shield size={20} /> Security
								</h2>
								<p className="text-sm pt-1">Update your security settings.</p>
							</>
						)}
						{pathname === "/settings/delete-account" && (
							<>
								<h2 className="text-xl text-red-500 flex items-center gap-2">
									<Trash2 size={20} /> Delete Account
								</h2>
								<p className="text-sm pt-1">
									Permanently delete your account and all associated data. This
									action cannot be undone.
								</p>
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
