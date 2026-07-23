import { baseApi } from "../../api/baseApi";
export type ContactMessage = {
	id: string;
	subject: string;
	name: string;
	email: string;
	message: string;
	phone: string;
	isRead: boolean;
	createdAt: Date;
	updatedAt: Date;
};

const contactApi = baseApi.injectEndpoints({
	endpoints: (builder) => ({
		createMessage: builder.mutation({
			query: (data) => ({
				url: "/contact",
				method: "POST",
				body: data,
			}),
		}),

		getAllMessages: builder.query({
			query: () => ({
				url: "/contact",
				method: "GET",
			}),
			providesTags: ["Messages"],
		}),

		getMessagesById: builder.query({
			query: (id: string) => ({
				url: `/contact/${id}`,
				method: "GET",
			}),
			providesTags: ["Messages"],
		}),

		readMessage: builder.mutation({
			query: (id: string) => ({
				url: `/contact/${id}/read`,
				method: "PATCH",
			}),
			invalidatesTags: ["Messages"],
		}),

		deleteMessage: builder.mutation({
			query: (id: string) => ({
				url: `/contact/${id}/delete`,
				method: "DELETE",
			}),
			invalidatesTags: ["Messages"],
		}),
	}),
});

export const {
	useCreateMessageMutation,
	useGetAllMessagesQuery,
	useGetMessagesByIdQuery,
	useReadMessageMutation,
	useDeleteMessageMutation,
} = contactApi;
