"use client";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { Button } from "@/components/ui/button";
import {
	Form,
	FormControl,
	FormField,
	FormItem,
	FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";

import { Eye, EyeOff } from "lucide-react";
import { useState } from "react";
import Link from "next/link";
import { useLoginMutation } from "@/redux/feature/auth/authApi";
import { verifyToken } from "@/utils/verify-token";
import { useAppDispatch, useAppSelector } from "@/redux/feature/hooks";
import {
	setUser,
	TUser,
	useCurrentToken,
} from "@/redux/feature/auth/authSlice";
import { toast } from "sonner";
import { useRouter } from "next/navigation";

const formSchema = z.object({
	email: z.string().email("Enter a valid email"),
	password: z.string().min(1, { message: "Password is required" }),
	rememberDevice: z.boolean(),
});

export function LoginForm() {
	const router = useRouter();
	const token = useAppSelector(useCurrentToken);

	const [login, { isLoading }] = useLoginMutation();
	const dispatch = useAppDispatch();

	const form = useForm<z.infer<typeof formSchema>>({
		resolver: zodResolver(formSchema),
		defaultValues: {
			email: "",
			password: "",
			rememberDevice: true,
		},
	});

	async function onSubmit(values: z.infer<typeof formSchema>) {
		const toastId = "sonner1";
		try {
			const res = await login(values).unwrap();
			const user = verifyToken(res.data.accessToken) as TUser;
			dispatch(setUser({ user, token: res.data.accessToken }));
			toast.success("Login successful", { id: toastId });
			// eslint-disable-next-line
		} catch (error: any) {
			console.log("ee", error);
			toast.error(error?.data.message || "Login failed. Try again", {
				id: toastId,
			});
		}
	}
	if (token) {
		router.replace("/");
	}
	return (
		<Form {...form}>
			<form onSubmit={form.handleSubmit(onSubmit)} className="space-y-5">
				<FormField
					control={form.control}
					name="email"
					render={({ field }) => (
						<FormItem>
							<FormControl>
								<Input placeholder="Email" className="h-11" {...field} />
							</FormControl>
							<FormMessage />
						</FormItem>
					)}
				/>
				<FormField
					control={form.control}
					name="password"
					render={({ field }) => {
						// eslint-disable-next-line
						const [isPasswordVisible, setIsPasswordVisible] = useState(false);
						const togglePasswordVisibility = () => {
							setIsPasswordVisible((prev) => !prev);
						};
						return (
							<FormItem className="relative">
								<FormControl>
									<Input
										placeholder="Password"
										className="h-11 pr-10"
										type={isPasswordVisible ? "text" : "password"}
										{...field}
									/>
								</FormControl>
								<button
									type="button"
									onClick={togglePasswordVisibility}
									className="absolute right-3 top-[23px] transform -translate-y-1/2 "
								>
									{isPasswordVisible ? <EyeOff size={20} /> : <Eye size={20} />}
								</button>
								<FormMessage />
							</FormItem>
						);
					}}
				/>
				<Button
					type="submit"
					className="w-full h-11 mt-2 cursor-pointer"
					disabled={isLoading}
				>
					{isLoading ? "Logging in.." : "Login"}
				</Button>
			</form>
			<div className="">
				<Link href="/forgot-password">
					<Button variant="link" className="cursor-pointer">
						Forgot password? - Reset
					</Button>
				</Link>
			</div>
		</Form>
	);
}
