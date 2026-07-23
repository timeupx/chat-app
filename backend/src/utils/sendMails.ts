import nodemailer from "nodemailer";
import { accountVerificationTemplate } from "../templates/accountVerification";
import { accountVerificationSuccess } from "../templates/accountVerificationSuccess";
import { newLoginAlertTemplate } from "../templates/newLoginAlert";
import db from "../config/prisma";
import { forgotPasswordTemplate } from "../templates/forgotPassword";
import { passwordChangeSuccessfulTemplate } from "../templates/passwordChange";
import { mfaEnabledTemplate } from "../templates/mfaEnabled";
import { StoreContactNotificationTemplate } from "../templates/contactMessageNotification";
import { StoreContactConfirmationTemplate } from "../templates/contactMessageNotifySender";
import { MFADisabledTemplate } from "../templates/mfaDisabled";

// Create a test account or replace with real credentials.
const transporter = nodemailer.createTransport({
	host: process.env.SMTP_SERVER,
	port: Number(process.env.SMTP_PORT),
	secure: false, // true for 465, false for other ports
	auth: {
		user: process.env.SMTP_USER,
		pass: process.env.SMTP_PASSWORD,
	},
});

// Send account activation email
const verificationEmail = async (
	email: string,
	code: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "Verify your account",
			html: accountVerificationTemplate.replace("{code}", code),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "Verify your account",
				body: accountVerificationTemplate.replace("{code}", code),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};
const forgotPasswordEmail = async (
	email: string,
	name: string,
	code: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "Reset password OTP",
			html: forgotPasswordTemplate
				.replace("{code}", code)
				.replace("{code}", code)
				.replace("{name}", name),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "Reset password OTP",
				body: forgotPasswordTemplate
					.replace("{code}", code)
					.replace("{code}", code)
					.replace("{name}", name),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};

const verificationSuccessEmail = async (
	email: string,
	name: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "Verification Successful!",
			html: accountVerificationSuccess.replace("{name}", name),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "Verify your account",
				body: accountVerificationTemplate.replace("{name}", name),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};

const newLoginAlertEmail = async (
	email: string,
	name: string,
	ipAddress: string,
	userAgent: string,
	browser: string,
	location: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "New Login Detected on your Nexweb account",
			html: newLoginAlertTemplate
				.replace("{name}", name)
				.replace("{ipAddress}", ipAddress)
				.replace("{userAgent}", userAgent)
				.replace("{location}", location)
				.replace("{browser}", browser)
				.replace("{loginTime}", new Date().toLocaleString()),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "New Login Detected on your Nexweb account",
				body: newLoginAlertTemplate
					.replace("{name}", name)
					.replace("{ipAddress}", ipAddress)
					.replace("{userAgent}", userAgent)
					.replace("{location}", location)
					.replace("{browser}", browser)
					.replace("{loginTime}", new Date().toLocaleString()),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};
const passwordChangeEmail = async (
	email: string,
	name: string,
	ipAddress: string,
	userAgent: string,
	browser: string,
	location: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "Password Changed Successfully",
			html: passwordChangeSuccessfulTemplate
				.replace("{name}", name)
				.replace("{ipAddress}", ipAddress)
				.replace("{userAgent}", userAgent)
				.replace("{location}", location)
				.replace("{browser}", browser)
				.replace("{changeTime}", new Date().toLocaleString()),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "Password Changed Successfully",
				body: passwordChangeSuccessfulTemplate
					.replace("{name}", name)
					.replace("{ipAddress}", ipAddress)
					.replace("{userAgent}", userAgent)
					.replace("{location}", location)
					.replace("{browser}", browser)
					.replace("{changeTime}", new Date().toLocaleString()),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};

const mfaEnabledEmail = async (email: string, name: string, source: string) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "Two-Factor Authentication Enabled",
			html: mfaEnabledTemplate.replace("{name}", name),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "Two-Factor Authentication Enabled",
				body: mfaEnabledTemplate.replace("{name}", name),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};

const mfaDisabledEmail = async (
	email: string,
	name: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "Two-Factor Authentication Disabled",
			html: MFADisabledTemplate.replace("{name}", name),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "Two-Factor Authentication Disabled",
				body: MFADisabledTemplate.replace("{name}", name),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};

const contactNotificationEmail = async (
	email: string,
	name: string,
	phone: string,
	senderEmail: string,
	subject: string,
	message: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "New Contact Form Submission",
			html: StoreContactNotificationTemplate.replace("{email}", senderEmail)
				.replace("{name}", name)
				.replace("{phone}", phone)
				.replace("{subject}", subject)
				.replace("{message}", message),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "New Contact Form Submission",
				body: StoreContactNotificationTemplate.replace("{email}", senderEmail)
					.replace("{name}", name)
					.replace("{phone}", phone)
					.replace("{subject}", subject)
					.replace("{message}", message),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};
const contactConfirmationEmail = async (
	email: string,
	name: string,
	subject: string,
	source: string
) => {
	try {
		const info = await transporter.sendMail({
			from: `"Nexweb" <${process.env.SENT_FROM}>`,
			to: `${email}`,
			subject: "Thank You for Contacting Us",
			html: StoreContactConfirmationTemplate.replace("{email}", email)
				.replace("{name}", name)
				.replace("{subject}", subject)
				.replace("{date}", new Date().toLocaleString()),
		});
		// Create email history
		await db.emailHistory.create({
			data: {
				sender: process.env.SENT_FROM as string,
				recipient: email,
				subject: "Thank You for Contacting Us",
				body: StoreContactConfirmationTemplate.replace("{email}", email)
					.replace("{name}", name)
					.replace("{subject}", subject)
					.replace("{date}", new Date().toLocaleString()),
				source: source,
			},
		});
		console.log("Message sent:", info.messageId);
	} catch (error) {
		console.error("Failed to send email:", error);
	}
};
export const sendMail = {
	verificationEmail,
	verificationSuccessEmail,
	newLoginAlertEmail,
	forgotPasswordEmail,
	passwordChangeEmail,
	mfaEnabledEmail,
	contactNotificationEmail,
	contactConfirmationEmail,
	mfaDisabledEmail,
};
