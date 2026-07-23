// import { NextRequest, NextResponse } from "next/server";

// // Define public and auth-only routes
// const PUBLIC_ROUTES = ["/about", "/contact"];
// const AUTH_ROUTES = ["/login", "/register", "/forgot-password"];

// export function middleware(request: NextRequest) {
// 	const { pathname } = request.nextUrl;

// 	// Get raw token from Authorization header
// 	const token = request.cookies.get("refreshToken")?.value;

// 	const isPublic = PUBLIC_ROUTES.some((route) => pathname.startsWith(route));
// 	const isAuthRoute = AUTH_ROUTES.some((route) => pathname.startsWith(route));

// 	// If accessing a protected route and not logged in → redirect to login
// 	if (!isPublic && !isAuthRoute && !token) {
// 		return NextResponse.redirect(new URL("/login", request.url));
// 	}

// 	// If accessing an auth-only route while logged in → redirect to dashboard
// 	if (isAuthRoute && token) {
// 		return NextResponse.redirect(new URL("/", request.url));
// 	}

// 	return NextResponse.next();
// }

// export const config = {
// 	matcher: ["/((?!_next|static|.*\\..*|api|favicon.ico).*)"],
// };
