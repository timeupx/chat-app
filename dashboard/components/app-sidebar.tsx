"use client";
import {
	GalleryVerticalEnd,
	LayoutDashboard,
	Mails,
	MessageCircleMore,
	Settings,
	Users,
} from "lucide-react";

import { NavMain } from "@/components/nav-main";
import { NavUser } from "@/components/nav-user";
import {
	Sidebar,
	SidebarContent,
	SidebarFooter,
	SidebarHeader,
	SidebarMenu,
	SidebarMenuButton,
	SidebarMenuItem,
	SidebarRail,
} from "@/components/ui/sidebar";
import { useAppSelector } from "@/redux/feature/hooks";
import { TUser, useCurrentUser } from "@/redux/feature/auth/authSlice";

// This is sample data.
const data = {
	user: {
		name: "Farid Alam",
		email: "faridalam62@gmail.com",
		avatar: "/avatars/shadcn.jpg",
	},

	navMain: [
		{
			title: "Dashboard",
			url: "/",
			icon: LayoutDashboard,
		},
		{
			title: "Users",
			url: "/users",
			icon: Users,
		},
		{
			title: "Messages",
			url: "/messages",
			icon: MessageCircleMore,
		},
		{
			title: "Email Logs",
			url: "/email-logs",
			icon: Mails,
		},
		{
			title: "Settings",
			url: "#",
			icon: Settings,
			items: [
				{
					title: "System Settings",
					url: "/system-settings",
				},
				{
					title: "Appearance",
					url: "/system-settings/appearance",
				},
				{
					title: "Contact information",
					url: "/system-settings/contact",
				},
				{
					title: "Intigrations",
					url: "/system-settings/intigrations",
				},
				{
					title: "Analytics & SEO",
					url: "/system-settings/seo",
				},
			],
		},
	],
};

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
	const userData = useAppSelector(useCurrentUser) as TUser;

	return (
		<Sidebar collapsible="icon" {...props}>
			<SidebarHeader className="text-primary-foreground dark:text-muted-foreground">
				<SidebarMenu>
					<SidebarMenuItem>
						<SidebarMenuButton size="lg" asChild>
							<a href="#">
								<div className="bg-sidebar-primary text-sidebar-primary-foreground flex aspect-square size-8 items-center justify-center rounded-lg">
									<GalleryVerticalEnd className="size-4" />
								</div>
								<div className="flex flex-col gap-0.5 leading-none">
									<span className="font-medium">Admin Kit</span>
									<span className="">v1.0.0</span>
								</div>
							</a>
						</SidebarMenuButton>
					</SidebarMenuItem>
				</SidebarMenu>
			</SidebarHeader>
			<SidebarContent className="text-primary-foreground dark:text-muted-foreground">
				<NavMain items={data.navMain} />
			</SidebarContent>
			<SidebarFooter className="text-primary-foreground dark:text-muted-foreground">
				<NavUser user={userData} />
			</SidebarFooter>
			<SidebarRail />
		</Sidebar>
	);
}
