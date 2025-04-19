// src/ts/middle-layer/stream.ts

// Import types first (adjust paths if needed)
import { EngineHandle, StreamHandle, StreamStatusCode } from '../types/common.js';
// Import logger and Zigar bindings (adjust paths if needed)
import { tsLogger } from '../utils/logging.js'; 
import * as zigEngine from '@zig/engine'; 
// Import EngineManager to notify on destroy
import { EngineManager } from './EngineManager.js';

export class Stream {
    // Properties declared
    public readonly id: number;
    private readonly engineHandle: EngineHandle; // Ensure this exists
    private readonly zigHandle: StreamHandle;
    private readonly sendRtpPacket: (packet: Buffer | Uint8Array) => void;
    public currentStatus: StreamStatusCode;

    // Constructor assigns all properties
    constructor(
        id: number,
        engineHandle: EngineHandle, // Receives engineHandle
        zigHandle: StreamHandle,
        sendRtpPacket: (packet: Buffer | Uint8Array) => void
    ) {
        this.id = id;
        this.engineHandle = engineHandle; // Stores engineHandle
        this.zigHandle = zigHandle;
        this.sendRtpPacket = sendRtpPacket;
        this.currentStatus = StreamStatusCode.Initializing;
        tsLogger.debug(`Stream [${this.id}] created in TS.`);
    }

    async play(): Promise<void> {
        if (this.currentStatus >= StreamStatusCode.Ended) return;
        tsLogger.debug(`Stream [${this.id}]: Requesting play...`);
        try {
            // FIX: Pass BOTH engineHandle AND zigHandle
            await zigEngine.playStream(this.engineHandle, this.zigHandle);
            tsLogger.info(`Stream [${this.id}]: Play command sent to Zig.`);
        } catch (error) {
            tsLogger.error(`Stream [${this.id}]: Error sending play command to Zig:`, error);
        }
    }

    async pause(): Promise<void> {
        if (this.currentStatus !== StreamStatusCode.Playing && this.currentStatus !== StreamStatusCode.Buffering) return;
        tsLogger.debug(`Stream [${this.id}]: Requesting pause...`);
        try {
            // FIX: Pass BOTH engineHandle AND zigHandle
            await zigEngine.pauseStream(this.engineHandle, this.zigHandle);
            tsLogger.info(`Stream [${this.id}]: Pause command sent to Zig.`);
        } catch (error) {
            tsLogger.error(`Stream [${this.id}]: Error sending pause command to Zig:`, error);
        }
    }

    async stop(): Promise<void> {
        if (this.currentStatus >= StreamStatusCode.Ended) return;
        tsLogger.debug(`Stream [${this.id}]: Requesting stop...`);
        try {
            // FIX: Pass BOTH engineHandle AND zigHandle
            await zigEngine.stopStream(this.engineHandle, this.zigHandle);
            tsLogger.info(`Stream [${this.id}]: Stop command sent to Zig.`);
        } catch (error) {
            tsLogger.error(`Stream [${this.id}]: Error sending stop command to Zig:`, error);
        }
    }

    // Internal method called by EngineManager callbacks
    _updateStatus(newStatus: StreamStatusCode, details?: string): void {
         tsLogger.debug(`Stream [${this.id}]: Status update received: ${StreamStatusCode[newStatus]} (${newStatus}), Details: ${details || 'N/A'}`);
         if (this.currentStatus >= StreamStatusCode.Ended && newStatus < StreamStatusCode.Ended) {
             tsLogger.warn(`Stream [${this.id}]: Ignoring status update ${StreamStatusCode[newStatus]} because stream is already in terminal state ${StreamStatusCode[this.currentStatus]}.`);
             return;
         }
         this.currentStatus = newStatus;
    }

    // Internal method called by EngineManager callbacks
    _forwardRtpPacket(packetData: Buffer | Uint8Array): void {
        if (this.currentStatus !== StreamStatusCode.Playing) return;
        try {
             this.sendRtpPacket(packetData);
        } catch(error) {
            tsLogger.error(`Stream [${this.id}]: Error forwarding RTP packet:`, error);
        }
    }

    async destroy(): Promise<void> {
        if (!EngineManager.getInstance().getStream(this.id)) {
            tsLogger.debug(`Stream [${this.id}]: Already removed by manager, skipping destroy command.`);
            return;
        }
        tsLogger.debug(`Stream [${this.id}]: Requesting destroy from Stream class...`);
        // Mark as stopped locally to prevent further actions maybe?
        // Consider if a 'Destroying' state is needed
        this.currentStatus = StreamStatusCode.Stopped; 

        try {
            // FIX: Pass BOTH engineHandle AND zigHandle
            await zigEngine.destroyStream(this.engineHandle, this.zigHandle);
            tsLogger.info(`Stream [${this.id}]: Destroy command sent to Zig.`);
        } catch (error) {
            tsLogger.error(`Stream [${this.id}]: Error sending destroy command to Zig:`, error);
        } finally {
            // Ensure removal from manager happens even if destroyStream fails
            EngineManager.getInstance().removeStream(this.id);
        }
    }
}