import {
	BaseQueryApi,
	BaseQueryFn,
	DefinitionType,
	FetchArgs,
	createApi,
	fetchBaseQuery,
} from "@reduxjs/toolkit/query/react";
import { RootState } from "../feature/store";
import { logOut, setUser } from "../feature/auth/authSlice";
import { serverUrl } from "@/utils/config";

const baseQuery = fetchBaseQuery({
	baseUrl: `${serverUrl}/api/`,
	credentials: "include",
	prepareHeaders: (headers, { getState }) => {
		const token = (getState() as RootState).auth.token;

		if (token) {
			headers.set("authorization", `${token}`);
		}

		return headers;
	},
});

const baseQueryWithRefreshToken: BaseQueryFn<
	FetchArgs,
	BaseQueryApi,
	DefinitionType
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
> = async (args, api, extraOptions): Promise<any> => {
	let result = await baseQuery(args, api, extraOptions);

	if (result?.error?.status === 401) {
		//* Send Refresh
		console.log("Sending refresh token");

		const res = await fetch(`${serverUrl}/api/auth/refresh-token`, {
			method: "POST",
			credentials: "include",
		});

		const data = await res.json();

		if (data?.data?.accessToken) {
			const user = (api.getState() as RootState).auth.user;

			api.dispatch(
				setUser({
					user,
					token: data.data.accessToken,
				})
			);

			result = await baseQuery(args, api, extraOptions);
		} else {
			api.dispatch(logOut());
			console.log("error");
		}
	}

	return result;
};

export const baseApi = createApi({
	reducerPath: "baseApi",
	tagTypes: [
		"Profile",
		"Users",
		"TrustedDevices",
		"SystemSettings",
		"Messages",
	],
	baseQuery: baseQueryWithRefreshToken,
	endpoints: () => ({}),
});
