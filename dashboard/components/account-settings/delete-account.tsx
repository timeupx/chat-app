"use client";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Trash2, AlertTriangle, Eye, EyeOff } from "lucide-react";

import { Button } from "@/components/ui/button";
import { CardContent } from "@/components/ui/card";
import {
	Form,
	FormControl,
	FormField,
	FormItem,
	FormLabel,
	FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Alert, AlertDescription } from "@/components/ui/alert";
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
import { toast } from "sonner";
import { useDeleteProfileMutation } from "@/redux/feature/user/userApi";
import { useAppDispatch } from "@/redux/feature/hooks";
import { logOut } from "@/redux/feature/auth/authSlice";

const deleteSchema = z.object({
	password: z.string().min(1, "Password is required to delete your account"),
});

type DeleteFormData = z.infer<typeof deleteSchema>;

export function DeleteAccount() {
	const [showDeleteDialog, setShowDeleteDialog] = useState(false);
	const [showPassword, setShowPassword] = useState(false);

	const [deleteProfile, { isLoading }] = useDeleteProfileMutation();
	const dispatch = useAppDispatch();

	const form = useForm<DeleteFormData>({
		resolver: zodResolver(deleteSchema),
		defaultValues: {
			password: "",
		},
	});

	const onSubmit = async (data: DeleteFormData) => {
		try {
			await deleteProfile(data).unwrap();
			toast.success("Account deleted successfully");
			setShowDeleteDialog(false);
			form.reset();
			dispatch(logOut());
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
		} catch (error: any) {
			console.log("Failed deleting account", error);
			toast.error(error?.data?.message || "Failed deleting account");
		}
	};

	const handleDeleteClick = () => {
		setShowDeleteDialog(true);
		form.reset();
	};

	return (
		<>
			<div className="border-red-200 w-full max-w-xl border-0 shadow-none">
				<CardContent className="space-y-4 px-2">
					<Alert className="border-red-200 bg-red-50">
						<AlertTriangle className="h-4 w-4 text-red-600" />
						<AlertDescription className="text-red-800">
							<strong>Warning:</strong> Account deletion is permanent and
							irreversible. All your data will be lost forever.
						</AlertDescription>
					</Alert>

					<Button
						variant="destructive"
						onClick={handleDeleteClick}
						className="w-full"
						size="lg"
					>
						<Trash2 className="h-4 w-4 mr-2" />
						Delete My Account
					</Button>
				</CardContent>
			</div>

			{/* Delete Confirmation Dialog */}
			<AlertDialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
				<AlertDialogContent>
					<AlertDialogHeader>
						<AlertDialogTitle className="flex items-center gap-2 text-red-600">
							<AlertTriangle className="h-5 w-5" />
							Confirm Account Deletion
						</AlertDialogTitle>
						<AlertDialogDescription>
							Enter your password to permanently delete your account. This
							action cannot be undone.
						</AlertDialogDescription>
					</AlertDialogHeader>

					<Form {...form}>
						<form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
							<FormField
								control={form.control}
								name="password"
								render={({ field }) => (
									<FormItem>
										<FormLabel>Current Password</FormLabel>
										<FormControl>
											<div className="relative">
												<Input
													type={showPassword ? "text" : "password"}
													placeholder="Enter your password"
													{...field}
												/>
												<Button
													type="button"
													variant="ghost"
													size="sm"
													className="absolute right-0 top-0 h-full px-3 py-2 hover:bg-transparent"
													onClick={() => setShowPassword(!showPassword)}
												>
													{showPassword ? (
														<EyeOff className="h-4 w-4" />
													) : (
														<Eye className="h-4 w-4" />
													)}
												</Button>
											</div>
										</FormControl>
										<FormMessage />
									</FormItem>
								)}
							/>
						</form>
					</Form>

					<AlertDialogFooter>
						<AlertDialogCancel onClick={() => form.reset()}>
							Cancel
						</AlertDialogCancel>
						<AlertDialogAction
							onClick={form.handleSubmit(onSubmit)}
							disabled={isLoading || !form.formState.isValid}
							className="bg-red-600 hover:bg-red-700"
						>
							{isLoading ? "Deleting..." : "Delete Account"}
						</AlertDialogAction>
					</AlertDialogFooter>
				</AlertDialogContent>
			</AlertDialog>
		</>
	);
}
