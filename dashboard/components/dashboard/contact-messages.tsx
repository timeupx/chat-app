"use client";

import { useState, useEffect, useMemo } from "react";
import {
	Search,
	Eye,
	Trash2,
	Filter,
	Mail,
	Phone,
	User,
	Calendar,
	MessageSquare,
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
import {
	AlertDialog,
	AlertDialogAction,
	AlertDialogCancel,
	AlertDialogContent,
	AlertDialogDescription,
	AlertDialogFooter,
	AlertDialogHeader,
	AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import {
	Sheet,
	SheetContent,
	SheetDescription,
	SheetHeader,
	SheetTitle,
} from "@/components/ui/sheet";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { toast } from "sonner";
import {
	ContactMessage,
	useDeleteMessageMutation,
	useGetAllMessagesQuery,
	useReadMessageMutation,
} from "@/redux/feature/contact/contactApi";

const ITEMS_PER_PAGE = 10;

export function ContactMessages() {
	const [messages, setMessages] = useState<ContactMessage[]>([]);
	const [loading, setLoading] = useState(true);
	const [searchTerm, setSearchTerm] = useState("");
	const [statusFilter, setStatusFilter] = useState<"all" | "read" | "unread">(
		"all"
	);
	const [currentPage, setCurrentPage] = useState(1);
	const [selectedMessage, setSelectedMessage] = useState<ContactMessage | null>(
		null
	);
	const [messageToDelete, setMessageToDelete] = useState<ContactMessage | null>(
		null
	);
	const [isSheetOpen, setIsSheetOpen] = useState(false);

	const { data } = useGetAllMessagesQuery({});
	const [readMessage] = useReadMessageMutation();
	const [deleteMessage] = useDeleteMessageMutation();

	useEffect(() => {
		if (data) {
			setMessages(data.data);
			setLoading(false);
		}
	}, [data]);

	const filteredMessages = useMemo(() => {
		return messages.filter((message) => {
			const matchesSearch =
				message.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
				message.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
				message.phone.includes(searchTerm);

			const matchesStatus =
				statusFilter === "all" ||
				(statusFilter === "read" && message.isRead) ||
				(statusFilter === "unread" && !message.isRead);

			return matchesSearch && matchesStatus;
		});
	}, [messages, searchTerm, statusFilter]);

	const totalPages = Math.ceil(filteredMessages.length / ITEMS_PER_PAGE);
	const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
	const paginatedMessages = filteredMessages.slice(
		startIndex,
		startIndex + ITEMS_PER_PAGE
	);

	useEffect(() => {
		setCurrentPage(1);
	}, [searchTerm, statusFilter]);

	const handleViewMessage = async (message: ContactMessage) => {
		setSelectedMessage(message);
		setIsSheetOpen(true);
		await readMessage(message.id);
	};

	const handleDeleteMessage = async (message: ContactMessage) => {
		await deleteMessage(message.id);
		setMessages((prev) => prev.filter((m) => m.id !== message.id));
		setMessageToDelete(null);
		toast.success("Message deleted successfully");

		const newFilteredCount = filteredMessages.length - 1;
		const newTotalPages = Math.ceil(newFilteredCount / ITEMS_PER_PAGE);
		if (currentPage > newTotalPages && newTotalPages > 0) {
			setCurrentPage(newTotalPages);
		}
	};

	const formatDate = (dateString: Date) => {
		return new Date(dateString).toLocaleString(undefined, {
			year: "numeric",
			month: "short",
			day: "numeric",
			hour: "2-digit",
			minute: "2-digit",
		});
	};

	const getStatusBadge = (isRead: boolean) => {
		return !isRead ? (
			<Badge className="bg-blue-500 hover:bg-blue-600 text-white">Unread</Badge>
		) : (
			<Badge variant="outline" className="text-foreground border-border">
				Read
			</Badge>
		);
	};

	const unreadCount = messages.filter((m) => !m.isRead).length;

	if (loading) {
		return (
			<div className="space-y-4">
				<div className="flex items-center justify-between">
					<h2 className="text-2xl font-bold flex items-center gap-2">
						<MessageSquare className="h-6 w-6" />
						Contact Messages
					</h2>
					<p className="text-muted-foreground">Loading messages...</p>
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
				<div className="flex items-center justify-between">
					<h2 className="text-2xl font-bold flex items-center gap-2">
						<MessageSquare className="h-6 w-6" />
						Contact Messages
						{unreadCount > 0 && (
							<Badge className="ml-2 bg-blue-500 text-white">
								{unreadCount} unread
							</Badge>
						)}
					</h2>
				</div>

				<div className="flex flex-col sm:flex-row gap-4">
					<div className="relative flex-1">
						<Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
						<Input
							placeholder="Search by name, email, or phone..."
							value={searchTerm}
							onChange={(e) => setSearchTerm(e.target.value)}
							className="pl-10"
						/>
					</div>
					<Select
						value={statusFilter}
						onValueChange={(value: "all" | "read" | "unread") =>
							setStatusFilter(value)
						}
					>
						<SelectTrigger className="w-full sm:w-[180px]">
							<Filter className="h-4 w-4 mr-2" />
							<SelectValue placeholder="Filter by status" />
						</SelectTrigger>
						<SelectContent>
							<SelectItem value="all">All Messages</SelectItem>
							<SelectItem value="unread">Unread Only</SelectItem>
							<SelectItem value="read">Read Only</SelectItem>
						</SelectContent>
					</Select>
				</div>

				<div className="text-sm text-muted-foreground">
					Showing {paginatedMessages.length} of {filteredMessages.length}{" "}
					messages
				</div>

				<div className="border rounded-md border-border">
					<Table>
						<TableHeader>
							<TableRow>
								<TableHead className="w-16">#</TableHead>
								<TableHead>Subject</TableHead>
								<TableHead>Name</TableHead>
								<TableHead>Email</TableHead>
								<TableHead>Phone</TableHead>
								<TableHead>Status</TableHead>
								<TableHead className="w-24">Actions</TableHead>
							</TableRow>
						</TableHeader>
						<TableBody>
							{paginatedMessages.length === 0 ? (
								<TableRow>
									<TableCell
										colSpan={7}
										className="text-center py-8 text-muted-foreground"
									>
										No messages found matching your criteria.
									</TableCell>
								</TableRow>
							) : (
								paginatedMessages.map((message, index) => (
									<TableRow
										key={message.id}
										className={
											!message.isRead
												? "bg-blue-500/5 dark:bg-blue-950/20 hover:bg-blue-500/10 dark:hover:bg-blue-950/30"
												: undefined
										}
									>
										<TableCell>{startIndex + index + 1}</TableCell>
										<TableCell className="max-w-[200px] truncate">
											{message.subject}
										</TableCell>
										<TableCell>{message.name}</TableCell>
										<TableCell className="font-mono text-sm">
											{message.email}
										</TableCell>
										<TableCell className="font-mono text-sm">
											{message.phone}
										</TableCell>
										<TableCell>{getStatusBadge(message.isRead)}</TableCell>
										<TableCell>
											<div className="flex gap-2">
												<Button
													variant="ghost"
													size="icon"
													onClick={() => handleViewMessage(message)}
												>
													<Eye className="h-5 w-5" />
												</Button>
												<Button
													variant="ghost"
													size="icon"
													onClick={() => setMessageToDelete(message)}
													className="text-destructive hover:text-destructive hover:bg-destructive/10"
												>
													<Trash2 className="h-5 w-5" />
												</Button>
											</div>
										</TableCell>
									</TableRow>
								))
							)}
						</TableBody>
					</Table>
				</div>

				{totalPages > 1 && (
					<div className="flex items-center justify-between">
						<div className="text-sm text-muted-foreground">
							Page {currentPage} of {totalPages}
						</div>
						<div className="flex items-center gap-2">
							<Button
								variant="outline"
								size="sm"
								onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
								disabled={currentPage === 1}
							>
								Previous
							</Button>
							<Button
								variant="outline"
								size="sm"
								onClick={() =>
									setCurrentPage((p) => Math.min(totalPages, p + 1))
								}
								disabled={currentPage === totalPages}
							>
								Next
							</Button>
						</div>
					</div>
				)}
			</div>

			<Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
				<SheetContent className="w-full sm:max-w-lg p-4 md:p-6">
					{selectedMessage && (
						<>
							<SheetHeader className="p-0">
								<SheetTitle className="flex items-center gap-2">
									<Mail className="h-5 w-5" />
									Message Details
								</SheetTitle>
								<SheetDescription>
									Contact form submission from {selectedMessage.name}
								</SheetDescription>
							</SheetHeader>

							<ScrollArea className="h-full pr-4">
								<div className="space-y-6 py-6">
									{/* Status and Date */}
									<div className="flex items-center justify-between">
										{getStatusBadge(selectedMessage.isRead)}
										<div className="text-sm text-muted-foreground">
											{formatDate(selectedMessage.createdAt)}
										</div>
									</div>

									<Separator />

									{/* Subject */}
									<div className="space-y-2">
										<h3 className="font-semibold text-lg">
											{selectedMessage.subject}
										</h3>
									</div>

									<Separator />

									{/* Contact Information */}
									<div className="space-y-4">
										<h4 className="font-medium">Contact Information</h4>

										<div className="space-y-3">
											<div className="flex items-center gap-3">
												<User className="h-4 w-4 text-muted-foreground" />
												<div>
													<p className="font-medium">{selectedMessage.name}</p>
												</div>
											</div>

											<div className="flex items-center gap-3">
												<Mail className="h-4 w-4 text-muted-foreground" />
												<div>
													<p className="font-mono text-sm">
														{selectedMessage.email}
													</p>
												</div>
											</div>

											<div className="flex items-center gap-3">
												<Phone className="h-4 w-4 text-muted-foreground" />
												<div>
													<p className="font-mono text-sm">
														{selectedMessage.phone}
													</p>
												</div>
											</div>
										</div>
									</div>

									<Separator />

									{/* Message Content */}
									<div className="space-y-4">
										<h4 className="font-medium">Message</h4>
										<div className="bg-muted p-4 rounded-lg">
											<p className="text-sm leading-relaxed whitespace-pre-wrap">
												{selectedMessage.message}
											</p>
										</div>
									</div>

									{/* Timestamps */}
									<div className="space-y-2 text-xs text-muted-foreground">
										<div className="flex items-center gap-2">
											<Calendar className="h-3 w-3" />
											<span>
												Received: {formatDate(selectedMessage.createdAt)}
											</span>
										</div>
										{selectedMessage.updatedAt !==
											selectedMessage.createdAt && (
											<div className="flex items-center gap-2">
												<Calendar className="h-3 w-3" />
												<span>
													Last updated: {formatDate(selectedMessage.updatedAt)}
												</span>
											</div>
										)}
									</div>
								</div>
							</ScrollArea>
						</>
					)}
				</SheetContent>
			</Sheet>

			<AlertDialog
				open={!!messageToDelete}
				onOpenChange={() => setMessageToDelete(null)}
			>
				<AlertDialogContent>
					<AlertDialogHeader>
						<AlertDialogTitle>Delete Message</AlertDialogTitle>
						<AlertDialogDescription>
							Are you sure you want to delete the message from{" "}
							<strong>{messageToDelete?.name}</strong>?
						</AlertDialogDescription>
					</AlertDialogHeader>
					<AlertDialogFooter>
						<AlertDialogCancel>Cancel</AlertDialogCancel>
						<AlertDialogAction
							onClick={() =>
								messageToDelete && handleDeleteMessage(messageToDelete)
							}
							className="bg-destructive hover:bg-destructive/90"
						>
							Delete Message
						</AlertDialogAction>
					</AlertDialogFooter>
				</AlertDialogContent>
			</AlertDialog>
		</>
	);
}
