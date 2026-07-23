// Handle uncaught exceptions
process.on("uncaughtException", (err) => {
	console.error("Uncaught Exception detected. Shutting down...", err);
	process.exit(1);
});

import app from "./app";
import init from "./init";

const port = process.env.PORT || 4000;

// Start the server and store the server instance
const server = app.listen(port, () => {
	console.log(`Server is running on port ${port}`);
	init();
});

// Handle unhandled promise rejections
process.on("unhandledRejection", (err) => {
	console.error("Unhandled Rejection detected. Shutting down...", err);
	server.close(() => {
		process.exit(1);
	});
});
