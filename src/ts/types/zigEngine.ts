// Place this in a file like: src/ts/types/zig-engine-manual.d.ts 
// (Ensure your tsconfig.json includes this directory/file)

declare module '@zig/engine' {

    // --- Opaque Types (Manual Definition based on User Example) ---
    // NOTE: Using 'number' might not reflect Zigar's actual runtime representation.
    export type EngineHandle = unknown;
    export type StreamHandle = unknown;
    /** Represents the pointer to a C string from Zig. Utilities might need adjustment. */
    export type ZigarStringPointer = unknown; 

    // --- Enums (Mirroring Zig) ---
    // Assuming these mirror enums defined in Zig's types.zig
    export enum LogLevel {
        Debug = 0,
        Info = 1,
        Warn = 2,
        Error = 3,
    }

    export enum StreamStatusCode {
        Initializing = 0,
        Buffering = 1,
        Playing = 2,
        Paused = 3,
        Seeking = 4,
        Ended = 5,
        Stopped = 6,
        Error = 7,
    }

    // --- Callback Interfaces (Passed TO Zig) ---
    // These define the shape of objects TS passes to Zig functions.
    export interface EngineCallbacks {
        on_log_fn: (level: LogLevel, messageBytesPtr: ZigarStringPointer) => void;
    }

    export interface StreamCallbacks {
        on_rtp_packet_fn: (
            streamId: number, 
            packetData: Uint8Array, 
            sequence: number, 
            timestamp: number, 
            isSilence: boolean
        ) => void;
        on_stream_status_fn: (
            streamId: number, 
            statusCode: StreamStatusCode, 
            detailsPtr: ZigarStringPointer | null 
        ) => void;
    }

    // --- Exported Zig Functions (Signatures matching api.zig) ---

    /** Initializes the Zig engine. Returns handle or null on error. */
    export function initializeEngine(callbacks: EngineCallbacks): Promise<EngineHandle | null>;

    /** Shuts down the Zig engine and releases resources. */
    export function shutdownEngine(handle: EngineHandle): Promise<void>;

    /** Creates a new audio stream instance in Zig. Returns handle or null on error. */
    export function createStream(
        engineHandle: EngineHandle,
        streamId: number, 
        sourceUrl: string, 
        callbacks: StreamCallbacks
    ): Promise<StreamHandle | null>;

    /** Destroys a specific stream instance. Returns true on success. */
    export function destroyStream(engineHandle: EngineHandle, streamHandle: StreamHandle): Promise<boolean>;

    /** Starts or resumes playback. Returns true on success. */
    export function playStream(engineHandle: EngineHandle, streamHandle: StreamHandle): Promise<boolean>;

    /** Pauses playback. Returns true on success. */
    export function pauseStream(engineHandle: EngineHandle, streamHandle: StreamHandle): Promise<boolean>;

    /** Stops playback. Returns true on success. */
    export function stopStream(engineHandle: EngineHandle, streamHandle: StreamHandle): Promise<boolean>;

    /** Sets the volume (0.0-1.0). Returns true on success. */
    export function setStreamVolume(engineHandle: EngineHandle, streamHandle: StreamHandle, volume: number): Promise<boolean>;

    /** Simple test function returning a C string pointer. */
    export function ping(): ZigarStringPointer;

} // End of declare module