"use client";

import {
	DropdownMenu,
	DropdownMenuTrigger,
	DropdownMenuContent,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { PaletteIcon } from "lucide-react";
import { useThemeApp } from "./theme-provider";
import {
	Select,
	SelectTrigger,
	SelectValue,
	SelectContent,
	SelectGroup,
	SelectLabel,
	SelectItem,
} from "@/components/ui/select";

const themes = [
	{ label: "Default", value: "default", color: "#000000" },
	{ label: "Sunset Glow", value: "theme-red", color: "#f87171" },
	{ label: "Green Harmony", value: "theme-green", color: "#4ade80" },
	{ label: "Ocean Blue", value: "theme-blue", color: "#60a5fa" },
	{ label: "Rose Petal", value: "theme-rose", color: "#fb7185" },
];

export function ThemeSwitcher() {
	const { theme, setTheme, mode, setMode } = useThemeApp();

	return (
		<DropdownMenu>
			<DropdownMenuTrigger asChild>
				<Button variant="outline" size="icon">
					<PaletteIcon className="h-5 w-5" />
				</Button>
			</DropdownMenuTrigger>

			<DropdownMenuContent className="w-72 p-4 space-y-4" align="end">
				{/* Theme Preset */}
				<div>
					<label className="block text-sm font-medium mb-1">
						Theme preset:
					</label>
					<Select
						value={theme}
						// eslint-disable-next-line @typescript-eslint/no-explicit-any
						onValueChange={(value) => setTheme(value as any)}
					>
						<SelectTrigger className="w-full">
							<SelectValue placeholder="Select theme" />
						</SelectTrigger>
						<SelectContent>
							<SelectGroup>
								<SelectLabel>Themes</SelectLabel>
								{themes.map((t) => (
									<SelectItem key={t.value} value={t.value}>
										<div className="flex items-center justify-between w-full">
											<span>{t.label}</span>
											<span
												className="w-3 h-3 rounded-full ml-2"
												style={{ backgroundColor: t.color }}
											/>
										</div>
									</SelectItem>
								))}
							</SelectGroup>
						</SelectContent>
					</Select>
				</div>

				{/* Mode Switch */}
				<div>
					<label className="block text-sm font-medium mb-1">Color mode:</label>
					<div className="flex gap-2">
						{["light", "dark"].map((m) => (
							<button
								key={m}
								onClick={() => setMode(m as "light" | "dark")}
								className={`flex-1 rounded-full px-4 py-2 text-sm font-medium border transition-colors ${
									mode === m
										? "bg-red-50 text-black border-red-300"
										: "bg-white dark:bg-zinc-800 text-gray-700 dark:text-gray-200 border-gray-300 dark:border-zinc-700"
								}`}
							>
								{m.charAt(0).toUpperCase() + m.slice(1)}
							</button>
						))}
					</div>
				</div>

				{/* Reset Button */}
				<div>
					<Button
						variant="destructive"
						className="w-full rounded-full"
						onClick={() => {
							setTheme("default");
							setMode("light");
						}}
					>
						Reset to Default
					</Button>
				</div>
			</DropdownMenuContent>
		</DropdownMenu>
	);
}
