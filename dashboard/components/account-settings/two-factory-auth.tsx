"use client";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { Shield, ShieldCheck, Phone, AlertTriangle } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
	Card,
	CardContent,
	CardDescription,
	CardHeader,
	CardTitle,
} from "@/components/ui/card";
import {
	Form,
	FormControl,
	FormField,
	FormItem,
	FormLabel,
	FormMessage,
	FormDescription,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { toast } from "sonner";
import { PhoneInput } from "./phone-input";

const phoneSchema = z.object({
	phoneNumber: z.string().regex(/^\+?[1-9]\d{1,14}$/, {
		message: "Please enter a valid phone number with country code.",
	}),
});

const otpSchema = z.object({
	otp: z.string().length(6, "OTP must be exactly 6 digits"),
});

type PhoneData = z.infer<typeof phoneSchema>;
type OtpData = z.infer<typeof otpSchema>;

export function TwoFactorAuth() {
	const [is2FAEnabled, setIs2FAEnabled] = useState(false);
	const [registeredPhone, setRegisteredPhone] = useState("+1 (555) 123-4567");
	const [currentFlow, setCurrentFlow] = useState<"none" | "enable" | "disable">(
		"none"
	);
	const [otpStep, setOtpStep] = useState<"phone" | "verify">("phone");
	const [isLoading, setIsLoading] = useState(false);
	// eslint-disable-next-line @typescript-eslint/no-unused-vars
	const [otpSent, setOtpSent] = useState(false);
	const [countdown, setCountdown] = useState(0);

	const phoneForm = useForm<PhoneData>({
		resolver: zodResolver(phoneSchema),
		defaultValues: {
			phoneNumber: "",
		},
	});

	const otpForm = useForm<OtpData>({
		resolver: zodResolver(otpSchema),
		defaultValues: {
			otp: "",
		},
	});

	const startCountdown = () => {
		setCountdown(60);
		const timer = setInterval(() => {
			setCountdown((prev) => {
				if (prev <= 1) {
					clearInterval(timer);
					return 0;
				}
				return prev - 1;
			});
		}, 1000);
	};

	const handleSendOtp = async (data: PhoneData) => {
		setIsLoading(true);

		// Simulate OTP sending
		await new Promise((resolve) => setTimeout(resolve, 1500));

		console.log("Sending OTP to:", data.phoneNumber);
		setOtpSent(true);
		setOtpStep("verify");
		setIsLoading(false);
		startCountdown();
		toast.success("OTP sent to your phone number");
	};

	const handleSendOtpToRegistered = async () => {
		setIsLoading(true);

		// Simulate OTP sending to registered phone
		await new Promise((resolve) => setTimeout(resolve, 1500));

		console.log("Sending OTP to registered phone:", registeredPhone);
		setOtpSent(true);
		setOtpStep("verify");
		setIsLoading(false);
		startCountdown();
		toast.success("OTP sent to your registered phone number");
	};

	const handleVerifyOtp = async (data: OtpData) => {
		setIsLoading(true);

		// Simulate OTP verification
		await new Promise((resolve) => setTimeout(resolve, 2000));

		console.log("Verifying OTP:", data.otp);

		// Mock verification - in real app, verify with backend
		if (data.otp === "123456") {
			if (currentFlow === "enable") {
				const phoneNumber = phoneForm.getValues("phoneNumber");
				setRegisteredPhone(phoneNumber);
				setIs2FAEnabled(true);
				toast.success("Two-factor authentication enabled successfully!");
			} else if (currentFlow === "disable") {
				setIs2FAEnabled(false);
				toast.success("Two-factor authentication disabled successfully!");
			}

			// Reset forms and state
			setCurrentFlow("none");
			setOtpStep("phone");
			setOtpSent(false);
			phoneForm.reset();
			otpForm.reset();
		} else {
			toast.error("Invalid OTP. Please try again.");
		}

		setIsLoading(false);
	};

	const handleResendOtp = async () => {
		if (countdown > 0) return;

		setIsLoading(true);
		await new Promise((resolve) => setTimeout(resolve, 1000));

		startCountdown();
		setIsLoading(false);
		toast.success("OTP resent successfully");
	};

	const startEnableFlow = () => {
		setCurrentFlow("enable");
		setOtpStep("phone");
		setOtpSent(false);
		phoneForm.reset();
		otpForm.reset();
	};

	const startDisableFlow = () => {
		setCurrentFlow("disable");
		setOtpStep("verify");
		setOtpSent(false);
		otpForm.reset();
		handleSendOtpToRegistered();
	};

	const cancelFlow = () => {
		setCurrentFlow("none");
		setOtpStep("phone");
		setOtpSent(false);
		phoneForm.reset();
		otpForm.reset();
	};

	// Show setup/verification flow
	if (currentFlow !== "none") {
		return (
			<Card>
				<CardHeader>
					<CardTitle className="flex items-center gap-2">
						<Shield className="h-5 w-5" />
						{currentFlow === "enable" ? "Enable" : "Disable"} Two-Factor
						Authentication
					</CardTitle>
					<CardDescription>
						{currentFlow === "enable"
							? "Verify your phone number to enable SMS-based two-factor authentication."
							: "Verify your identity to disable two-factor authentication."}
					</CardDescription>
				</CardHeader>
				<CardContent className="space-y-6">
					{currentFlow === "enable" && otpStep === "phone" && (
						<div className="space-y-4">
							<Alert className="bg-amber-100 border-amber-200">
								<Phone className="h-4 w-4" />
								<AlertDescription>
									Enter your phone number to receive SMS verification codes for
									two-factor authentication.
								</AlertDescription>
							</Alert>

							<Form {...phoneForm}>
								<form
									onSubmit={phoneForm.handleSubmit(handleSendOtp)}
									className="space-y-4"
								>
									<FormField
										control={phoneForm.control}
										name="phoneNumber"
										render={({ field }) => (
											<FormItem className="flex flex-col items-start">
												<FormLabel>Phone Number</FormLabel>
												<FormControl className="w-full">
													<PhoneInput
														placeholder="Enter your phone number"
														{...field}
														defaultCountry="BD"
													/>
												</FormControl>

												<FormMessage />
											</FormItem>
										)}
									/>

									<div className="flex gap-2">
										<Button
											type="button"
											variant="outline"
											onClick={cancelFlow}
										>
											Cancel
										</Button>
										<Button type="submit" disabled={isLoading}>
											{isLoading ? "Sending..." : "Send OTP"}
										</Button>
									</div>
								</form>
							</Form>
						</div>
					)}

					{otpStep === "verify" && (
						<div className="space-y-4">
							<Alert>
								<Phone className="h-4 w-4" />
								<AlertDescription>
									We&lsquo;ve sent a 6-digit verification code to{" "}
									<strong>
										{currentFlow === "enable"
											? phoneForm.getValues("phoneNumber")
											: registeredPhone}
									</strong>
								</AlertDescription>
							</Alert>

							<Form {...otpForm}>
								<form
									onSubmit={otpForm.handleSubmit(handleVerifyOtp)}
									className="space-y-4"
								>
									<FormField
										control={otpForm.control}
										name="otp"
										render={({ field }) => (
											<FormItem>
												<FormLabel>Verification Code</FormLabel>
												<FormControl>
													<Input
														placeholder="123456"
														maxLength={6}
														className="font-mono text-center text-lg tracking-widest"
														{...field}
													/>
												</FormControl>
												<FormDescription>
													Enter the 6-digit code sent to your phone
												</FormDescription>
												<FormMessage />
											</FormItem>
										)}
									/>

									<div className="flex items-center justify-between">
										<Button
											type="button"
											variant="ghost"
											onClick={handleResendOtp}
											disabled={countdown > 0 || isLoading}
											className="text-sm"
										>
											{countdown > 0 ? `Resend in ${countdown}s` : "Resend OTP"}
										</Button>
									</div>

									<div className="flex gap-2">
										<Button
											type="button"
											variant="outline"
											onClick={cancelFlow}
										>
											Cancel
										</Button>
										<Button
											type="submit"
											disabled={
												isLoading ||
												!otpForm.watch("otp") ||
												otpForm.watch("otp").length !== 6
											}
										>
											{isLoading
												? "Verifying..."
												: currentFlow === "enable"
												? "Enable 2FA"
												: "Disable 2FA"}
										</Button>
									</div>
								</form>
							</Form>
						</div>
					)}

					<Alert>
						<AlertTriangle className="h-4 w-4" />
						<AlertDescription>
							<strong>Important:</strong> SMS charges may apply. Make sure you
							have access to this phone number as you&apos;ll need it to sign
							in.
						</AlertDescription>
					</Alert>
				</CardContent>
			</Card>
		);
	}

	// Show main 2FA status
	return (
		<Card className="w-full">
			<CardHeader className="">
				<CardTitle className="flex items-center gap-2">
					{is2FAEnabled ? (
						<ShieldCheck className="h-5 w-5 text-green-600" />
					) : (
						<Shield className="h-5 w-5" />
					)}
					Two-Factor Authentication
				</CardTitle>
				<CardDescription>
					Secure your account with SMS-based two-factor authentication.
				</CardDescription>
			</CardHeader>
			<Separator />
			<CardContent className="space-y-4">
				<div className="flex items-center justify-between">
					<div className="space-y-1">
						<p className="font-medium">
							Two-factor authentication is{" "}
							{is2FAEnabled ? "enabled" : "disabled"}
						</p>
						<p className="text-sm text-muted-foreground">
							{is2FAEnabled
								? `SMS codes will be sent to ${registeredPhone}`
								: "Add an extra layer of security with SMS verification"}
						</p>
					</div>
					<Badge variant={is2FAEnabled ? "default" : "secondary"}>
						{is2FAEnabled ? "Enabled" : "Disabled"}
					</Badge>
				</div>

				{is2FAEnabled ? (
					<div className="space-y-4">
						<Alert>
							<ShieldCheck className="h-4 w-4" />
							<AlertDescription>
								Two-factor authentication is active. You&apos;ll receive SMS
								codes at <strong>{registeredPhone}</strong> when signing in.
							</AlertDescription>
						</Alert>

						<Separator />

						<div className="space-y-2">
							<h4 className="font-medium text-sm">Registered Phone Number</h4>
							<div className="flex items-center gap-2 text-sm">
								<Phone className="h-4 w-4 text-muted-foreground" />
								<span className="font-mono">{registeredPhone}</span>
							</div>
						</div>

						<Button variant="destructive" onClick={startDisableFlow}>
							Disable Two-Factor Authentication
						</Button>
					</div>
				) : (
					<Button onClick={startEnableFlow}>
						Enable Two-Factor Authentication
					</Button>
				)}
			</CardContent>
		</Card>
	);
}
