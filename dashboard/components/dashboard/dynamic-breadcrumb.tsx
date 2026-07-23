"use client";

import { useMemo } from "react";
import { usePathname } from "next/navigation";

import {
	Breadcrumb,
	BreadcrumbItem,
	BreadcrumbLink,
	BreadcrumbList,
	BreadcrumbPage,
	BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

interface BreadcrumbSegment {
	label: string;
	href: string;
	isCurrentPage: boolean;
}

// You can customize these mappings to show more user-friendly names
const pathMappings: Record<string, string> = {
	"data-fetching": "Data Fetching",
	"building-your-application": "Building Your Application",
	"system-settings": "System Settings",
	appearance: "Appearance",
	docs: "Documentation",
	// Add more mappings as needed
};

export function DynamicBreadcrumb() {
	const pathname = usePathname();

	const breadcrumbs = useMemo(() => {
		// Skip empty segments and remove trailing slashes
		const segments = pathname.split("/").filter(Boolean);

		// Generate breadcrumb segments with proper links
		const breadcrumbSegments: BreadcrumbSegment[] = segments.map(
			(segment, index) => {
				// Create the href for this segment (all segments up to this point)
				const href = `/${segments.slice(0, index + 1).join("/")}`;

				// Get a user-friendly label from our mappings, or format the segment
				const label =
					pathMappings[segment] ||
					segment
						.replace(/-/g, " ")
						.replace(/\b\w/g, (char) => char.toUpperCase());

				// Check if this is the current/last segment
				const isCurrentPage = index === segments.length - 1;

				return { label, href, isCurrentPage };
			}
		);

		return breadcrumbSegments;
	}, [pathname]);

	// If we're on the homepage, show just "Dashboard"
	if (breadcrumbs.length === 0) {
		return (
			<Breadcrumb className="truncate">
				<BreadcrumbList>
					<BreadcrumbItem>
						<BreadcrumbPage>Dashboard</BreadcrumbPage>
					</BreadcrumbItem>
				</BreadcrumbList>
			</Breadcrumb>
		);
	}

	return (
		<Breadcrumb className="truncate">
			<BreadcrumbList>
				{/* Dashboard link (renamed from Home) */}
				<BreadcrumbItem className="hidden md:block">
					<BreadcrumbLink href="/">Dashboard</BreadcrumbLink>
				</BreadcrumbItem>

				{/* Dynamic breadcrumb items with separators */}
				{breadcrumbs.map((breadcrumb, index) => (
					<>
						<BreadcrumbSeparator
							key={`separator-${index}`}
							className="hidden md:block"
						/>
						<BreadcrumbItem
							key={breadcrumb.href}
							className={
								index < breadcrumbs.length - 1 ? "hidden md:block" : ""
							}
						>
							{breadcrumb.isCurrentPage ? (
								<BreadcrumbPage>{breadcrumb.label}</BreadcrumbPage>
							) : (
								<BreadcrumbLink href={breadcrumb.href}>
									{breadcrumb.label}
								</BreadcrumbLink>
							)}
						</BreadcrumbItem>
					</>
				))}
			</BreadcrumbList>
		</Breadcrumb>
	);
}
