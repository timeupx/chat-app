"use client";

import * as React from "react";
import {
	Select,
	SelectContent,
	SelectGroup,
	SelectItem,
	SelectLabel,
	SelectTrigger,
	SelectValue,
} from "@/components/ui/select";

export function SettingsDropdown() {
	const handleSelectChange = (value: string) => {
		// Navigate to the selected value (assuming value is a valid URL or path)
		window.location.href = value;
	};

	return (
		<Select onValueChange={handleSelectChange}>
			<SelectTrigger className="w-full">
				<SelectValue placeholder="Account Settings" />
			</SelectTrigger>
			<SelectContent>
				<SelectGroup>
					<SelectLabel>Account Settings</SelectLabel>
					<SelectItem value="/settings">Profile</SelectItem>
					<SelectItem value="/settings/security">Security</SelectItem>
					<SelectItem value="/settings/delete-account">
						Delete Account
					</SelectItem>
				</SelectGroup>
			</SelectContent>
		</Select>
	);
}
