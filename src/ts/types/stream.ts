// src/ts/middle-layer/types/Stream.ts

// Import shared types needed
import type { ZigarStringPointer } from './common.js';
import { StreamStatusCode } from './common.js';

// Interface for callbacks passed during Stream creation
export interface StreamCallbacks {
    /**
     * Function called by Zig when an RTP packet is ready.
     * @param streamId The ID of the stream this packet belongs to.
     * @param packetData The raw bytes of the RTP packet.
     * @param sequence The RTP sequence number.
     * @param timestamp The RTP timestamp.
     * @param isSilence True if the packet represents silence.
     */
    on_rtp_packet_fn: (
        streamId: number,
        packetData: Uint8Array, // Expect raw bytes
        sequence: number,
        timestamp: number,
        isSilence: boolean
    ) => void;

    /**
     * Function called by Zig when the stream's status changes.
     * @param streamId The ID of the stream whose status changed.
     * @param statusCode The new status code enum value.
     * @param detailsPtr Optional opaque pointer object (unknown) to a C string containing error details. Use decodeZigarCString utility. Can be null.
     */
    on_stream_status_fn: (
        streamId: number,
        statusCode: StreamStatusCode,
        detailsPtr: ZigarStringPointer | null
    ) => void;
}

// Add other Stream-specific types here if needed in the future.