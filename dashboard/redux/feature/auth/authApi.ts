import { baseApi } from "../../api/baseApi";
const authApi = baseApi.injectEndpoints({
	endpoints: (builder) => ({
		login: builder.mutation({
			query: (credentials) => ({
				url: "/auth/login",
				method: "POST",
				body: credentials,
			}),
		}),
		updatePassword: builder.mutation({
			query: (data) => ({
				url: "/auth/change-password",
				method: "PATCH",
				body: data,
			}),
		}),
		trustedDevices: builder.query({
			query: () => ({
				url: "/auth/devices",
				method: "GET",
			}),
			providesTags: ["TrustedDevices"],
		}),
		deleteDevice: builder.mutation({
			query: (id: string) => ({
				url: `/auth/devices/${id}`,
				method: "DELETE",
			}),
			invalidatesTags: ["TrustedDevices"],
		}),

		loginHistory: builder.query({
			query: () => ({
				url: "/auth/login-history",
				method: "GET",
			}),
		}),
	}),
});

export const {
	useLoginMutation,
	useUpdatePasswordMutation,
	useTrustedDevicesQuery,
	useDeleteDeviceMutation,
	useLoginHistoryQuery,
} = authApi;
