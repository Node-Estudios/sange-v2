This section defines the logical functions that the TypeScript Middle Layer must implement and provide to the Zig Engine (likely via the `callbacks` parameter in `create_stream`). Zig will call these functions asynchronously during stream processing.
### Purpose of the Callback API

The Zig Engine operates asynchronously. Once the TypeScript Middle Layer initiates an operation like `play_stream`, the Zig engine performs complex, time-based tasks in the background (reading data, decoding, encoding, packetizing).

his callback interface is essential for the following reasons:

1. **Asynchronous Data & Event Handling:** Results (like RTP packets), significant events (stream end, errors), and **log messages** are generated _within_ the Zig engine during its background processing. Callbacks allow Zig to communicate this information back to TypeScript _as it happens_.
2. **Bridging the Language Gap:** TypeScript needs to act on this information (sending packets, updating state, **displaying logs**). Callbacks provide the bridge for Zig to deliver data/events/logs across the language boundary to the TypeScript code that _can_ act on them.
3. **Efficiency (Push vs. Poll):** Callbacks allow Zig to efficiently "push" information (packets, status, logs) to TypeScript immediately when available, avoiding inefficient polling.
4. **Decoupling:** This interface decouples Zig (processing) from TypeScript (network I/O, state management, **log display**).

In essence, the callbacks allow the asynchronous, high-performance Zig engine to feed the necessary real-time information back to the TypeScript environment where it can be appropriately handled.

---

-**Global Callbacks (Likely passed via `EngineCallbacks` during `initialize_engine`)**

- **`on_log(log_level: LogLevel, message: []const u8)`**
    - **Description:** Called by Zig whenever it needs to log a message.
    - **Parameters (provided by Zig):**
        - `log_level`: An enum indicating the severity (`Debug`, `Info`, `Warn`, `Error`).
        - `message`: The raw bytes (`[]const u8`) of the formatted log message.
    - **TS Implementation Responsibility:** Decode the message bytes into a string and display it using the appropriate `console` method (`console.debug`, `console.info`, etc.) in the Node.js environment.

**Per-Stream Callbacks (Likely passed via `StreamCallbacks` during `create_stream`)**

- **`on_rtp_packet(stream_id: u64, packet_data: []const u8, sequence: u16, timestamp: u32, is_silence: bool)`**
    
    - _(Definition unchanged)_
    - **TS Implementation Responsibility:** Forward the `packet_data` to the correct Discord voice UDP connection.
- **`on_stream_status(stream_id: u64, status_code: StreamStatusCode, details: ?string)`**
    
    - _(Definition unchanged)_
    - **TS Implementation Responsibility:** Update the internal state of the stream; potentially trigger cleanup or notify the TS High Level Layer.

---