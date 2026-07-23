"use client";

import type React from "react";

import { useEffect, useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Edit2, Upload, User, Phone, X, LoaderCircle } from "lucide-react";

import { Button } from "@/components/ui/button";

import {
	Form,
	FormControl,
	FormDescription,
	FormField,
	FormItem,
	FormLabel,
	FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
	Dialog,
	DialogContent,
	DialogDescription,
	DialogFooter,
	DialogHeader,
	DialogTitle,
} from "@/components/ui/dialog";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { toast } from "sonner";
import { TUser } from "@/redux/feature/auth/authSlice";
import {
	useProfileQuery,
	useUpdateProfileMutation,
} from "@/redux/feature/user/userApi";

const formSchema = z.object({
	name: z.string().min(2, {
		message: "Name must be at least 2 characters.",
	}),
	address: z.string().min(5, {
		message: "Address must be at least 5 characters.",
	}),
	bio: z.string().max(500, {
		message: "Bio must not exceed 500 characters.",
	}),
	photo: z.string().optional(),
});

type FormData = z.infer<typeof formSchema>;

export default function UpdateProfileForm() {
	const [photoPreview, setPhotoPreview] = useState<string>(
		"/placeholder.svg?height=100&width=100"
	);
	const [isOtpDialogOpen, setIsOtpDialogOpen] = useState(false);
	const [user, setUser] = useState<TUser>();

	const { data, isLoading } = useProfileQuery(user);
	const [updateProfile, { isLoading: isUpdating }] = useUpdateProfileMutation();

	const form = useForm<FormData>({
		resolver: zodResolver(formSchema),
		defaultValues: {
			name: "",
			address: "",
			bio: "",
			photo: "",
		},
	});

	useEffect(() => {
		if (data) {
			setUser(data.data);
			form.reset({
				name: user?.name || "",
				address: user?.address || "",
				bio: user?.bio || "",
				photo: user?.photo || "",
			});
		}
	}, [data]);

	console.log("dd", data);
	if (isLoading) {
		return (
			<div className="py-10 flex flex-col items-center justify-center">
				<LoaderCircle size={16} className="mr-3 size-5 animate-spin" />
				Please wait…
			</div>
		);
	}
	const handlePhotoUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
		const file = event.target.files?.[0];
		if (file) {
			const reader = new FileReader();
			reader.onload = (e) => {
				const result = e.target?.result as string;
				setPhotoPreview(result);
				form.setValue("photo", result);
			};
			reader.readAsDataURL(file);
		}
	};

	const onSubmit = async (data: FormData) => {
		try {
			console.log("data", data);
			await updateProfile(data).unwrap();
			toast.success("Profile updated successfully!");
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
		} catch (error: any) {
			console.error("Update profile failed:", error);
			toast.error(error?.data?.message || "Failed to update profile");
		}
	};

	return (
		<div className="max-w-2xl pt-4">
			{/* <Card>
				<CardContent> */}
			<Form {...form}>
				<form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
					{/* Photo Upload */}
					<div className="space-y-4">
						<div className="flex items-center space-x-4">
							<Avatar className="h-20 w-20">
								<AvatarImage
									src={user?.photo || photoPreview || "/placeholder.svg"}
									alt="Profile photo"
								/>
								<AvatarFallback>
									<User className="h-8 w-8" />
								</AvatarFallback>
							</Avatar>
							<div>
								<Input
									type="file"
									accept="image/*"
									onChange={handlePhotoUpload}
									className="hidden"
									id="photo-upload"
								/>
								<Button
									type="button"
									variant="outline"
									onClick={() =>
										document.getElementById("photo-upload")?.click()
									}
								>
									<Upload className="h-4 w-4 mr-2" />
									Upload Photo
								</Button>
							</div>
						</div>
					</div>

					{/* Name Field */}
					<FormField
						control={form.control}
						name="name"
						render={({ field }) => (
							<FormItem>
								<FormLabel>Full Name</FormLabel>
								<FormControl>
									<Input placeholder="Enter your full name" {...field} />
								</FormControl>
								<FormMessage />
							</FormItem>
						)}
					/>

					{/* Address Field */}
					<FormField
						control={form.control}
						name="address"
						render={({ field }) => (
							<FormItem>
								<FormLabel>Address</FormLabel>
								<FormControl>
									<Input placeholder="Enter your address" {...field} />
								</FormControl>
								<FormMessage />
							</FormItem>
						)}
					/>

					{/* Bio Field */}
					<FormField
						control={form.control}
						name="bio"
						render={({ field }) => (
							<FormItem>
								<FormLabel>Bio</FormLabel>
								<FormControl>
									<Textarea
										placeholder="Tell us about yourself..."
										className="min-h-[60px]"
										{...field}
									/>
								</FormControl>
								<FormDescription>
									{field.value?.length || 0}/500 characters
								</FormDescription>
								<FormMessage />
							</FormItem>
						)}
					/>

					{/* Phone Number Field (Disabled with Edit Button) */}
					<div className="space-y-2">
						<FormLabel>Phone Number</FormLabel>
						<div className="flex items-center space-x-2">
							<div className="relative flex-1">
								<Input value={user?.phone} disabled className="pr-10" />
								<Phone className="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
							</div>
							<Button
								type="button"
								variant="outline"
								size="sm"
								onClick={() => "pending"}
							>
								<Edit2 className="h-4 w-4" />
							</Button>
						</div>
						<FormDescription>
							Click the edit button to update your phone number. OTP
							verification required.
						</FormDescription>
					</div>

					<Button type="submit" className="w-full">
						{isUpdating ? "Updating profile" : "Update Profile"}
					</Button>
				</form>
			</Form>
			{/* </CardContent>
			</Card> */}

			{/* OTP Verification Dialog */}
			<Dialog open={isOtpDialogOpen} onOpenChange={setIsOtpDialogOpen}>
				<DialogContent className="sm:max-w-md">
					<DialogHeader>
						<DialogTitle>Update Phone Number | Verify OTP</DialogTitle>
						<DialogDescription>
							Enter your new phone number to receive an OTP : Enter the 6-digit
							code sent to your phone.
						</DialogDescription>
					</DialogHeader>

					<DialogFooter className="flex-col sm:flex-row gap-2">
						<>
							<Button
								variant="outline"
								onClick={() => setIsOtpDialogOpen(false)}
							>
								<X className="h-4 w-4 mr-2" />
								Cancel
							</Button>
							<Button>Send OTP</Button>
						</>
					</DialogFooter>
				</DialogContent>
			</Dialog>
		</div>
	);
}
