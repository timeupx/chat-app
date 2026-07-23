import { baseApi } from "../../api/baseApi";
export type SystemSettings = {
	metaTitle?: string;
	metaDescription?: string;
	allowSignup?: boolean;
	maintenanceMode?: boolean;
	contact?: {
		email?: string;
		phone?: string;
		address?: string;
		facebook?: string;
		x?: string;
		instagram?: string;
		youtube?: string;
	};
	intigration?: {
		smsApiKey?: string;
		emailApiKey?: string;
	};
	analyticsSeo?: {
		gatId?: string;
		gtmId?: string;
		pixelId?: string;
	};
};

const systemApi = baseApi.injectEndpoints({
	endpoints: (builder) => ({
		updateSettings: builder.mutation({
			query: (data) => ({
				url: "/system-settings",
				method: "PATCH",
				body: data,
			}),
			invalidatesTags: ["SystemSettings"],
		}),

		getSettings: builder.query({
			query: () => ({
				url: "/system-settings",
				method: "GET",
			}),
			providesTags: ["SystemSettings"],
		}),
	}),
});

export const { useGetSettingsQuery, useUpdateSettingsMutation } = systemApi;
