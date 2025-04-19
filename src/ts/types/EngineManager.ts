// src/ts/middle-layer/types/EngineManager.ts

// Import shared types needed
import type { ZigarStringPointer } from './common.js';
// Adjust path to your logger file if needed
import { LogLevel } from '../utils/logging.js'; // Adjust path if needed

// Interface for callbacks passed during Engine initialization
export interface EngineCallbacks {
    /**
     * Function called by Zig to log messages.
     * @param level The severity level.
     * @param messageBytesPtr Opaque pointer object (unknown) to the C string message. Use decodeZigarCString utility.
     */
    on_log_fn: (level: LogLevel, messageBytesPtr: ZigarStringPointer) => void;
}

// Add other EngineManager-specific types here if needed in the future.