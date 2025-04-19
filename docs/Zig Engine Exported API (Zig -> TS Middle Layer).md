This section defines the logical functions that the Zig Engine must export for the TypeScript Middle Layer to call.

---
### Engine Lifecycle

- **`initialize_engine()`**
    
    - **Description:** Initializes the global Zig engine environment. Must be called once before any other engine operations.
    - **Parameters:** None (or potentially an allocator if managed externally).
    - **Returns:** `Result<EngineHandle, EngineError>`
        - `EngineHandle`: An opaque handle representing the initialized engine instance.
        - `EngineError`: Indicates failure during initialization.
- **`shutdown_engine(engine_handle: EngineHandle)`**
    
    - **Description:** Shuts down the Zig engine and releases all global resources. Should be called once when the application/library is closing.
    - **Parameters:**
        - `engine_handle`: The handle obtained from `initialize_engine`.
    - **Returns:** `Result<void, EngineError>`
---
### Stream Management

- **`create_stream(engine_handle: EngineHandle, stream_id: u64, source_url: string, callbacks: StreamCallbacks)`**
    
    - **Description:** Requests the Zig engine to prepare a new audio stream for processing.
    - **Parameters:**
        - `engine_handle`: The global engine handle.
        - `stream_id`: A unique identifier provided by the TS Middle Layer to identify this stream in subsequent callbacks.
        - `source_url`: The URL or identifier of the audio source to be processed.
        - `callbacks`: A structure/object containing references to the TypeScript callback functions (`on_rtp_packet`, `on_stream_status`) that Zig should use for this stream. (Zigar must facilitate passing these function references).
    - **Returns:** `Result<StreamHandle, StreamError>`
        - `StreamHandle`: An opaque handle representing this specific stream instance within Zig. Used for subsequent control calls.
        - `StreamError`: Indicates failure during stream creation (e.g., invalid source, resource allocation failure).
- **`destroy_stream(stream_handle: StreamHandle)`**
    
    - **Description:** Tells the Zig engine to stop processing and clean up all resources associated with a specific stream. Should be called when the stream ends, errors out, or is explicitly stopped.
    - **Parameters:**
        - `stream_handle`: The handle for the specific stream to destroy.
    - **Returns:** `Result<void, StreamError>`
---
### Stream Control

- **`play_stream(stream_handle: StreamHandle)`**
    
    - **Description:** Starts or resumes the audio processing and packet generation for the stream. Zig will begin calling the `on_rtp_packet` callback.
    - **Parameters:**
        - `stream_handle`: The handle of the stream to play.
    - **Returns:** `Result<void, StreamError>`
- **`pause_stream(stream_handle: StreamHandle)`**
    
    - **Description:** Pauses the audio processing. Zig should stop calling the `on_rtp_packet` callback but retain the stream's state.
    - **Parameters:**
        - `stream_handle`: The handle of the stream to pause.
    - **Returns:** `Result<void, StreamError>`
- **`stop_stream(stream_handle: StreamHandle)`**
    
    - **Description:** Requests a graceful stop of the stream. Zig should finish any current processing, potentially send an `on_stream_status` update (e.g., `Stopped`), and prepare for cleanup. This might implicitly lead to the stream needing to be destroyed.
    - **Parameters:**
        - `stream_handle`: The handle of the stream to stop.
    - **Returns:** `Result<void, StreamError>`
- **`set_stream_volume(stream_handle: StreamHandle, volume: f32)`**
    
    - **Description:** Adjusts the playback volume for the stream. The volume level might be applied during decoding or before Opus encoding.
    - **Parameters:**
        - `stream_handle`: The handle of the stream.
        - `volume`: The desired volume level (e.g., `0.0` to `1.0`).
    - **Returns:** `Result<void, StreamError>`