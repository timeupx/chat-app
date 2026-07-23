// components/theme/theme-context.tsx
"use client";

import React, {
	createContext,
	useContext,
	useEffect,
	useLayoutEffect,
	useState,
} from "react";

type ThemeMode = "light" | "dark" | "system";
type ThemeName =
	| "default"
	| "theme-red"
	| "theme-green"
	| "theme-blue"
	| "theme-rose"
	| "theme-yellow";

interface ThemeContextType {
	theme: ThemeName;
	mode: ThemeMode;
	setTheme: (theme: ThemeName) => void;
	setMode: (mode: ThemeMode) => void;
}

const ThemeContext = createContext<ThemeContextType | null>(null);

export const ThemeProvider = ({ children }: { children: React.ReactNode }) => {
	const [theme, setThemeState] = useState<ThemeName>("default");
	const [mode, setModeState] = useState<ThemeMode>("system");
	const [isLoaded, setIsLoaded] = useState(false);

	// Avoid FOUC by applying stored settings early
	useLayoutEffect(() => {
		const storedTheme = localStorage.getItem("app-theme") as ThemeName | null;
		const storedMode = localStorage.getItem("app-mode") as ThemeMode | null;

		if (storedTheme) applyTheme(storedTheme);
		if (storedMode) applyMode(storedMode);

		setIsLoaded(true);
	}, []);

	// Apply theme classes
	const applyTheme = (newTheme: ThemeName) => {
		const html = document.documentElement;

		// Remove all known theme classes
		html.classList.remove(
			"default",
			"theme-red",
			"theme-green",
			"theme-blue",
			"theme-rose",
			"theme-yellow"
		);
		html.classList.add(newTheme);

		localStorage.setItem("app-theme", newTheme);
		setThemeState(newTheme);
	};

	// Apply mode classes
	const applyMode = (newMode: ThemeMode) => {
		const html = document.documentElement;

		const isDark =
			newMode === "dark" ||
			(newMode === "system" &&
				window.matchMedia("(prefers-color-scheme: dark)").matches);

		html.classList.remove("light", "dark");
		html.classList.add(isDark ? "dark" : "light");

		localStorage.setItem("app-mode", newMode);
		setModeState(newMode);
	};

	// Prevent FOUC while loading
	useLayoutEffect(() => {
		document.documentElement.classList.add("invisible");
	}, []);

	// Reveal page once loaded
	useEffect(() => {
		if (isLoaded) {
			document.documentElement.classList.remove("invisible");
		}
	}, [isLoaded]);

	if (!isLoaded) return null;

	return (
		<ThemeContext.Provider
			value={{
				theme: theme,
				mode: mode,
				setTheme: applyTheme,
				setMode: applyMode,
			}}
		>
			{children}
		</ThemeContext.Provider>
	);
};

export const useThemeApp = () => {
	const ctx = useContext(ThemeContext);
	if (!ctx) throw new Error("useThemeApp must be used inside ThemeProvider");
	return ctx;
};
