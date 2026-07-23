// components/AuthGuard.tsx
"use client";

import { useCurrentToken } from "@/redux/feature/auth/authSlice";
import { useAppSelector } from "@/redux/feature/hooks";
import { useRouter } from "next/navigation";
import { useEffect } from "react";

export default function AuthGuard({ children }: { children: React.ReactNode }) {
	const token = useAppSelector(useCurrentToken);
	const router = useRouter();

	useEffect(() => {
		if (!token) {
			router.replace("/login");
		}
	}, [token, router]);

	if (!token) return null;

	return <>{children}</>;
}
