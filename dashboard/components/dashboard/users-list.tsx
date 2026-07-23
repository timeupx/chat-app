"use client";

import { Textarea } from "@/components/ui/textarea";
import { useState, useEffect, useMemo } from "react";
import { format } from "date-fns";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import {
	Search,
	Edit,
	Trash2,
	Ban,
	CheckCircle,
	UserPlus,
	Filter,
	Eye,
	ChevronDown,
	X,
	ArrowUp,
	ArrowDown,
	Users,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
	Table,
	TableBody,
	TableCell,
	TableHead,
	TableHeader,
	TableRow,
} from "@/components/ui/table";
import {
	DropdownMenu,
	DropdownMenuContent,
	DropdownMenuItem,
	DropdownMenuTrigger,
	DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
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
	SheetHeader,
	SheetTitle,
} from "@/components/ui/sheet";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
	Select,
	SelectContent,
	SelectItem,
	SelectTrigger,
	SelectValue,
} from "@/components/ui/select";
import {
	Form,
	FormControl,
	FormDescription,
	FormField,
	FormItem,
	FormLabel,
	FormMessage,
} from "@/components/ui/form";
import { toast } from "sonner";
import {
	useBlockUserMutation,
	useCreateUserMutation,
	useDeleteUserMutation,
	useGetAllUsersQuery,
	useUpdateUserMutation,
} from "@/redux/feature/user/userApi";

// Types
type UserRole = "ADMIN" | "USER";
type UserStatus = "PENDING" | "ACTIVE" | "INACTIVE" | "SUSPENDED";
type SortField = "joinDate" | "status" | null;
type SortDirection = "asc" | "desc";

interface TUser {
	id: string;
	name: string;
	email: string;
	phone: string;
	role: UserRole;
	status: UserStatus;
	createdAt: Date;
	photo?: string;
	address?: string;
	bio?: string;
	password?: string;
}

// Form schemas
const userFormSchema = z.object({
	name: z.string().min(2, "Name must be at least 2 characters"),
	email: z.string().email("Please enter a valid email address"),
	phone: z.string().min(10, "Phone number must be at least 10 characters"),
	role: z.enum(["ADMIN", "USER"]),
	address: z.string().optional(),
	bio: z.string().optional(),
	password: z.string().optional(),
});

type UserFormData = z.infer<typeof userFormSchema>;

const ITEMS_PER_PAGE = 10;

export function UserList() {
	const [users, setUsers] = useState<TUser[]>([]);
	const [searchTerm, setSearchTerm] = useState("");
	const [roleFilter, setRoleFilter] = useState<UserRole | "all">("all");
	const [currentPage, setCurrentPage] = useState(1);
	const [selectedUser, setSelectedUser] = useState<TUser | null>(null);
	const [userToDelete, setUserToDelete] = useState<TUser | null>(null);
	const [userToBlock, setUserToBlock] = useState<TUser | null>(null);
	const [isViewOpen, setIsViewOpen] = useState(false);
	const [isEditOpen, setIsEditOpen] = useState(false);
	const [isAddOpen, setIsAddOpen] = useState(false);
	const [sortField, setSortField] = useState<SortField>(null);
	const [sortDirection, setSortDirection] = useState<SortDirection>("asc");

	// Redux hooks - properly destructure the mutation functions
	const { data, isLoading } = useGetAllUsersQuery(users);
	const [createUser] = useCreateUserMutation();
	const [updateUser] = useUpdateUserMutation();
	const [deleteUser] = useDeleteUserMutation();
	const [blockUser] = useBlockUserMutation();

	// Initialize users from API
	useEffect(() => {
		if (data?.data) {
			setUsers(data.data);
		}
	}, [data]);

	// Handle sorting
	const handleSort = (field: SortField) => {
		if (sortField === field) {
			setSortDirection(sortDirection === "asc" ? "desc" : "asc");
		} else {
			setSortField(field);
			setSortDirection("asc");
		}
	};

	// Filter, sort, and search users
	const filteredUsers = useMemo(() => {
		const filtered = users.filter((user) => {
			const matchesSearch =
				searchTerm === "" ||
				user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
				user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
				user.phone.includes(searchTerm);

			const matchesRole = roleFilter === "all" || user.role === roleFilter;

			return matchesSearch && matchesRole;
		});

		if (sortField) {
			return [...filtered].sort((a, b) => {
				if (sortField === "joinDate") {
					const dateA = new Date(a.createdAt).getTime();
					const dateB = new Date(b.createdAt).getTime();
					return sortDirection === "asc" ? dateA - dateB : dateB - dateA;
				} else if (sortField === "status") {
					if (sortDirection === "asc") {
						return a.status === "ACTIVE" ? -1 : 1;
					} else {
						return a.status === "SUSPENDED" ? -1 : 1;
					}
				}
				return 0;
			});
		}

		return filtered;
	}, [users, searchTerm, roleFilter, sortField, sortDirection]);

	// Pagination
	const totalPages = Math.ceil(filteredUsers.length / ITEMS_PER_PAGE);
	const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
	const paginatedUsers = filteredUsers.slice(
		startIndex,
		startIndex + ITEMS_PER_PAGE
	);

	// Reset to first page when filters change
	useEffect(() => {
		setCurrentPage(1);
	}, [searchTerm, roleFilter]);

	const handleViewUser = (user: TUser) => {
		setSelectedUser(user);
		setIsViewOpen(true);
	};

	const handleEditUser = (user: TUser) => {
		setSelectedUser(user);
		setIsEditOpen(true);
	};

	const handleAddUser = () => {
		setSelectedUser(null);
		setIsAddOpen(true);
	};

	const handleDeleteUser = async (user: TUser) => {
		try {
			await deleteUser(user.id);
			setUserToDelete(null);
			toast.success(`User ${user.name} deleted successfully`);

			// Adjust current page if needed
			const newFilteredCount = filteredUsers.length - 1;
			const newTotalPages = Math.ceil(newFilteredCount / ITEMS_PER_PAGE);
			if (currentPage > newTotalPages && newTotalPages > 0) {
				setCurrentPage(newTotalPages);
			}
		} catch (error) {
			console.log(error);
			toast.error("Failed to delete user");
		}
	};

	const handleToggleBlockUser = async (user: TUser) => {
		try {
			const newStatus = user.status === "ACTIVE" ? "SUSPENDED" : "ACTIVE";
			await blockUser({
				id: user.id,
				data:
					user.status === "ACTIVE"
						? { status: "SUSPENDED" }
						: { status: "ACTIVE" },
			});

			setUserToBlock(null);
			toast.success(
				`User ${user.name} ${
					newStatus === "SUSPENDED" ? "blocked" : "unblocked"
				} successfully`
			);
		} catch (error) {
			console.log(error);
			toast.error("Failed to update user status");
		}
	};

	const formatDate = (dateString: Date) => {
		return format(new Date(dateString), "MMM d, yyyy");
	};

	const getStatusBadge = (status: UserStatus) => {
		return status === "ACTIVE" ? (
			<Badge className="bg-green-500 hover:bg-green-600 text-white">
				Active
			</Badge>
		) : (
			<Badge
				variant="outline"
				className="text-red-500 border-red-200 bg-red-50 dark:bg-red-950/20"
			>
				Blocked
			</Badge>
		);
	};

	const getRoleBadge = (role: UserRole) => {
		const roleColors: Record<UserRole, string> = {
			ADMIN: "bg-purple-500 hover:bg-purple-600 text-white",
			USER: "bg-emerald-500 hover:bg-emerald-600 text-white",
		};

		return <Badge className={roleColors[role]}>{role}</Badge>;
	};

	const clearFilters = () => {
		setSearchTerm("");
		setRoleFilter("all");
		setSortField(null);
	};

	if (isLoading) {
		return (
			<div className="space-y-4">
				<div className="flex items-center justify-between">
					<div className="space-y-1">
						<h2 className="text-2xl font-bold tracking-tight flex items-center gap-2">
							<Users /> User Management
						</h2>
						<p className="text-muted-foreground">Loading users...</p>
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
						<h2 className="text-2xl font-bold tracking-tight flex gap-2 items-center">
							<Users />
							User Management
						</h2>
						<p className="text-muted-foreground">
							Manage user accounts, roles, and permissions.
						</p>
					</div>
					<Button onClick={handleAddUser}>
						<UserPlus className="h-4 w-4 mr-2" />
						Add New User
					</Button>
				</div>

				{/* Filters and Search */}
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
						value={roleFilter}
						onValueChange={(value: UserRole | "all") => setRoleFilter(value)}
					>
						<SelectTrigger className="w-full sm:w-[180px]">
							<Filter className="h-4 w-4 mr-2" />
							<SelectValue placeholder="Filter by role" />
						</SelectTrigger>
						<SelectContent>
							<SelectItem value="all">All Roles</SelectItem>
							<SelectItem value="ADMIN">Admin</SelectItem>
							<SelectItem value="USER">User</SelectItem>
						</SelectContent>
					</Select>
					{(searchTerm || roleFilter !== "all" || sortField) && (
						<Button
							variant="ghost"
							onClick={clearFilters}
							className="sm:w-auto"
						>
							<X className="h-4 w-4 mr-2" />
							Clear Filters
						</Button>
					)}
				</div>

				{/* Results Summary */}
				<div className="text-sm text-muted-foreground">
					Showing {paginatedUsers.length} of {filteredUsers.length} users
				</div>

				{/* Users Table */}
				<div className="border rounded-md border-border">
					<Table>
						<TableHeader>
							<TableRow className="hover:bg-transparent">
								<TableHead className="w-16">#</TableHead>
								<TableHead>Name</TableHead>
								<TableHead>Contact</TableHead>
								<TableHead>Role</TableHead>
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
									onClick={() => handleSort("joinDate")}
								>
									<div className="flex items-center gap-1">
										Join Date
										{sortField === "joinDate" &&
											(sortDirection === "asc" ? (
												<ArrowUp className="h-3 w-3" />
											) : (
												<ArrowDown className="h-3 w-3" />
											))}
									</div>
								</TableHead>
								<TableHead className="w-[120px]">Actions</TableHead>
							</TableRow>
						</TableHeader>
						<TableBody>
							{paginatedUsers.length === 0 ? (
								<TableRow>
									<TableCell
										colSpan={7}
										className="text-center py-8 text-muted-foreground"
									>
										No users found matching your criteria.
									</TableCell>
								</TableRow>
							) : (
								paginatedUsers.map((user, index) => (
									<TableRow key={user.id}>
										<TableCell className="font-medium">
											{startIndex + index + 1}
										</TableCell>
										<TableCell>
											<div className="flex items-center gap-3">
												<Avatar>
													<AvatarImage
														src={user.photo || "/placeholder.svg"}
														alt={user.name}
													/>
													<AvatarFallback>
														{user.name.substring(0, 2).toUpperCase()}
													</AvatarFallback>
												</Avatar>
												<div>
													<p className="font-medium">{user.name}</p>
												</div>
											</div>
										</TableCell>
										<TableCell>
											<div className="space-y-1">
												<p className="text-sm font-medium">{user.email}</p>
												<p className="text-xs text-muted-foreground">
													{user.phone}
												</p>
											</div>
										</TableCell>
										<TableCell>{getRoleBadge(user.role)}</TableCell>
										<TableCell>{getStatusBadge(user.status)}</TableCell>
										<TableCell>{formatDate(user.createdAt)}</TableCell>
										<TableCell>
											<DropdownMenu>
												<DropdownMenuTrigger asChild>
													<Button
														variant="ghost"
														size="sm"
														className="h-8 w-8 p-0"
													>
														<span className="sr-only">Open menu</span>
														<ChevronDown className="h-4 w-4" />
													</Button>
												</DropdownMenuTrigger>
												<DropdownMenuContent align="end">
													<DropdownMenuItem
														onClick={() => handleViewUser(user)}
													>
														<Eye className="h-4 w-4 mr-2" />
														View Details
													</DropdownMenuItem>
													<DropdownMenuItem
														onClick={() => handleEditUser(user)}
													>
														<Edit className="h-4 w-4 mr-2" />
														Edit User
													</DropdownMenuItem>
													<DropdownMenuSeparator />
													<DropdownMenuItem
														onClick={() => setUserToBlock(user)}
														className={
															user.status === "ACTIVE"
																? "text-amber-600"
																: "text-green-600"
														}
													>
														{user.status === "ACTIVE" ? (
															<>
																<Ban className="h-4 w-4 mr-2" />
																Block User
															</>
														) : (
															<>
																<CheckCircle className="h-4 w-4 mr-2" />
																Unblock User
															</>
														)}
													</DropdownMenuItem>
													<DropdownMenuItem
														onClick={() => setUserToDelete(user)}
														className="text-destructive"
													>
														<Trash2 className="h-4 w-4 mr-2" />
														Delete User
													</DropdownMenuItem>
												</DropdownMenuContent>
											</DropdownMenu>
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

			{/* User Details Sheet */}
			<UserDetailsSheet
				user={selectedUser}
				open={isViewOpen}
				onOpenChange={setIsViewOpen}
			/>

			{/* User Form Sheet */}
			<UserFormSheet
				user={selectedUser}
				open={isEditOpen || isAddOpen}
				onOpenChange={(open) => {
					if (isEditOpen) setIsEditOpen(open);
					if (isAddOpen) setIsAddOpen(open);
				}}
				onSave={async (userData) => {
					try {
						if (selectedUser) {
							// Update existing user
							await updateUser({ id: selectedUser.id, data: { ...userData } });

							toast.success(`User ${userData.name} updated successfully`);
						} else {
							// Create new user
							await createUser(userData);
							const newUser = {
								...userData,
								status: "ACTIVE" as UserStatus,
							} as TUser;
							setUsers((prev) => [...prev, newUser]);
							toast.success(`User ${userData.name} created successfully`);
						}
						setIsEditOpen(false);
						setIsAddOpen(false);
					} catch (error) {
						console.log(error);
						toast.error("Failed to save user");
					}
				}}
			/>

			{/* Delete Confirmation Dialog */}
			<AlertDialog
				open={!!userToDelete}
				onOpenChange={() => setUserToDelete(null)}
			>
				<AlertDialogContent>
					<AlertDialogHeader>
						<AlertDialogTitle>Delete User</AlertDialogTitle>
						<AlertDialogDescription>
							Are you sure you want to delete{" "}
							<strong>{userToDelete?.name}</strong>? This action cannot be
							undone and will permanently remove the user account and all
							associated data.
						</AlertDialogDescription>
					</AlertDialogHeader>
					<AlertDialogFooter>
						<AlertDialogCancel>Cancel</AlertDialogCancel>
						<AlertDialogAction
							onClick={() => userToDelete && handleDeleteUser(userToDelete)}
							className="bg-destructive hover:bg-destructive/90"
						>
							Delete User
						</AlertDialogAction>
					</AlertDialogFooter>
				</AlertDialogContent>
			</AlertDialog>

			{/* Block/Unblock Confirmation Dialog */}
			<AlertDialog
				open={!!userToBlock}
				onOpenChange={() => setUserToBlock(null)}
			>
				<AlertDialogContent>
					<AlertDialogHeader>
						<AlertDialogTitle>
							{userToBlock?.status === "ACTIVE" ? "Block User" : "Unblock User"}
						</AlertDialogTitle>
						<AlertDialogDescription>
							{userToBlock?.status === "ACTIVE" ? (
								<>
									Are you sure you want to block{" "}
									<strong>{userToBlock?.name}</strong>? This will prevent the
									user from accessing the system until they are unblocked.
								</>
							) : (
								<>
									Are you sure you want to unblock{" "}
									<strong>{userToBlock?.name}</strong>? This will restore the
									user&apos;s access to the system.
								</>
							)}
						</AlertDialogDescription>
					</AlertDialogHeader>
					<AlertDialogFooter>
						<AlertDialogCancel>Cancel</AlertDialogCancel>
						<AlertDialogAction
							onClick={() => userToBlock && handleToggleBlockUser(userToBlock)}
							className={
								userToBlock?.status === "ACTIVE"
									? "bg-amber-600 hover:bg-amber-700"
									: "bg-green-600 hover:bg-green-700"
							}
						>
							{userToBlock?.status === "ACTIVE" ? "Block User" : "Unblock User"}
						</AlertDialogAction>
					</AlertDialogFooter>
				</AlertDialogContent>
			</AlertDialog>
		</>
	);
}

// User Details Sheet Component
function UserDetailsSheet({
	user,
	open,
	onOpenChange,
}: {
	user: TUser | null;
	open: boolean;
	onOpenChange: (open: boolean) => void;
}) {
	if (!user) return null;

	const formatDate = (dateString: Date) => {
		return format(new Date(dateString), "MMMM d, yyyy 'at' h:mm a");
	};

	const getStatusBadge = (status: UserStatus) => {
		return status === "ACTIVE" ? (
			<Badge className="bg-green-500 hover:bg-green-600 text-white">
				Active
			</Badge>
		) : (
			<Badge
				variant="outline"
				className="text-red-500 border-red-200 bg-red-50 dark:bg-red-950/20"
			>
				Blocked
			</Badge>
		);
	};

	const getRoleBadge = (role: UserRole) => {
		const roleColors: Record<UserRole, string> = {
			ADMIN: "bg-purple-500 hover:bg-purple-600 text-white",
			USER: "bg-emerald-500 hover:bg-emerald-600 text-white",
		};

		return <Badge className={roleColors[role]}>{role}</Badge>;
	};

	return (
		<Sheet open={open} onOpenChange={onOpenChange}>
			<SheetContent className="w-full sm:max-w-lg p-4 md:p-6">
				<SheetHeader>
					<SheetTitle>User Details</SheetTitle>
				</SheetHeader>
				<ScrollArea className="h-full pr-4">
					<div className="space-y-6 py-6 px-2">
						{/* User Header */}
						<div className="flex items-center gap-4">
							<Avatar className="h-16 w-16">
								<AvatarImage
									src={user.photo || "/placeholder.svg"}
									alt={user.name}
								/>
								<AvatarFallback>
									{user.name.substring(0, 2).toUpperCase()}
								</AvatarFallback>
							</Avatar>
							<div>
								<h3 className="font-semibold text-lg">{user.name}</h3>
								<div className="flex items-center gap-2 mt-1">
									{getStatusBadge(user.status)}
									{getRoleBadge(user.role)}
								</div>
							</div>
						</div>

						<Separator />

						{/* Contact Information */}
						<div className="space-y-4">
							<h4 className="font-medium">Contact Information</h4>
							<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Email</p>
									<p className="font-medium">{user.email}</p>
								</div>
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Phone</p>
									<p className="font-medium">{user.phone}</p>
								</div>
								{user.address && (
									<div className="space-y-1 col-span-2">
										<p className="text-sm text-muted-foreground">Address</p>
										<p className="font-medium">{user.address}</p>
									</div>
								)}
							</div>
						</div>

						<Separator />

						{/* Account Information */}
						<div className="space-y-4">
							<h4 className="font-medium">Account Information</h4>
							<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">User ID</p>
									<p className="font-mono text-sm">{user.id}</p>
								</div>
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Role</p>
									<p className="font-medium">{user.role}</p>
								</div>
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Status</p>
									<p className="font-medium capitalize">{user.status}</p>
								</div>
								<div className="space-y-1">
									<p className="text-sm text-muted-foreground">Join Date</p>
									<p className="font-medium">{formatDate(user.createdAt)}</p>
								</div>
							</div>
						</div>

						{user.bio && (
							<>
								<Separator />
								<div className="space-y-4">
									<h4 className="font-medium">Bio</h4>
									<p className="text-sm">{user.bio}</p>
								</div>
							</>
						)}
					</div>
				</ScrollArea>
			</SheetContent>
		</Sheet>
	);
}

// User Form Sheet Component with shadcn Form
function UserFormSheet({
	user,
	open,
	onOpenChange,
	onSave,
}: {
	user: TUser | null;
	open: boolean;
	onOpenChange: (open: boolean) => void;
	onSave: (userData: UserFormData) => Promise<void>;
}) {
	const form = useForm<UserFormData>({
		resolver: zodResolver(userFormSchema),
		defaultValues: {
			name: "",
			email: "",
			phone: "",
			role: "USER",
			address: "",
			bio: "",
			password: "",
		},
	});

	// Initialize form with user data when editing
	useEffect(() => {
		if (user && open) {
			form.reset({
				name: user.name,
				email: user.email,
				phone: user.phone,
				role: user.role,
				address: user.address || "",
				bio: user.bio || "",
				password: "",
			});
		} else if (!user && open) {
			// Reset form for new user
			form.reset({
				name: "",
				email: "",
				phone: "",
				role: "USER",
				address: "",
				bio: "",
				password: "",
			});
		}
	}, [user, open, form]);

	const onSubmit = async (data: UserFormData) => {
		try {
			await onSave(data);
			form.reset();
		} catch (error) {
			console.error("Error saving user:", error);
		}
	};

	return (
		<Sheet open={open} onOpenChange={onOpenChange}>
			<SheetContent className="w-full sm:max-w-lg p-4 md:p-6 pb-6">
				<SheetHeader className="p-0">
					<SheetTitle>{user ? "Edit User" : "Add New User"}</SheetTitle>
				</SheetHeader>
				<ScrollArea className="h-full pr-4">
					<Form {...form}>
						<form
							onSubmit={form.handleSubmit(onSubmit)}
							className="space-y-6 py-6 px-2"
						>
							{/* Basic Information */}
							<div className="space-y-4">
								<div className="grid gap-4">
									<FormField
										control={form.control}
										name="name"
										render={({ field }) => (
											<FormItem>
												<FormLabel>Full Name</FormLabel>
												<FormControl>
													<Input placeholder="Enter full name" {...field} />
												</FormControl>
												<FormMessage />
											</FormItem>
										)}
									/>

									<FormField
										control={form.control}
										name="email"
										render={({ field }) => (
											<FormItem>
												<FormLabel>Email Address</FormLabel>
												<FormControl>
													<Input
														type="email"
														placeholder="Enter email address"
														{...field}
													/>
												</FormControl>
												<FormMessage />
											</FormItem>
										)}
									/>

									<FormField
										control={form.control}
										name="phone"
										render={({ field }) => (
											<FormItem>
												<FormLabel>Phone Number</FormLabel>
												<FormControl>
													<Input placeholder="Enter phone number" {...field} />
												</FormControl>
												<FormMessage />
											</FormItem>
										)}
									/>
									<FormField
										control={form.control}
										name="role"
										render={({ field }) => (
											<FormItem>
												<FormLabel>User Role</FormLabel>
												<Select
													onValueChange={field.onChange}
													defaultValue={field.value}
												>
													<FormControl>
														<SelectTrigger className="w-full">
															<SelectValue placeholder="Select role" />
														</SelectTrigger>
													</FormControl>
													<SelectContent>
														<SelectItem value="ADMIN">Admin</SelectItem>
														<SelectItem value="USER">User</SelectItem>
													</SelectContent>
												</Select>

												<FormMessage />
											</FormItem>
										)}
									/>

									<FormField
										control={form.control}
										name="password"
										render={({ field }) => (
											<FormItem>
												<FormLabel>Password</FormLabel>
												<FormControl>
													<Input
														type="password"
														placeholder="Enter password"
														{...field}
													/>
												</FormControl>
												<FormDescription>
													Password must be at least 6 characters long.
												</FormDescription>
												<FormMessage />
											</FormItem>
										)}
									/>
									<FormField
										control={form.control}
										name="address"
										render={({ field }) => (
											<FormItem>
												<FormLabel>Address (Optional)</FormLabel>
												<FormControl>
													<Input placeholder="Enter address" {...field} />
												</FormControl>
												<FormMessage />
											</FormItem>
										)}
									/>

									<FormField
										control={form.control}
										name="bio"
										render={({ field }) => (
											<FormItem>
												<FormLabel>Bio (Optional)</FormLabel>
												<FormControl>
													<Textarea
														placeholder="Enter user bio or description"
														className="min-h-[50px]"
														{...field}
													/>
												</FormControl>
												<FormMessage />
											</FormItem>
										)}
									/>
								</div>
							</div>

							<div className="flex justify-end gap-2 pt-4">
								<Button
									type="button"
									variant="outline"
									onClick={() => onOpenChange(false)}
								>
									Cancel
								</Button>
								<Button type="submit" disabled={form.formState.isSubmitting}>
									{form.formState.isSubmitting
										? "Saving..."
										: user
										? "Update User"
										: "Create User"}
								</Button>
							</div>
						</form>
					</Form>
				</ScrollArea>
			</SheetContent>
		</Sheet>
	);
}
