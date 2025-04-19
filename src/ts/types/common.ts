// src/ts/middle-layer/types/common.ts
// --- Opaque Handle Types (Manual Definition) ---
// Defined as 'unknown' as the exact type from Zigar couldn't be verified.
// Replace 'unknown' if Zigar's .d.ts provides a more specific type.

/** Opaque handle representing the initialized Zig engine instance. */
export type EngineHandle = unknown;

/** Opaque handle representing a single stream instance within Zig. */
export type StreamHandle = unknown;

/** Opaque pointer object for C strings returned from Zig. */
export type ZigarStringPointer = unknown;

// --- Shared Enums (Mirroring Zig) ---

// LogLevel is imported where needed, assuming definition in core/logger.ts

export enum StreamStatusCode {
    Initializing = 0,
    Buffering = 1,
    Playing = 2,
    Paused = 3,
    Seeking = 4, // If implemented
    Ended = 5,   // Finished successfully
    Stopped = 6, // Explicitly stopped
    Error = 7,
}

// --- Shared Error Types (Conceptual - Optional) ---
// You might use these or rely on error messages in status callbacks

export enum EngineError {
    InitializationFailed = 1,
    ShutdownFailed = 2,
    ResourceAllocationFailed = 3,
}

export enum StreamError {
    StreamNotFound = 10,
    InvalidSourceUrl = 11,
    DecodingError = 12,
    EncodingError = 13,
    ResourceError = 14,
    OperationNotAllowed = 15,
    UnknownError = 99,
}