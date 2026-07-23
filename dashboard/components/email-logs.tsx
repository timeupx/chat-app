"use client";

import { useState, useEffect, useMemo } from "react";
import { format, parseISO } from "date-fns";
import {
	Search,
	Mail,
	MailOpen,
	MailX,
	Clock,
	CheckCircle,
	XCircle,
	Eye,
	Download,
	RefreshCw,
	Send,
	ArrowUp,
	ArrowDown,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
	Table,
	TableBody,
	TableCell,
	TableHead,
	TableHeader,
	TableRow,
} from "@/components/ui/table";
import {
	Select,
	SelectContent,
	SelectItem,
	SelectTrigger,
	SelectValue,
} from "@/components/ui/select";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { Sheet, SheetContent } from "@/components/ui/sheet";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { toast } from "sonner";

// Types
type EmailStatus =
	| "sent"
	| "delivered"
	| "opened"
	| "clicked"
	| "bounced"
	| "failed"
	| "pending";
type EmailType =
	| "welcome"
	| "notification"
	| "marketing"
	| "transactional"
	| "password-reset"
	| "verification";
type SortField = "timestamp" | "status" | "type" | null;
type SortDirection = "asc" | "desc";

interface EmailLog {
	id: string;
	recipient: string;
	recipientName: string;
	subject: string;
	type: EmailType;
	status: EmailStatus;
	timestamp: string;
	deliveredAt?: string;
	openedAt?: string;
	clickedAt?: string;
	bounceReason?: string;
	failureReason?: string;
	templateId: string;
	templateName: string;
	content: string;
	metadata: {
		campaignId?: string;
		userId?: string;
		ipAddress?: string;
		userAgent?: string;
		clickCount?: number;
		openCount?: number;
	};
}

// Mock data
const mockEmailLogs: EmailLog[] = [
	{
		id: "1",
		recipient: "john.doe@example.com",
		recipientName: "John Doe",
		subject: "Welcome to our platform!",
		type: "welcome",
		status: "opened",
		timestamp: "2024-01-15T10:30:00Z",
		deliveredAt: "2024-01-15T10:30:15Z",
		openedAt: "2024-01-15T11:45:00Z",
		templateId: "welcome-001",
		templateName: "Welcome Email Template",
		content: "Welcome to our platform! We're excited to have you on board...",
		metadata: {
			userId: "user-123",
			ipAddress: "192.168.1.100",
			userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
			openCount: 2,
		},
	},
	{
		id: "2",
		recipient: "sarah.johnson@company.com",
		recipientName: "Sarah Johnson",
		subject: "Password Reset Request",
		type: "password-reset",
		status: "clicked",
		timestamp: "2024-01-15T09:15:00Z",
		deliveredAt: "2024-01-15T09:15:10Z",
		openedAt: "2024-01-15T09:20:00Z",
		clickedAt: "2024-01-15T09:22:00Z",
		templateId: "password-reset-001",
		templateName: "Password Reset Template",
		content:
			"You requested a password reset. Click the link below to reset your password...",
		metadata: {
			userId: "user-456",
			ipAddress: "203.0.113.1",
			userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)",
			clickCount: 1,
			openCount: 1,
		},
	},
	{
		id: "3",
		recipient: "invalid@nonexistent-domain.xyz",
		recipientName: "Invalid User",
		subject: "Account Verification",
		type: "verification",
		status: "bounced",
		timestamp: "2024-01-14T16:20:00Z",
		bounceReason: "Invalid email address - domain does not exist",
		templateId: "verification-001",
		templateName: "Email Verification Template",
		content: "Please verify your email address by clicking the link below...",
		metadata: {
			userId: "user-789",
		},
	},
	{
		id: "4",
		recipient: "michael.brown@startup.io",
		recipientName: "Michael Brown",
		subject: "New Feature Announcement",
		type: "notification",
		status: "delivered",
		timestamp: "2024-01-14T14:45:00Z",
		deliveredAt: "2024-01-14T14:45:20Z",
		templateId: "notification-001",
		templateName: "Feature Announcement Template",
		content: "We're excited to announce our new feature that will help you...",
		metadata: {
			campaignId: "campaign-123",
			userId: "user-101",
		},
	},
	{
		id: "5",
		recipient: "emily.davis@email.com",
		recipientName: "Emily Davis",
		subject: "Special Offer - 50% Off!",
		type: "marketing",
		status: "failed",
		timestamp: "2024-01-13T11:30:00Z",
		failureReason: "SMTP server temporarily unavailable",
		templateId: "marketing-001",
		templateName: "Promotional Email Template",
		content:
			"Don't miss out on our special offer! Get 50% off on all premium plans...",
		metadata: {
			campaignId: "campaign-456",
			userId: "user-202",
		},
	},
	{
		id: "6",
		recipient: "david.wilson@domain.com",
		recipientName: "David Wilson",
		subject: "Order Confirmation #12345",
		type: "transactional",
		status: "sent",
		timestamp: "2024-01-13T09:00:00Z",
		templateId: "order-confirmation-001",
		templateName: "Order Confirmation Template",
		content:
			"Thank you for your order! Here are the details of your purchase...",
		metadata: {
			userId: "user-303",
			campaignId: "order-12345",
		},
	},
];

const ITEMS_PER_PAGE = 5;

export function EmailLogs() {
	const [emailLogs, setEmailLogs] = useState<EmailLog[]>([]);
	const [loading, setLoading] = useState(true);
	const [searchTerm, setSearchTerm] = useState("");
	const [statusFilter, setStatusFilter] = useState<EmailStatus | "all">("all");
	const [typeFilter, setTypeFilter] = useState<EmailType | "all">("all");
	const [currentPage, setCurrentPage] = useState(1);
	const [selectedEmail, setSelectedEmail] = useState<EmailLog | null>(null);
	const [isSheetOpen, setIsSheetOpen] = useState(false);
	const [sortField, setSortField] = useState<SortField>(null);
	const [sortDirection, setSortDirection] = useState<SortDirection>("desc");
	// eslint-disable-next-line @typescript-eslint/no-unused-vars
	const [dateRange, setDateRange] = useState<{ from?: Date; to?: Date }>({});

	// Simulate API call
	useEffect(() => {
		const fetchEmailLogs = async () => {
			setLoading(true);
			await new Promise((resolve) => setTimeout(resolve, 1000));
			setEmailLogs(mockEmailLogs);
			setLoading(false);
		};

		fetchEmailLogs();
	}, []);

	// Handle sorting
	const handleSort = (field: SortField) => {
		if (sortField === field) {
			setSortDirection(sortDirection === "asc" ? "desc" : "asc");
		} else {
			setSortField(field);
			setSortDirection("desc");
		}
	};

	// Filter, sort, and search emails
	const filteredEmails = useMemo(() => {
		let filtered = emailLogs.filter((email) => {
			// Search filter
			const matchesSearch =
				searchTerm === "" ||
				email.recipient.toLowerCase().includes(searchTerm.toLowerCase()) ||
				email.recipientName.toLowerCase().includes(searchTerm.toLowerCase()) ||
				email.subject.toLowerCase().includes(searchTerm.toLowerCase());

			// Status filter
			const matchesStatus =
				statusFilter === "all" || email.status === statusFilter;

			// Type filter
			const matchesType = typeFilter === "all" || email.type === typeFilter;

			// Date range filter
			const emailDate = new Date(email.timestamp);
			const matchesDateRange =
				(!dateRange.from || emailDate >= dateRange.from) &&
				(!dateRange.to || emailDate <= dateRange.to);

			return matchesSearch && matchesStatus && matchesType && matchesDateRange;
		});

		// Sort
		if (sortField) {
			filtered = [...filtered].sort((a, b) => {
				if (sortField === "timestamp") {
					const dateA = new Date(a.timestamp).getTime();
					const dateB = new Date(b.timestamp).getTime();
					return sortDirection === "asc" ? dateA - dateB : dateB - dateA;
				} else if (sortField === "status") {
					return sortDirection === "asc"
						? a.status.localeCompare(b.status)
						: b.status.localeCompare(a.status);
				} else if (sortField === "type") {
					return sortDirection === "asc"
						? a.type.localeCompare(b.type)
						: b.type.localeCompare(a.type);
				}
				return 0;
			});
		}

		return filtered;
	}, [
		emailLogs,
		searchTerm,
		statusFilter,
		typeFilter,
		dateRange,
		sortField,
		sortDirection,
	]);

	// Pagination
	const totalPages = Math.ceil(filteredEmails.length / ITEMS_PER_PAGE);
	const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
	const paginatedEmails = filteredEmails.slice(
		startIndex,
		startIndex + ITEMS_PER_PAGE
	);

	// Reset to first page when filters change
	useEffect(() => {
		setCurrentPage(1);
	}, [searchTerm, statusFilter, typeFilter, dateRange]);

	const handleViewEmail = (email: EmailLog) => {
		setSelectedEmail(email);
		setIsSheetOpen(true);
	};

	const handleRefresh = async () => {
		setLoading(true);
		await new Promise((resolve) => setTimeout(resolve, 1000));
		// In real app, refetch data
		setLoading(false);
		toast.success("Email logs refreshed");
	};

	const handleExport = () => {
		const csvContent = [
			["ID", "Recipient", "Subject", "Type", "Status", "Timestamp"],
			...filteredEmails.map((email) => [
				email.id,
				email.recipient,
				email.subject,
				email.type,
				email.status,
				email.timestamp,
			]),
		]
			.map((row) => row.join(","))
			.join("\n");

		const blob = new Blob([csvContent], { type: "text/csv" });
		const url = URL.createObjectURL(blob);
		const a = document.createElement("a");
		a.href = url;
		a.download = `email-logs-${format(new Date(), "yyyy-MM-dd")}.csv`;
		a.click();
		URL.revokeObjectURL(url);

		toast.success("Email logs exported successfully");
	};

	const formatDate = (dateString: string) => {
		return format(parseISO(dateString), "MMM d, yyyy h:mm a");
	};

	const getStatusBadge = (status: EmailStatus) => {
		const statusConfig = {
			sent: { color: "bg-blue-500 text-white", icon: Send },
			delivered: { color: "bg-green-500 text-white", icon: CheckCircle },
			opened: { color: "bg-purple-500 text-white", icon: MailOpen },
			clicked: { color: "bg-indigo-500 text-white", icon: Eye },
			bounced: { color: "bg-orange-500 text-white", icon: MailX },
			failed: { color: "bg-red-500 text-white", icon: XCircle },
			pending: { color: "bg-gray-500 text-white", icon: Clock },
		};

		const config = statusConfig[status];
		const Icon = config.icon;

		return (
			<Badge className={config.color}>
				<Icon className="h-3 w-3 mr-1" />
				{status.charAt(0).toUpperCase() + status.slice(1)}
			</Badge>
		);
	};

	const getTypeBadge = (type: EmailType) => {
		const typeColors = {
			welcome: "bg-green-100 text-green-800 border-green-200",
			notification: "bg-blue-100 text-blue-800 border-blue-200",
			marketing: "bg-purple-100 text-purple-800 border-purple-200",
			transactional: "bg-orange-100 text-orange-800 border-orange-200",
			"password-reset": "bg-red-100 text-red-800 border-red-200",
			verification: "bg-yellow-100 text-yellow-800 border-yellow-200",
		};

		return (
			<Badge variant="outline" className={typeColors[type]}>
				{type.replace("-", " ").replace(/\b\w/g, (l) => l.toUpperCase())}
			</Badge>
		);
	};

	// Statistics
	const stats = useMemo(() => {
		const total = filteredEmails.length;
		const delivered = filteredEmails.filter(
			(e) =>
				e.status === "delivered" ||
				e.status === "opened" ||
				e.status === "clicked"
		).length;
		const opened = filteredEmails.filter(
			(e) => e.status === "opened" || e.status === "clicked"
		).length;
		const clicked = filteredEmails.filter((e) => e.status === "clicked").length;
		const failed = filteredEmails.filter(
			(e) => e.status === "failed" || e.status === "bounced"
		).length;

		return {
			total,
			delivered,
			opened,
			clicked,
			failed,
			deliveryRate: total > 0 ? ((delivered / total) * 100).toFixed(1) : "0",
			openRate: delivered > 0 ? ((opened / delivered) * 100).toFixed(1) : "0",
			clickRate: opened > 0 ? ((clicked / opened) * 100).toFixed(1) : "0",
		};
	}, [filteredEmails]);

	if (loading) {
		return (
			<div className="space-y-4">
				<div className="flex items-center justify-between">
					<div className="space-y-1">
						<h2 className="text-2xl font-bold tracking-tight">Email Logs</h2>
						<p className="text-muted-foreground">Loading email logs...</p>
					</div>
				</div>
				<div className="flex items-center justify-center h-64">
					<div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
				</div>
			</div>
		);
	}

	return (
		<>
			<div className="space-y-6">
				{/* Header */}
				<div className="flex items-center justify-between">
					<div className="space-y-1">
						<h2 className="text-2xl font-bold tracking-tight flex items-center gap-2">
							<Mail className="h-6 w-6" />
							Email Logs
						</h2>
						<p className="text-muted-foreground">
							Monitor and track all email communications sent from your system.
						</p>
					</div>
					<div className="flex items-center gap-2">
						<Button
							variant="outline"
							onClick={handleRefresh}
							disabled={loading}
						>
							<RefreshCw className="h-4 w-4 mr-2" />
							Refresh
						</Button>
						<Button variant="outline" onClick={handleExport}>
							<Download className="h-4 w-4 mr-2" />
							Export
						</Button>
					</div>
				</div>

				{/* Statistics Cards */}
				<div className="grid grid-cols-1 md:grid-cols-5 gap-4">
					<Card>
						<CardHeader className="pb-2">
							<CardTitle className="text-sm font-medium text-muted-foreground">
								Total Emails
							</CardTitle>
							<div className="text-2xl font-bold">{stats.total}</div>
						</CardHeader>
					</Card>
					<Card>
						<CardHeader className="pb-2">
							<CardTitle className="text-sm font-medium text-muted-foreground">
								Delivery Rate
							</CardTitle>
							<div className="text-2xl font-bold">{stats.deliveryRate}%</div>
						</CardHeader>
					</Card>
					<Card>
						<CardHeader className="pb-2">
							<CardTitle className="text-sm font-medium text-muted-foreground">
								Open Rate
							</CardTitle>
							<div className="text-2xl font-bold">{stats.openRate}%</div>
						</CardHeader>
					</Card>
					<Card>
						<CardHeader className="pb-2">
							<CardTitle className="text-sm font-medium text-muted-foreground">
								Click Rate
							</CardTitle>
							<div className="text-2xl font-bold">{stats.clickRate}%</div>
						</CardHeader>
					</Card>
					<Card>
						<CardHeader className="pb-2">
							<CardTitle className="text-sm font-medium text-muted-foreground">
								Failed
							</CardTitle>
							<div className="text-2xl font-bold text-red-600">
								{stats.failed}
							</div>
						</CardHeader>
					</Card>
				</div>

				{/* Filters */}
				<div className="flex flex-col lg:flex-row gap-4">
					<div className="relative flex-1">
						<Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
						<Input
							placeholder="Search by recipient, subject, or name..."
							value={searchTerm}
							onChange={(e) => setSearchTerm(e.target.value)}
							className="pl-10"
						/>
					</div>
					<Select
						value={statusFilter}
						onValueChange={(value: EmailStatus | "all") =>
							setStatusFilter(value)
						}
					>
						<SelectTrigger className="w-full lg:w-[180px]">
							<SelectValue placeholder="Filter by status" />
						</SelectTrigger>
						<SelectContent>
							<SelectItem value="all">All Statuses</SelectItem>
							<SelectItem value="sent">Sent</SelectItem>
							<SelectItem value="delivered">Delivered</SelectItem>
							<SelectItem value="opened">Opened</SelectItem>
							<SelectItem value="clicked">Clicked</SelectItem>
							<SelectItem value="bounced">Bounced</SelectItem>
							<SelectItem value="failed">Failed</SelectItem>
							<SelectItem value="pending">Pending</SelectItem>
						</SelectContent>
					</Select>
					<Select
						value={typeFilter}
						onValueChange={(value: EmailType | "all") => setTypeFilter(value)}
					>
						<SelectTrigger className="w-full lg:w-[180px]">
							<SelectValue placeholder="Filter by type" />
						</SelectTrigger>
						<SelectContent>
							<SelectItem value="all">All Types</SelectItem>
							<SelectItem value="welcome">Welcome</SelectItem>
							<SelectItem value="notification">Notification</SelectItem>
							<SelectItem value="marketing">Marketing</SelectItem>
							<SelectItem value="transactional">Transactional</SelectItem>
							<SelectItem value="password-reset">Password Reset</SelectItem>
							<SelectItem value="verification">Verification</SelectItem>
						</SelectContent>
					</Select>
				</div>

				{/* Results Summary */}
				<div className="text-sm text-muted-foreground">
					Showing {paginatedEmails.length} of {filteredEmails.length} emails
				</div>

				{/* Email Logs Table */}
				<div className="border rounded-md border-border">
					<Table>
						<TableHeader>
							<TableRow className="hover:bg-transparent">
								<TableHead className="w-16">#</TableHead>
								<TableHead>Recipient</TableHead>
								<TableHead>Subject</TableHead>
								<TableHead>Type</TableHead>
								<TableHead
									className="cursor-pointer hover:bg-muted/50"
									onClick={() => handleSort("status")}
								>
									<div className="flex items-center gap-1">
										Status
										{sortField === "status" &&
											(sortDirection === "asc" ? (
												<ArrowUp className="h-3 w-3" />
											) : (
												<ArrowDown className="h-3 w-3" />
											))}
									</div>
								</TableHead>
								<TableHead
									className="cursor-pointer hover:bg-muted/50"
									onClick={() => handleSort("timestamp")}
								>
									<div className="flex items-center gap-1">
										Timestamp
										{sortField === "timestamp" &&
											(sortDirection === "asc" ? (
												<ArrowUp className="h-3 w-3" />
											) : (
												<ArrowDown className="h-3 w-3" />
											))}
									</div>
								</TableHead>
								<TableHead className="w-[100px]">Actions</TableHead>
							</TableRow>
						</TableHeader>
						<TableBody>
							{paginatedEmails.length === 0 ? (
								<TableRow>
									<TableCell
										colSpan={7}
										className="text-center py-8 text-muted-foreground"
									>
										No email logs found matching your criteria.
									</TableCell>
								</TableRow>
							) : (
								paginatedEmails.map((email, index) => (
									<TableRow key={email.id}>
										<TableCell className="font-medium">
											{startIndex + index + 1}
										</TableCell>
										<TableCell>
											<div className="space-y-1">
												<p className="font-medium">{email.recipientName}</p>
												<p className="text-sm text-muted-foreground">
													{email.recipient}
												</p>
											</div>
										</TableCell>
										<TableCell className="max-w-[300px] truncate">
											{email.subject}
										</TableCell>
										<TableCell>{getTypeBadge(email.type)}</TableCell>
										<TableCell>{getStatusBadge(email.status)}</TableCell>
										<TableCell>{formatDate(email.timestamp)}</TableCell>
										<TableCell>
											<Button
												variant="ghost"
												size="icon"
												onClick={() => handleViewEmail(email)}
												className="h-8 w-8"
											>
												<Eye className="h-4 w-4" />
											</Button>
										</TableCell>
									</TableRow>
								))
							)}
						</TableBody>
					</Table>
				</div>

				{/* Pagination */}
				{totalPages > 1 && (
					<div className="flex items-center justify-between">
						<div className="text-sm text-muted-foreground">
							Page {currentPage} of {totalPages}
						</div>
						<div className="flex items-center gap-2">
							<Button
								variant="outline"
								size="sm"
								onClick={() => setCurrentPage((prev) => Math.max(1, prev - 1))}
								disabled={currentPage === 1}
							>
								Previous
							</Button>
							<Button
								variant="outline"
								size="sm"
								onClick={() =>
									setCurrentPage((prev) => Math.min(totalPages, prev + 1))
								}
								disabled={currentPage === totalPages}
							>
								Next
							</Button>
						</div>
					</div>
				)}
			</div>

			{/* Email Details Sheet */}
			<EmailDetailsSheet
				email={selectedEmail}
				open={isSheetOpen}
				onOpenChange={setIsSheetOpen}
			/>
		</>
	);
}

// Email Details Sheet Component
function EmailDetailsSheet({
	email,
	open,
	onOpenChange,
}: {
	email: EmailLog | null;
	open: boolean;
	onOpenChange: (open: boolean) => void;
}) {
	if (!email) return null;

	const formatDate = (dateString: string) => {
		return format(parseISO(dateString), "MMMM d, yyyy 'at' h:mm:ss a");
	};

	const getStatusIcon = (status: EmailStatus) => {
		const icons = {
			sent: Send,
			delivered: CheckCircle,
			opened: MailOpen,
			clicked: Eye,
			bounced: MailX,
			failed: XCircle,
			pending: Clock,
		};
		return icons[status];
	};

	const StatusIcon = getStatusIcon(email.status);

	return (
		<Sheet open={open} onOpenChange={onOpenChange}>
			<SheetContent className="w-full sm:max-w-2xl p-3 md:p-6">
				<ScrollArea className="h-full pr-4">
					<div className="space-y-6 py-6">
						{/* Email Header */}
						<div className="space-y-4">
							<div className="flex items-center gap-2">
								<StatusIcon className="h-5 w-5" />
								<h3 className="font-semibold text-lg">{email.subject}</h3>
							</div>
							<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Recipient</p>
									<p className="font-medium">{email.recipientName}</p>
									<p className="text-sm text-muted-foreground">
										{email.recipient}
									</p>
								</div>
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Status</p>
									<div className="flex items-center gap-2">
										<StatusIcon className="h-4 w-4" />
										<span className="font-medium capitalize">
											{email.status}
										</span>
									</div>
								</div>
							</div>
						</div>

						<Separator />

						{/* Timeline */}
						<div className="space-y-4">
							<h4 className="font-medium">Email Timeline</h4>
							<div className="space-y-3">
								<div className="flex items-center gap-3">
									<div className="w-2 h-2 bg-blue-500 rounded-full"></div>
									<div className="flex-1">
										<p className="text-sm font-medium">Email Sent</p>
										<p className="text-xs text-muted-foreground">
											{formatDate(email.timestamp)}
										</p>
									</div>
								</div>

								{email.deliveredAt && (
									<div className="flex items-center gap-3">
										<div className="w-2 h-2 bg-green-500 rounded-full"></div>
										<div className="flex-1">
											<p className="text-sm font-medium">Email Delivered</p>
											<p className="text-xs text-muted-foreground">
												{formatDate(email.deliveredAt)}
											</p>
										</div>
									</div>
								)}

								{email.openedAt && (
									<div className="flex items-center gap-3">
										<div className="w-2 h-2 bg-purple-500 rounded-full"></div>
										<div className="flex-1">
											<p className="text-sm font-medium">Email Opened</p>
											<p className="text-xs text-muted-foreground">
												{formatDate(email.openedAt)}
											</p>
										</div>
									</div>
								)}

								{email.clickedAt && (
									<div className="flex items-center gap-3">
										<div className="w-2 h-2 bg-indigo-500 rounded-full"></div>
										<div className="flex-1">
											<p className="text-sm font-medium">Link Clicked</p>
											<p className="text-xs text-muted-foreground">
												{formatDate(email.clickedAt)}
											</p>
										</div>
									</div>
								)}

								{email.bounceReason && (
									<div className="flex items-center gap-3">
										<div className="w-2 h-2 bg-orange-500 rounded-full"></div>
										<div className="flex-1">
											<p className="text-sm font-medium">Email Bounced</p>
											<p className="text-xs text-muted-foreground">
												{email.bounceReason}
											</p>
										</div>
									</div>
								)}

								{email.failureReason && (
									<div className="flex items-center gap-3">
										<div className="w-2 h-2 bg-red-500 rounded-full"></div>
										<div className="flex-1">
											<p className="text-sm font-medium">Email Failed</p>
											<p className="text-xs text-muted-foreground">
												{email.failureReason}
											</p>
										</div>
									</div>
								)}
							</div>
						</div>

						<Separator />

						{/* Template Information */}
						<div className="space-y-4">
							<h4 className="font-medium">Template Information</h4>
							<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Template ID</p>
									<p className="font-mono text-sm">{email.templateId}</p>
								</div>
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Template Name</p>
									<p className="font-medium">{email.templateName}</p>
								</div>
							</div>
						</div>

						<Separator />

						{/* Email Content */}
						<div className="space-y-4">
							<h4 className="font-medium">Email Content</h4>
							<div className="bg-muted p-4 rounded-lg">
								<p className="text-sm leading-relaxed">{email.content}</p>
							</div>
						</div>

						<Separator />

						{/* Metadata */}
						<div className="space-y-4">
							<h4 className="font-medium">Metadata</h4>
							<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
								{email.metadata.userId && (
									<div className="space-y-1">
										<p className="text-sm text-muted-foreground">User ID</p>
										<p className="font-mono text-sm">{email.metadata.userId}</p>
									</div>
								)}
								{email.metadata.campaignId && (
									<div className="space-y-1">
										<p className="text-sm text-muted-foreground">Campaign ID</p>
										<p className="font-mono text-sm">
											{email.metadata.campaignId}
										</p>
									</div>
								)}
								{email.metadata.ipAddress && (
									<div className="space-y-1">
										<p className="text-sm text-muted-foreground">IP Address</p>
										<p className="font-mono text-sm">
											{email.metadata.ipAddress}
										</p>
									</div>
								)}
								{email.metadata.openCount && (
									<div className="space-y-1">
										<p className="text-sm text-muted-foreground">Open Count</p>
										<p className="font-medium">{email.metadata.openCount}</p>
									</div>
								)}
								{email.metadata.clickCount && (
									<div className="space-y-1">
										<p className="text-sm text-muted-foreground">Click Count</p>
										<p className="font-medium">{email.metadata.clickCount}</p>
									</div>
								)}
							</div>
							{email.metadata.userAgent && (
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">User Agent</p>
									<p className="text-xs font-mono break-all">
										{email.metadata.userAgent}
									</p>
								</div>
							)}
						</div>
					</div>
				</ScrollArea>
			</SheetContent>
		</Sheet>
	);
}
