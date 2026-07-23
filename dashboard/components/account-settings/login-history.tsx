"use client";

import { useEffect, useState } from "react";
import { History, MapPin, Calendar, Globe } from "lucide-react";

import {
	Card,
	CardContent,
	CardDescription,
	CardHeader,
	CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
	Table,
	TableBody,
	TableCell,
	TableHead,
	TableHeader,
	TableRow,
} from "@/components/ui/table";
import { Separator } from "@/components/ui/separator";
import { useLoginHistoryQuery } from "@/redux/feature/auth/authApi";

interface LoginAttempt {
	id: string;
	timestamp: string;
	location: string;
	device: string;
	ipAddress: string;
	successful: boolean;
	createdAt: Date;
}

export function LoginHistory() {
	const [loginHistory, setLoginHistory] = useState<LoginAttempt[]>([]);

	const { data } = useLoginHistoryQuery(loginHistory);

	useEffect(() => {
		if (data) {
			setLoginHistory(data.data);
		}
	}, [data]);

	const formatDate = (timestamp: Date) => {
		return new Date(timestamp).toLocaleDateString(undefined, {
			month: "short",
			day: "numeric",
			hour: "2-digit",
			minute: "2-digit",
			second: "2-digit",
		});
	};

	return (
		<Card className="w-full">
			<CardHeader>
				<CardTitle className="flex items-center gap-2">
					<History className="h-5 w-5" />
					Login History
				</CardTitle>
				<CardDescription>
					Recent login attempts and security events for your account.
				</CardDescription>
			</CardHeader>
			<Separator />
			<CardContent className="p-6">
				{/* Desktop Table View */}
				<div className="hidden md:block">
					<div className="rounded-md border">
						<Table>
							<TableHeader>
								<TableRow>
									<TableHead>Date & Time</TableHead>
									<TableHead>Location</TableHead>
									<TableHead>Device</TableHead>
									<TableHead>Status</TableHead>
									<TableHead>IP Address</TableHead>
								</TableRow>
							</TableHeader>
							<TableBody>
								{loginHistory.map((attempt) => (
									<TableRow key={attempt.id}>
										<TableCell className="font-medium">
											{formatDate(attempt.createdAt)}
										</TableCell>
										<TableCell>
											<div className="flex items-center gap-2">
												<MapPin className="h-4 w-4 text-muted-foreground" />
												{attempt.location}
											</div>
										</TableCell>
										<TableCell>
											<div className="flex items-center gap-2">
												{attempt.device}
											</div>
										</TableCell>

										<TableCell>
											{attempt.successful ? (
												<Badge variant="default">Succeess</Badge>
											) : (
												<Badge variant="destructive">Failed</Badge>
											)}
										</TableCell>
										<TableCell className="font-mono text-sm">
											{attempt.ipAddress}
										</TableCell>
									</TableRow>
								))}
							</TableBody>
						</Table>
					</div>
				</div>

				{/* Mobile Card View */}
				<div className="md:hidden space-y-4">
					{loginHistory.map((attempt) => (
						<div key={attempt.id} className="border rounded-lg p-4 space-y-3">
							{/* Header with status and date */}
							<div className="flex items-center justify-between">
								<div className="flex items-center gap-1 text-sm text-muted-foreground">
									<Calendar className="h-3 w-3" />
									{formatDate(attempt.createdAt)}
								</div>
							</div>

							{/* Device info */}
							<div className="flex items-center gap-2">
								<span className="font-medium text-sm">{attempt.device}</span>
							</div>

							{/* Location */}
							<div className="flex items-center gap-2">
								<MapPin className="h-4 w-4 text-muted-foreground" />
								<span className="text-sm">{attempt.location}</span>
							</div>
							<div className="flex items-center gap-2">
								<span className="text-sm">
									{attempt.successful ? (
										<Badge variant="default">Succeess</Badge>
									) : (
										<Badge variant="destructive">Failed</Badge>
									)}
								</span>
							</div>

							{/* IP Address */}
							<div className="flex items-center gap-2">
								<Globe className="h-4 w-4 text-muted-foreground" />
								<span className="font-mono text-sm">{attempt.ipAddress}</span>
							</div>
						</div>
					))}
				</div>
			</CardContent>
		</Card>
	);
}
