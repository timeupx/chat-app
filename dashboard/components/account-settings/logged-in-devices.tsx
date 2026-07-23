"use client";

import { useEffect, useState } from "react";
import { Monitor, MapPin, LogOut } from "lucide-react";

import {
	Card,
	CardContent,
	CardDescription,
	CardHeader,
	CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
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
import { Separator } from "../ui/separator";
import {
	useDeleteDeviceMutation,
	useTrustedDevicesQuery,
} from "@/redux/feature/auth/authApi";

interface LoggedInDevice {
	id: string;
	userId: string;
	deviceToken: string;
	ip: string;
	userAgent: string;
	browser: string;
	location: string;
	createdAt: Date;
	expiresAt: Date;
}

export function LoggedInDevices() {
	const [devices, setDevices] = useState<LoggedInDevice[]>([]);
	const [deviceToRevoke, setDeviceToRevoke] = useState<LoggedInDevice | null>(
		null
	);

	const { data } = useTrustedDevicesQuery(devices);
	const [deleteDevice, { isLoading: isDeleteing }] = useDeleteDeviceMutation();

	useEffect(() => {
		if (data) {
			setDevices(data.data);
		}
	}, [data]);

	console.log(data);

	const handleRevokeDevice = async (id: string) => {
		try {
			await deleteDevice(id).unwrap();
			toast.success("Device deleted successfully!");
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
		} catch (error: any) {
			console.log("Failed deleting device", error);
			toast.error(error.data.message || "Failed deleting device");
		}
	};

	return (
		<Card className="w-full">
			<CardHeader className="">
				<CardTitle className="flex items-center gap-2">
					<Monitor className="h-5 w-5" />
					Trusted Devices
				</CardTitle>
				<CardDescription>
					Manage devices that are currently signed in to your account.
				</CardDescription>
			</CardHeader>
			<Separator />
			<CardContent className="space-y-6">
				<div className="space-y-4">
					{devices.map((device) => (
						<div
							key={device.id}
							className="flex flex-col md:flex-row gap-2 items-start justify-between p-4 border rounded-lg"
						>
							<div className="flex items-start gap-3">
								<div className="space-y-1">
									<div className="flex items-center gap-2">
										<h3 className="font-medium">{device.userAgent}</h3>
										{/* {device.isCurrent && (
											<Badge variant="default" className="text-xs">
												Current Device
											</Badge>
										)} */}
									</div>
									<p className="text-sm text-muted-foreground">
										{device.userAgent} • {device.browser}
									</p>
									<div className="flex items-center gap-4 text-sm text-muted-foreground">
										<div className="flex items-center gap-1">
											<MapPin className="h-3 w-3" />
											{device.location}
										</div>
									</div>
									<p className="text-xs text-muted-foreground font-mono">
										IP: {device.ip}
									</p>
								</div>
							</div>

							<Button
								variant="outline"
								size="sm"
								onClick={() => setDeviceToRevoke(device)}
								className="text-red-600 hover:text-red-700 hover:bg-red-50"
							>
								<LogOut className="h-4 w-4 mr-2" />
								Revoke
							</Button>
						</div>
					))}
				</div>
			</CardContent>

			<AlertDialog
				open={!!deviceToRevoke}
				onOpenChange={() => setDeviceToRevoke(null)}
			>
				<AlertDialogContent>
					<AlertDialogHeader>
						<AlertDialogTitle>Revoke Device Session</AlertDialogTitle>
						<AlertDialogDescription>
							Are you sure you want to revoke the session for &quot;
							{deviceToRevoke?.userAgent}&quot;? This will sign out the device
							and require a new login.
						</AlertDialogDescription>
					</AlertDialogHeader>
					<AlertDialogFooter>
						<AlertDialogCancel>Cancel</AlertDialogCancel>
						<AlertDialogAction
							onClick={() =>
								deviceToRevoke && handleRevokeDevice(deviceToRevoke.id)
							}
							disabled={isDeleteing}
							className="bg-red-600 hover:bg-red-700"
						>
							{isDeleteing ? "Revoking..." : "Revoke Session"}
						</AlertDialogAction>
					</AlertDialogFooter>
				</AlertDialogContent>
			</AlertDialog>
		</Card>
	);
}
