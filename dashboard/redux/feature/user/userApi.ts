import { baseApi } from "../../api/baseApi";
const userApi = baseApi.injectEndpoints({
	endpoints: (builder) => ({
		profile: builder.query({
			query: () => ({
				url: "/user/profile",
				method: "GET",
			}),
		}),
		updateProfile: builder.mutation({
			query: (data) => ({
				url: "/user/profile",
				method: "PATCH",
				body: data,
			}),
		}),
		deleteProfile: builder.mutation({
			query: (password) => ({
				url: "/user/profile",
				method: "DELETE",
				body: password,
			}),
		}),
		createUser: builder.mutation({
			query: (data) => ({
				url: "/user/create",
				method: "POST",
				body: data,
			}),
			invalidatesTags: ["Users"],
		}),

		getAllUsers: builder.query({
			query: () => ({
				url: "/user",
				method: "GET",
			}),
			providesTags: ["Users"],
		}),
		deleteUser: builder.mutation({
			query: (id) => ({
				url: `/user/${id}`,
				method: "DELETE",
			}),
			invalidatesTags: ["Users"],
		}),
		blockUser: builder.mutation({
			query: ({ id, data }) => ({
				url: `/user/${id}`,
				method: "PATCH",
				body: data,
			}),
			invalidatesTags: ["Users"],
		}),
		updateUser: builder.mutation({
			query: ({ id, data }) => ({
				url: `/user/${id}`,
				method: "PATCH",
				body: data,
			}),
			invalidatesTags: ["Users"],
		}),
	}),
});

export const {
	useProfileQuery,
	useUpdateProfileMutation,
	useDeleteProfileMutation,
	useCreateUserMutation,
	useGetAllUsersQuery,
	useDeleteUserMutation,
	useBlockUserMutation,
	useUpdateUserMutation,
} = userApi;
