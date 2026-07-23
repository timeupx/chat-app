"use client";
import { toast } from "sonner";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
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
import { Switch } from "@/components/ui/switch";
import {
	SystemSettings,
	useGetSettingsQuery,
	useUpdateSettingsMutation,
} from "@/redux/feature/system-settings/systemApi";
import { useEffect, useState } from "react";

const formSchema = z.object({
	metaTitle: z.string().min(1).optional(),
	metaDescription: z.string().optional(),
	allowSignup: z.boolean().optional(),
	maintenanceMode: z.boolean().optional(),
});

export default function GeneralSettings() {
	const [settings, setSettings] = useState<SystemSettings>();
	const { data } = useGetSettingsQuery(settings);
	const [updateSettings, { isLoading }] = useUpdateSettingsMutation();

	const form = useForm<z.infer<typeof formSchema>>({
		resolver: zodResolver(formSchema),
	});

	useEffect(() => {
		if (data) {
			setSettings(data.data);
			form.reset({
				metaTitle: settings?.metaTitle,
				metaDescription: settings?.metaDescription,
				allowSignup: settings?.allowSignup,
				maintenanceMode: settings?.maintenanceMode,
			});
		}
	}, [data]);

	async function onSubmit(values: z.infer<typeof formSchema>) {
		try {
			const update = await updateSettings(values).unwrap();
			toast.success(update.message || "Settings updated");
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
		} catch (error: any) {
			console.error("Form submission error", error);
			toast.error(
				error.data.message || "Failed to submit the form. Please try again."
			);
		}
	}

	return (
		<Form {...form}>
			<form
				onSubmit={form.handleSubmit(onSubmit)}
				className="space-y-6 max-w-3xl py-4"
			>
				<FormField
					control={form.control}
					name="metaTitle"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Meta Title</FormLabel>
							<FormControl>
								<Input
									placeholder="Website title"
									type=""
									{...field}
									className="h-11"
								/>
							</FormControl>

							<FormMessage />
						</FormItem>
					)}
				/>

				<FormField
					control={form.control}
					name="metaDescription"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Meta Description</FormLabel>
							<FormControl>
								<Textarea
									placeholder="Website Description"
									className="resize-none"
									{...field}
								/>
							</FormControl>

							<FormMessage />
						</FormItem>
					)}
				/>

				<FormField
					control={form.control}
					name="allowSignup"
					render={({ field }) => (
						<FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
							<div className="space-y-0.5">
								<FormLabel>Create account</FormLabel>
								<FormDescription>
									Allow new user to create an account
								</FormDescription>
							</div>
							<FormControl>
								<Switch
									checked={field.value}
									onCheckedChange={field.onChange}
									aria-readonly
								/>
							</FormControl>
						</FormItem>
					)}
				/>

				<FormField
					control={form.control}
					name="maintenanceMode"
					render={({ field }) => (
						<FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
							<div className="space-y-0.5">
								<FormLabel>Maintenance</FormLabel>
								<FormDescription>
									Enable or disable maintenance mode
								</FormDescription>
							</div>
							<FormControl>
								<Switch
									checked={field.value}
									onCheckedChange={field.onChange}
									aria-readonly
								/>
							</FormControl>
						</FormItem>
					)}
				/>
				<Button type="submit" className="w-full">
					{isLoading ? "Updating..." : "Update"}
				</Button>
			</form>
		</Form>
	);
}
