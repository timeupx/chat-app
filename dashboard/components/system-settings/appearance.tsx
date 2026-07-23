"use client";

import type React from "react";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Upload, ImageIcon, Palette, Monitor, Sun, Moon } from "lucide-react";

import { Button } from "@/components/ui/button";
import { CardContent } from "@/components/ui/card";
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
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Label } from "@/components/ui/label";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { toast } from "sonner";

const formSchema = z.object({
	logo: z.string().optional(),
	favicon: z.string().optional(),
	theme: z.enum(["light", "dark", "system"], {
		required_error: "Please select a theme preference.",
	}),
});

type FormData = z.infer<typeof formSchema>;

export default function AppearanceSettingsForm() {
	const [logoPreview, setLogoPreview] = useState<string>(
		"/placeholder_logo.png"
	);
	const [faviconPreview, setFaviconPreview] = useState<string>(
		"/placeholder.svg?height=32&width=32"
	);
	const [isSubmitting, setIsSubmitting] = useState(false);

	const form = useForm<FormData>({
		resolver: zodResolver(formSchema),
		defaultValues: {
			logo: "",
			favicon: "",
			theme: "system",
		},
	});

	const handleLogoUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
		const file = event.target.files?.[0];
		if (file) {
			// Validate file type
			if (!file.type.startsWith("image/")) {
				toast.error("Please select a valid image file");
				return;
			}

			// Validate file size (max 5MB)
			if (file.size > 5 * 1024 * 1024) {
				toast.error("File size must be less than 5MB");
				return;
			}

			const reader = new FileReader();
			reader.onload = (e) => {
				const result = e.target?.result as string;
				setLogoPreview(result);
				form.setValue("logo", result);
			};
			reader.readAsDataURL(file);
		}
	};

	const handleFaviconUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
		const file = event.target.files?.[0];
		if (file) {
			// Validate file type
			if (!file.type.startsWith("image/")) {
				toast.error("Please select a valid image file");
				return;
			}

			// Validate file size (max 1MB for favicon)
			if (file.size > 1 * 1024 * 1024) {
				toast.error("Favicon file size must be less than 1MB");
				return;
			}

			const reader = new FileReader();
			reader.onload = (e) => {
				const result = e.target?.result as string;
				setFaviconPreview(result);
				form.setValue("favicon", result);
			};
			reader.readAsDataURL(file);
		}
	};

	const onSubmit = async (data: FormData) => {
		setIsSubmitting(true);

		// Simulate API call
		await new Promise((resolve) => setTimeout(resolve, 2000));

		// Console log the form data
		console.log("Site Settings Form Data:", {
			logo: data.logo ? "Logo file uploaded" : "No logo uploaded",
			favicon: data.favicon ? "Favicon file uploaded" : "No favicon uploaded",
			theme: data.theme,
			logoSize: data.logo
				? `${Math.round(data.logo.length * 0.75)} bytes`
				: "N/A",
			faviconSize: data.favicon
				? `${Math.round(data.favicon.length * 0.75)} bytes`
				: "N/A",
			timestamp: new Date().toISOString(),
		});

		setIsSubmitting(false);
		toast.success("Site settings saved successfully!");
	};

	return (
		<div className="max-w-2xl py-4">
			<>
				<CardContent className="p-0">
					<Form {...form}>
						<form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
							{/* Logo Upload Section */}
							<div className="space-y-4">
								<div className="flex items-center gap-2">
									<ImageIcon className="h-5 w-5" />
									<h3 className="text-lg font-medium">Brand Assets</h3>
								</div>

								<FormField
									control={form.control}
									name="logo"
									// eslint-disable-next-line @typescript-eslint/no-unused-vars
									render={({ field }) => (
										<FormItem>
											<FormLabel>Logo</FormLabel>
											<FormControl>
												<div className="space-y-4">
													{/* Logo Preview */}
													<div className="flex items-center space-x-4">
														<div className="border-2 border-dashed border-muted-foreground/25 rounded-lg p-2 bg-muted/50">
															<img
																src={logoPreview || "/placeholder_logo.png"}
																alt="Logo preview"
																className="max-h-16 max-w-48 object-contain"
															/>
														</div>
														<div className="flex-1">
															<Input
																type="file"
																accept="image/*"
																onChange={handleLogoUpload}
																className="hidden"
																id="logo-upload"
															/>
															<Button
																type="button"
																variant="outline"
																onClick={() =>
																	document
																		.getElementById("logo-upload")
																		?.click()
																}
																className="w-full"
															>
																<Upload className="h-4 w-4 mr-2" />
																Upload Logo
															</Button>
														</div>
													</div>
												</div>
											</FormControl>
											<FormDescription>
												Upload your site logo. Recommended size: 200x80px. Max
												file size: 5MB.
											</FormDescription>
											<FormMessage />
										</FormItem>
									)}
								/>

								<FormField
									control={form.control}
									name="favicon"
									// eslint-disable-next-line @typescript-eslint/no-unused-vars
									render={({ field }) => (
										<FormItem>
											<FormLabel>Favicon</FormLabel>
											<FormControl>
												<div className="space-y-4">
													{/* Favicon Preview */}
													<div className="flex items-center space-x-4">
														<div className="border-2 border-dashed border-muted-foreground/25 rounded-lg p-2 bg-muted/50">
															<Avatar className="h-8 w-8">
																<AvatarImage
																	src={faviconPreview || "/placeholder.svg"}
																	alt="Favicon preview"
																/>
																<AvatarFallback>
																	<ImageIcon className="h-4 w-4" />
																</AvatarFallback>
															</Avatar>
														</div>
														<div className="flex-1">
															<Input
																type="file"
																accept="image/*"
																onChange={handleFaviconUpload}
																className="hidden"
																id="favicon-upload"
															/>
															<Button
																type="button"
																variant="outline"
																onClick={() =>
																	document
																		.getElementById("favicon-upload")
																		?.click()
																}
																className="w-full"
															>
																<Upload className="h-4 w-4 mr-2" />
																Upload Favicon
															</Button>
														</div>
													</div>
												</div>
											</FormControl>
											<FormDescription>
												Upload your site favicon. Recommended size: 32x32px or
												16x16px. Max file size: 1MB.
											</FormDescription>
											<FormMessage />
										</FormItem>
									)}
								/>
							</div>

							{/* Theme Selection Section */}
							<div className="space-y-4">
								<div className="flex items-center gap-2">
									<Palette className="h-5 w-5" />
									<h3 className="text-lg font-medium">Appearance</h3>
								</div>

								<FormField
									control={form.control}
									name="theme"
									render={({ field }) => (
										<FormItem className="space-y-3">
											<FormLabel>Theme Preference</FormLabel>
											<FormControl>
												<RadioGroup
													onValueChange={field.onChange}
													defaultValue={field.value}
													className="grid grid-cols-1 md:grid-cols-3 gap-4"
												>
													<div className="flex items-center space-x-2">
														<RadioGroupItem value="light" id="light" />
														<Label
															htmlFor="light"
															className="flex items-center gap-2 cursor-pointer flex-1 p-3 border rounded-lg hover:bg-muted/50"
														>
															<Sun className="h-4 w-4" />
															<div>
																<div className="font-medium">Light</div>
																<div className="text-sm text-muted-foreground">
																	Always use light theme
																</div>
															</div>
														</Label>
													</div>

													<div className="flex items-center space-x-2">
														<RadioGroupItem value="dark" id="dark" />
														<Label
															htmlFor="dark"
															className="flex items-center gap-2 cursor-pointer flex-1 p-3 border rounded-lg hover:bg-muted/50"
														>
															<Moon className="h-4 w-4" />
															<div>
																<div className="font-medium">Dark</div>
																<div className="text-sm text-muted-foreground">
																	Always use dark theme
																</div>
															</div>
														</Label>
													</div>

													<div className="flex items-center space-x-2">
														<RadioGroupItem value="system" id="system" />
														<Label
															htmlFor="system"
															className="flex items-center gap-2 cursor-pointer flex-1 p-3 border rounded-lg hover:bg-muted/50"
														>
															<Monitor className="h-4 w-4" />
															<div>
																<div className="font-medium">System</div>
																<div className="text-sm text-muted-foreground">
																	Follow system preference
																</div>
															</div>
														</Label>
													</div>
												</RadioGroup>
											</FormControl>
											<FormDescription>
												Choose how you want the site theme to be displayed.
											</FormDescription>
											<FormMessage />
										</FormItem>
									)}
								/>
							</div>

							<Button
								type="submit"
								disabled={isSubmitting}
								className="w-full"
								size="lg"
							>
								{isSubmitting ? "Saving Settings..." : "Save Settings"}
							</Button>
						</form>
					</Form>
				</CardContent>
			</>
		</div>
	);
}
