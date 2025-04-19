// src/ts/middle-layer/EngineManager.ts
import { tsLogger, zigLogger, LogLevel } from '../utils/logging.js'; // Adjust path if needed
import { decodeZigarCString } from '../utils/zigar.js'; // Adjust path if needed
import { Stream } from './stream.js';
// Import types from type files
import { EngineHandle, StreamHandle, StreamStatusCode, ZigarStringPointer } from '../types/common.js';
import type { EngineCallbacks } from '../types/EngineManager.js';
import type { StreamCallbacks } from '../types/stream.js';
// Import Zig bindings
import * as zigEngine from '@zig/engine'; // Assuming path mapping is correct

export class EngineManager {
    private static instance: EngineManager | null = null;
    private engineHandle: EngineHandle | null = null;
    private streams = new Map<number, Stream>();
    private isInitialized = false;
    private nextStreamId = 1;

    private constructor() { }

    public static getInstance(): EngineManager {
        if (!EngineManager.instance) {
            EngineManager.instance = new EngineManager();
        }
        return EngineManager.instance;
    }

    // --- Callback Handlers (Passed to Zig) ---
    private _handleLog(level: LogLevel, messagePtr: ZigarStringPointer): void {
        const message = decodeZigarCString(messagePtr);
        if (message === null) {
             zigLogger.error("Failed to decode log message pointer from Zig.");
             return;
        }
        switch (level) {
            case LogLevel.Debug: zigLogger.debug(message); break;
            case LogLevel.Info: zigLogger.info(message); break;
            case LogLevel.Warn: zigLogger.warn(message); break;
            case LogLevel.Error: zigLogger.error(message); break;
            default: zigLogger.log(`(Level ${level}) ${message}`);
        }
    }

    private _handleStreamStatus(streamId: number, statusCode: StreamStatusCode, detailsPtr: ZigarStringPointer | null): void {
        const stream = this.streams.get(streamId);
        if (stream) {
            const details = detailsPtr ? decodeZigarCString(detailsPtr) : undefined;
            // Ensure null is converted to undefined for the method signature
            stream._updateStatus(statusCode, details ?? undefined);

            if (statusCode === StreamStatusCode.Ended || statusCode === StreamStatusCode.Error) {
                 tsLogger.info(`Stream [${streamId}] ended or errored with status ${StreamStatusCode[statusCode]}. Triggering destroy.`);
                 // Let destroy handle removal
                 stream.destroy().catch(err => tsLogger.error(`Error during automatic destroy for stream [${streamId}]:`, err));
            }
        } else {
            zigLogger.warn(`Received status update for unknown streamId: ${streamId}`);
        }
    }

    private _handleRtpPacket(streamId: number, packetData: Uint8Array, sequence: number, timestamp: number, isSilence: boolean): void {
        const stream = this.streams.get(streamId);
        if (stream) {
            stream._forwardRtpPacket(packetData);
        } else {
            zigLogger.warn(`Received RTP packet for unknown streamId: ${streamId}`);
        }
    }

    // --- Public Methods ---
    async initialize(): Promise<boolean> {
        if (this.isInitialized) return true;
        tsLogger.info("Attempting to initialize Zig engine...");

        const engineCallbacks: EngineCallbacks = {
            on_log_fn: this._handleLog.bind(this)
        };

        try {
            // FIX: Use camelCase
            const handle: EngineHandle | null = await zigEngine.initializeEngine(engineCallbacks);

            if (!handle) {
                throw new Error("Zig engine initialization failed (returned null handle).");
            }
            this.engineHandle = handle;

            tsLogger.info(`Zig engine initialized successfully.`);
            this.isInitialized = true;
            return true;
        } catch (error) {
            tsLogger.error("Error initializing Zig engine:", error);
            this.isInitialized = false;
            return false;
        }
    }

    async createStream(url: string, sendRtpPacket: (packet: Buffer | Uint8Array) => void): Promise<Stream | null> {
        if (!this.isInitialized || !this.engineHandle) {
            tsLogger.error("Cannot create stream: Engine not initialized.");
            return null;
        }

        const streamId = this.nextStreamId++;

        const streamCallbacks: StreamCallbacks = {
             on_rtp_packet_fn: this._handleRtpPacket.bind(this),
             on_stream_status_fn: this._handleStreamStatus.bind(this)
        };

        try {
            tsLogger.info(`Requesting Zig to create stream [${streamId}] for URL: ${url}`);
            // FIX: Use camelCase
            const streamHandle: StreamHandle | null = await zigEngine.createStream(
                this.engineHandle,
                streamId,
                url,
                streamCallbacks
            );

            if (!streamHandle) {
                 throw new Error(`Zig createStream returned invalid handle for stream [${streamId}].`);
            }

            const stream = new Stream(streamId, this.engineHandle, streamHandle, sendRtpPacket);
            this.streams.set(streamId, stream);
            tsLogger.info(`Stream [${streamId}] created successfully.`);
            return stream;

        } catch (error) {
            tsLogger.error(`Error creating stream [${streamId}] for URL ${url}:`, error);
            return null;
        }
    }

    getStream(streamId: number): Stream | undefined {
        return this.streams.get(streamId);
    }

    removeStream(streamId: number): boolean {
         const deleted = this.streams.delete(streamId);
         if (deleted) {
             tsLogger.debug(`Stream [${streamId}] removed from EngineManager.`);
         }
         return deleted;
    }

    async shutdown(): Promise<void> {
         if (!this.isInitialized || !this.engineHandle) return;
         tsLogger.info("Shutting down Zig engine...");

         const shutdownPromises = Array.from(this.streams.values()).map(stream => {
             return stream.stop().finally(() => stream.destroy());
         });
         await Promise.all(shutdownPromises);
         this.streams.clear();

         try {
              // FIX: Use camelCase
              await zigEngine.shutdownEngine(this.engineHandle);
              tsLogger.info("Zig engine shutdown command sent.");
         } catch(error) {
             tsLogger.error("Error sending shutdown command to Zig:", error);
         } finally {
             this.isInitialized = false;
             this.engineHandle = null;
             EngineManager.instance = null;
         }
    }
}