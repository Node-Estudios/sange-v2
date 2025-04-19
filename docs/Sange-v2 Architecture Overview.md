This document outlines the logical architecture for the `sange-v2` audio player library. It consists of three distinct layers:

---
1. **Zig Engine (Low Level):**
    
    - Written in Zig.
    - Responsible for all heavy audio processing: fetching/decoding using FFmpeg, encoding to Opus, and packetizing into RTP.
    - Manages multiple concurrent audio streams internally, including resource allocation and state.
    - Provides a control API to the TS Middle Layer.
    - Sends processed RTP packets and status updates back to the TS Middle Layer via callbacks.
    - **Goal:** Maximum performance and efficiency for audio processing.
2. **TypeScript Middle Layer (Internal Orchestration):**
    
    - Written in TypeScript, likely using classes (`EngineManager`, `Stream`).
    - The **only** layer that directly communicates with the Zig Engine (via Zigar).
    - Calls Zig functions to control streams (create, play, pause, stop, destroy).
    - Implements and provides callback functions to Zig for receiving RTP packets and status updates.
    - Receives RTP packets and forwards them to the appropriate Discord voice connection UDP socket.
    - Manages the TypeScript-side state corresponding to Zig streams.
    - Provides an internal API for the TS High Level Layer.
    - **Goal:** Bridge Zig and TypeScript, manage Zig interaction, handle network sending, synchronize state.
3. **TypeScript High Level (Public API):**
    
    - Written in TypeScript.
    - The public-facing interface for users of the `sange-v` library.
    - Provides simple, user-friendly methods (e.g., `player.play()`, `player.queue()`, `player.volume()`).
    - Manages higher-level concepts like playlists/queues, guild-specific settings, etc.
    - Translates public API calls into calls to the TS Middle Layer.
    - **Does not interact directly with Zig.**
    - **Goal:** Provide a clean, easy-to-use API for bot developers.