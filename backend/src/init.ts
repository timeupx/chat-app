import bcrypt from "bcrypt";
import db from "./config/prisma";

export default function init() {
	const createAdminUser = async () => {
		const email = process.env.ADMIN_EMAIL || "admin@example.com";
		const password = process.env.ADMIN_PASSWORD || "Admin@123";
		const name = process.env.ADMIN_NAME || "Admin";

		const existingAdmin = await db.user.findUnique({ where: { email } });
		if (existingAdmin) return;

		const salt = await bcrypt.genSalt(10);
		const hashedPassword = await bcrypt.hash(password, salt);

		await db.user.create({
			data: {
				name,
				email,
				password: hashedPassword,
				role: "ADMIN",
				status: "ACTIVE",
				emailVerified: true,
				phoneVerified: true,
			},
		});

		console.log(`Default admin user created: ${email}`);
	};

	createAdminUser().catch((err) => {
		console.error("Failed to seed default admin user:", err);
	});
}
