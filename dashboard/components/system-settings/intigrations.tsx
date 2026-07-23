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
import { useEffect, useState } from "react";
import {
	SystemSettings,
	useGetSettingsQuery,
	useUpdateSettingsMutation,
} from "@/redux/feature/system-settings/systemApi";

const formSchema = z.object({
	smsApiKey: z.string().min(1).optional(),
	emailApiKey: z.string().min(1).optional(),
});

export default function IntigrationsForm() {
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
				smsApiKey: settings?.intigration?.smsApiKey,
				emailApiKey: settings?.intigration?.emailApiKey,
			});
		}
	}, [data]);

	async function onSubmit(values: z.infer<typeof formSchema>) {
		try {
			const data = { intigration: values };
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
					name="smsApiKey"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Bulk SMS Api Key</FormLabel>
							<FormControl>
								<Input
									placeholder="Bulk sms api key"
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
					name="emailApiKey"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Brevo Email Service Api</FormLabel>
							<FormControl>
								<Input
									placeholder="shadcn"
									type=""
									{...field}
									className="h-11"
								/>
							</FormControl>
							<FormDescription>Brevo email service api key</FormDescription>
							<FormMessage />
						</FormItem>
					)}
				/>
				<Button type="submit" className="w-full h-11">
					{isLoading ? "Updating..." : "Update Settings"}
				</Button>
			</form>
		</Form>
	);
}
