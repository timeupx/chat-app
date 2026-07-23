import { createSlice } from "@reduxjs/toolkit";
import { RootState } from "../store";

export type TUser = {
	id?: string;
	userId?: string;
	name?: string;
	email?: string;
	phone?: string;
	emailVerified?: boolean;
	phoneVerified?: boolean;
	photo?: string;
	status?: string;
	address?: string;
	bio?: string;
	role?: string;
	iat?: number;
	exp?: number;
	createdAt?: Date;
	updatedAt?: Date;
	password: string;
};

type TAuthState = {
	user: null | object;
	token: null | string;
};
const initialState: TAuthState = {
	user: null,
	token: null,
};
const authSlice = createSlice({
	name: "auth",
	initialState,
	reducers: {
		setUser: (state, action) => {
			const { user, token } = action.payload;
			state.user = user;
			state.token = token;
		},

		logOut: (state) => {
			state.user = null;
			state.token = null;
		},
	},
});

export const { setUser, logOut } = authSlice.actions;

export default authSlice.reducer;

export const useCurrentToken = (state: RootState) => state.auth.token;
export const useCurrentUser = (state: RootState) => state.auth.user;
