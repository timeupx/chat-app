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
import { Textarea } from "@/components/ui/textarea";
import { useEffect, useState } from "react";
import {
	SystemSettings,
	useGetSettingsQuery,
	useUpdateSettingsMutation,
} from "@/redux/feature/system-settings/systemApi";

const formSchema = z.object({
	email: z.string().optional(),
	phone: z.string().min(1).optional(),
	address: z.string().optional(),
	facebook: z.string().min(1).optional(),
	instagram: z.string().min(1).optional(),
	x: z.string().min(1).optional(),
	youtube: z.string().min(1).optional(),
});

export default function ContactSettingsForm() {
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
				email: settings?.contact?.email,
				phone: settings?.contact?.phone,
				address: settings?.contact?.address,
				facebook: settings?.contact?.facebook,
				instagram: settings?.contact?.instagram,
				x: settings?.contact?.x,
				youtube: settings?.contact?.youtube,
			});
		}
	}, [data]);

	async function onSubmit(values: z.infer<typeof formSchema>) {
		try {
			const data = { contact: values };
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
					name="email"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Email Address</FormLabel>
							<FormControl>
								<Input placeholder="Email address" type="email" {...field} />
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
								<Input placeholder="Phone number" type="" {...field} />
							</FormControl>

							<FormMessage />
						</FormItem>
					)}
				/>

				<FormField
					control={form.control}
					name="address"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Address</FormLabel>
							<FormControl>
								<Textarea
									placeholder="Address"
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
					name="facebook"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Facebook</FormLabel>
							<FormControl>
								<Input
									placeholder="https://facebook.com/yourpage"
									type=""
									{...field}
								/>
							</FormControl>

							<FormMessage />
						</FormItem>
					)}
				/>

				<FormField
					control={form.control}
					name="instagram"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Instagram</FormLabel>
							<FormControl>
								<Input
									placeholder="https://instagram.com/yourpage"
									type=""
									{...field}
								/>
							</FormControl>

							<FormMessage />
						</FormItem>
					)}
				/>

				<FormField
					control={form.control}
					name="x"
					render={({ field }) => (
						<FormItem>
							<FormLabel>X</FormLabel>
							<FormControl>
								<Input
									placeholder="https://x.com/yourpage"
									type=""
									{...field}
								/>
							</FormControl>

							<FormMessage />
						</FormItem>
					)}
				/>

				<FormField
					control={form.control}
					name="youtube"
					render={({ field }) => (
						<FormItem>
							<FormLabel>Youtube</FormLabel>
							<FormControl>
								<Input
									placeholder="https://youtube.com/yourpage"
									type=""
									{...field}
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
