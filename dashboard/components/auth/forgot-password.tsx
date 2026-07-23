"use client";

import { useEffect, useState } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";

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
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { CircleCheckBig, Eye, EyeOff } from "lucide-react";
import { useRouter } from "next/navigation";

const emailSchema = z.object({
	email: z.string().email("Enter a valid email"),
});

const otpSchema = z.object({
	otp: z.string().min(4, "OTP must be at least 4 characters"),
});

const passwordSchema = z
	.object({
		password: z.string().min(6, "Password must be at least 6 characters"),
		confirmPassword: z.string(),
	})
	.refine((data) => data.password === data.confirmPassword, {
		message: "Passwords do not match",
		path: ["confirmPassword"],
	});

type EmailSchema = z.infer<typeof emailSchema>;
type OtpSchema = z.infer<typeof otpSchema>;
type PasswordSchema = z.infer<typeof passwordSchema>;

export function ForgotPasswordForm() {
	const [step, setStep] = useState<"email" | "otp" | "reset" | "success">(
		"email"
	);
	const [showPassword, setShowPassword] = useState(false);
	const [showConfirm, setShowConfirm] = useState(false);

	const emailForm = useForm<EmailSchema>({
		resolver: zodResolver(emailSchema),
		defaultValues: { email: "" },
	});

	const otpForm = useForm<OtpSchema>({
		resolver: zodResolver(otpSchema),
		defaultValues: { otp: "" },
	});

	const resetForm = useForm<PasswordSchema>({
		resolver: zodResolver(passwordSchema),
		defaultValues: { password: "", confirmPassword: "" },
	});
	// eslint-disable-next-line @typescript-eslint/no-unused-vars
	const onEmailSubmit = (values: EmailSchema) => {
		toast.success("OTP sent to email");
		setStep("otp");
	};
	// eslint-disable-next-line @typescript-eslint/no-unused-vars
	const onOtpSubmit = (values: OtpSchema) => {
		toast.success("OTP verified");
		setStep("reset");
	};
	// eslint-disable-next-line @typescript-eslint/no-unused-vars
	const onResetSubmit = (values: PasswordSchema) => {
		toast.success("Password reset successful");
		setStep("success");
	};

	// Add at the top of your component
	const [timeLeft, setTimeLeft] = useState(180); // 180 seconds = 3 minutes
	const [isResendAvailable, setIsResendAvailable] = useState(false);

	// Countdown effect
	useEffect(() => {
		if (step === "otp" && timeLeft > 0) {
			const timer = setInterval(() => {
				setTimeLeft((prev) => prev - 1);
			}, 1000);
			return () => clearInterval(timer);
		} else if (timeLeft === 0) {
			setIsResendAvailable(true);
		}
	}, [step, timeLeft]);

	// Format seconds to mm:ss
	const formatTime = (seconds: number) => {
		const m = String(Math.floor(seconds / 60)).padStart(2, "0");
		const s = String(seconds % 60).padStart(2, "0");
		return `${m}:${s}`;
	};

	// Handle resend
	const handleResendOtp = () => {
		setTimeLeft(180);
		setIsResendAvailable(false);
		toast.success("OTP resent successfully");
		// trigger resend API call here if needed
	};

	const router = useRouter();
	return (
		<div className="flex flex-col items-center justify-center w-full p-4 h-screen">
			<Card className="w-full max-w-md">
				<CardHeader className="text-center">
					<h2 className="text-xl font-semibold">
						{step === "email"
							? "Forgot your password?"
							: step === "otp"
							? "Verify OTP"
							: step === "reset"
							? "Reset Password"
							: ""}
					</h2>
					<p className="text-sm text-muted-foreground">
						{step === "email"
							? "We’ll email you an OTP to verify your identity."
							: step === "otp"
							? "Enter your OTP to verify your identity."
							: step === "reset"
							? "Enter your new password below."
							: ""}
					</p>
				</CardHeader>

				<CardContent>
					{/* Email Form */}
					{step === "email" && (
						<Form {...emailForm}>
							<form
								onSubmit={emailForm.handleSubmit(onEmailSubmit)}
								className="space-y-5"
							>
								<FormField
									control={emailForm.control}
									name="email"
									render={({ field }) => (
										<FormItem>
											<FormControl>
												<Input
													placeholder="Enter your account email"
													className="h-11"
													{...field}
												/>
											</FormControl>
											<FormMessage />
										</FormItem>
									)}
								/>
								<Button type="submit" className="w-full h-11">
									Send OTP
								</Button>
							</form>
						</Form>
					)}

					{/* OTP Form */}
					{step === "otp" && (
						<Form {...otpForm}>
							<form
								onSubmit={otpForm.handleSubmit(onOtpSubmit)}
								className="space-y-5"
							>
								<FormField
									control={otpForm.control}
									name="otp"
									render={({ field }) => (
										<FormItem>
											<FormControl>
												<Input
													placeholder="Enter the OTP"
													className="h-11"
													{...field}
												/>
											</FormControl>
											<FormMessage />
										</FormItem>
									)}
								/>

								<Button type="submit" className="w-full h-11">
									Verify OTP
								</Button>

								<div className="text-center pt-2">
									{isResendAvailable ? (
										<Button
											variant="link"
											type="button"
											className="text-sm"
											onClick={handleResendOtp}
										>
											Didn&apos;t receive OTP? Resend
										</Button>
									) : (
										<p className="text-sm text-muted-foreground">
											Resend available in {formatTime(timeLeft)}
										</p>
									)}
								</div>
							</form>
						</Form>
					)}

					{/* Reset Password Form */}
					{step === "reset" && (
						<Form {...resetForm}>
							<form
								onSubmit={resetForm.handleSubmit(onResetSubmit)}
								className="space-y-5"
							>
								<FormField
									control={resetForm.control}
									name="password"
									render={({ field }) => (
										<FormItem>
											<FormLabel>New Password</FormLabel>
											<FormControl>
												<div className="relative">
													<Input
														type={showPassword ? "text" : "password"}
														className="h-11 pr-10"
														placeholder="New password"
														{...field}
													/>
													<Button
														type="button"
														variant="ghost"
														size="icon"
														className="absolute right-1 top-1/2 -translate-y-1/2 h-8 w-8"
														onClick={() => setShowPassword((prev) => !prev)}
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
								<FormField
									control={resetForm.control}
									name="confirmPassword"
									render={({ field }) => (
										<FormItem>
											<FormLabel>Confirm Password</FormLabel>
											<FormControl>
												<div className="relative">
													<Input
														type={showConfirm ? "text" : "password"}
														className="h-11 pr-10"
														placeholder="Confirm password"
														{...field}
													/>
													<Button
														type="button"
														variant="ghost"
														size="icon"
														className="absolute right-1 top-1/2 -translate-y-1/2 h-8 w-8"
														onClick={() => setShowConfirm((prev) => !prev)}
													>
														{showConfirm ? (
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
								<Button type="submit" className="w-full h-11">
									Reset Password
								</Button>
							</form>
						</Form>
					)}

					{/* Final Success Message */}
					{step === "success" && (
						<div className="gap-4 py-8 flex flex-col items-center justify-center">
							<CircleCheckBig size={60} className="text-green-600" />
							<p className="text-green-600 font-semibold">
								Your password has been reset successfully!
							</p>
							<Button
								className="w-full mt-8"
								onClick={() => router.push("/login")}
							>
								Back to Login
							</Button>
						</div>
					)}
				</CardContent>
			</Card>
		</div>
	);
}
