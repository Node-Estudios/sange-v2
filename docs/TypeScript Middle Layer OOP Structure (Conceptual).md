This outlines a potential class structure for the TypeScript Middle Layer, designed to interact with the Zig Engine API and implement the required callbacks.

---
- **`EngineManager` (Likely Singleton)**
    
    - **Responsibilities:**
        - Manages the global lifecycle of the Zig Engine (`initialize_engine`, `shutdown_engine`).
        - Holds the global `EngineHandle`.
        - Manages a collection (e.g., `Map<streamId, Stream>`) of active `Stream` instances.
        - Acts as the entry point for creating new streams.
        - Potentially houses the static callback methods invoked by Zig, dispatching them to the correct `Stream` instance.
    - **Key Methods/Properties:**
        - `async initialize()`
        - `async shutdown()`
        - `async createStream(url: string, sendRtpPacket: (packet: Buffer) => void): Promise<Stream>` (Receives the sending function from the High Layer or other context).
        - `getStream(streamId: number): Stream | undefined`
        - `removeStream(streamId: number): void`
        - `static _onRtpPacketCallback(...)` (Finds stream via ID, calls its packet handler).
        - `static _onStreamStatusCallback(...)` (Finds stream via ID, calls its status handler).
- **`Stream`**
    
    - **Responsibilities:**
        - Represents a single, active audio stream managed by Zig.
        - Holds the unique `streamId` and the opaque `streamHandle` returned by Zig's `create_stream`.
        - Holds the function needed to send RTP packets for _this specific stream_ (`sendRtpPacket`).
        - Provides methods to control the stream (play, pause, stop, volume) by calling the corresponding Zig functions.
        - Maintains the current known status of the stream (mirroring updates from Zig).
        - Handles cleanup by calling `destroy_stream`.
    - **Key Methods/Properties:**
        - `readonly id: number`
        - `readonly zigHandle: StreamHandle` (Opaque handle type)
        - `readonly sendRtpPacket: (packet: Buffer) => void`
        - `currentStatus: StreamStatusCode`
        - `async play()`
        - `async pause()`
        - `async stop()`
        - `async setVolume(level: number)`
        - `async destroy()` (Calls `destroy_stream` in Zig and removes itself from `EngineManager`).
        - `_handlePacketData(packetData, sequence, timestamp, isSilence)` (Called by the static callback; uses `sendRtpPacket`).
        - `_handleStatusUpdate(statusCode, details)` (Called by the static callback; updates `currentStatus`, may trigger `destroy`).