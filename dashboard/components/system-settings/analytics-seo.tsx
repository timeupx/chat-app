"use client";
import { toast } from "sonner";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import {
	Form,
	FormControl,
	FormField,
	FormItem,
	FormLabel,
	FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { useEffect, useState } from "react";
import {
	SystemSettings,
	useGetSettingsQuery,
	useUpdateSettingsMutation,
} from "@/redux/feature/system-settings/systemApi";

const formSchema = z.object({
	gatId: z.string().min(1).optional(),
	gtmId: z.string().min(1).optional(),
	pixelId: z.string().min(1).optional(),
});

export default function AnalyticsSeoForm() {
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
				gatId: settings?.analyticsSeo?.gatId,
				gtmId: settings?.analyticsSeo?.gtmId,
				pixelId: settings?.analyticsSeo?.pixelId,
			});
		}
	}, [data]);

	async function onSubmit(values: z.infer<typeof formSchema>) {
		try {
			const data = { analyticsSeo: values };
			const update = await updateSettings(data).unwrap();

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
					name="gatId"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Google Analytics Tracking ID</FormLabel>
							<FormControl>
								<Input
									placeholder="Google analytics tracking ID"
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
					name="gtmId"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Google Tag Manager ID</FormLabel>
							<FormControl>
								<Input
									placeholder="Google tag manager id"
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
					name="pixelId"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Facebook Pixel ID</FormLabel>
							<FormControl>
								<Input
									placeholder="Facebook pixel ID"
									type=""
									{...field}
									className="h-11"
								/>
							</FormControl>

							<FormMessage />
						</FormItem>
					)}
				/>
				<Button type="submit" className="w-full">
					{isLoading ? "Updating..." : "Update Settings"}
				</Button>
			</form>
		</Form>
	);
}
