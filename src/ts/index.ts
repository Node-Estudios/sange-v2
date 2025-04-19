// Import the singleton manager
import { EngineManager } from './middle-layer/EngineManager.js'; // Adjust path if needed

async function main() {
    console.log("Starting Sange-v2 Application...");

    // Get the EngineManager instance
    const engineManager = EngineManager.getInstance();

    // Initialize the engine (calls Zig)
    const initialized = await engineManager.initialize();

    if (initialized) {
        console.log("Sange-v2 Engine Manager Initialized successfully.");

        // --- Example Usage (replace with your actual bot logic) ---
        // const stream = await engineManager.createStream("your_test_url", (packet) => {
        //     console.log(`Received RTP packet, sequence: ${/* decode sequence? */''}`);
        //     // Send packet to Discord voice connection here
        // });
        //
        // if (stream) {
        //     await stream.play();
        //     // ... wait or do other things ...
        //     await stream.pause();
        //     await stream.stop(); // stop might trigger destroy via callback
        //     // or await stream.destroy(); explicitly
        // }
        // --- End Example Usage ---

        // Example shutdown handling (e.g., on process exit)
        process.on('SIGINT', async () => {
            console.log("Received SIGINT. Shutting down...");
            await engineManager.shutdown();
            process.exit(0);
        });

    } else {
        console.error("Sange-v2 Engine Manager failed to initialize. Exiting.");
        process.exit(1);
    }
}

// Run the main function
main().catch(error => {
    console.error("Unhandled error in main function:", error);
    process.exit(1);
});