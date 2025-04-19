const std = @import("std");
const av = @import("av"); // Assuming av.zig is importable and WILL BE CORRECTED

// --- Enums, Errors, Handles ---
pub const LogLevel = enum(u8) { Debug, Info, Warn, Error };
pub const StreamStatusCode = enum(u8) { Initializing = 0, Buffering = 1, Playing = 2, Paused = 3, Seeking = 4, Ended = 5, Stopped = 6, Error = 7 };
pub const EngineError = error{ InitializationFailed, ShutdownFailed, OutOfMemory, InvalidEngineHandle };
pub const StreamError = error{ StreamNotFound, InvalidSourceUrl, ResourceAllocationFailed, OperationNotAllowed, FfmpegOpenFailed, FfmpegCloseFailed, CallbackError };
pub const EngineHandle = *anyopaque;
pub const StreamHandle = *anyopaque;

// --- Callback Function Pointer Types ---
// Function pointers themselves are non-null by default
pub const TsCallback_on_log = *const fn (level: LogLevel, message: [*c]const u8) callconv(.C) void;
pub const TsCallback_on_rtp_packet = *const fn (stream_id: u64, packet_data: [*]const u8, packet_len: usize, sequence: u16, timestamp: u32, is_silence: bool) callconv(.C) void;
// Use nullable pointer [*c]const u8 for details, compatible with C ABI
pub const TsCallback_on_stream_status = *const fn (stream_id: u64, status_code: StreamStatusCode, details: [*c]const u8) callconv(.C) void;

// --- Callback Structs ---
// These structs hold the non-null function pointers
pub const EngineCallbacks = extern struct {
    on_log_fn: TsCallback_on_log,
};
pub const StreamCallbacks = extern struct {
    on_rtp_packet_fn: TsCallback_on_rtp_packet,
    on_stream_status_fn: TsCallback_on_stream_status,
};

// --- Stream State ---
pub const StreamState = struct {
    id: u64,
    handle: StreamHandle,
    status: StreamStatusCode,
    allocator: std.mem.Allocator,
    engine_callbacks: *const EngineCallbacks, // Pointer to global callbacks
    stream_callbacks: StreamCallbacks, // Own struct for stream-specific callbacks
    url: []u8,
    volume: f32 = 1.0,

    // Ensure this type name matches the one in your (corrected) av.zig
    av_format_ctx: ?*av.FormatContext = null,

    const Self = @This();

    pub fn init(
        id: u64,
        allocator: std.mem.Allocator,
        engine_cbs: *const EngineCallbacks, // Pass pointer to global callbacks
        stream_cbs: StreamCallbacks, // Pass stream-specific callbacks
        source_url: []const u8,
    ) !*Self {
        // Validate callbacks before allocating
        // Note: Zig pointers are non-null by default, explicit check might be redundant
        // if types enforce non-null, but kept for clarity if types were different.
        if (engine_cbs == null or engine_cbs.on_log_fn == null or
            stream_cbs.on_rtp_packet_fn == null or stream_cbs.on_stream_status_fn == null)
        {
            std.log.err("StreamState init failed: Invalid callbacks provided.", .{});
            return error.CallbackError; // Or a more specific error
        }

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const handle_ptr = @as(StreamHandle, @ptrCast(self));

        // Dupe the URL early, so it's cleaned up by errdefer if later steps fail
        const url_copy = try allocator.dupe(u8, source_url);
        errdefer allocator.free(url_copy);

        self.* = .{
            .id = id,
            .handle = handle_ptr,
            .status = .Initializing,
            .allocator = allocator,
            .engine_callbacks = engine_cbs, // Store pointer
            .stream_callbacks = stream_cbs, // Store struct
            .url = url_copy, // Assign the successfully duplicated URL
            .volume = 1.0,
            .av_format_ctx = null,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        // *** CORRECTED FFmpeg Context Closing ***
        // Check if the context exists before trying to close it.
        if (self.av_format_ctx != null) {
            // Pass the address of the optional pointer field directly.
            // avformat_close_input expects *?*av.FormatContext, and &self.av_format_ctx has this type.
            // Ensure 'av.avformat_close_input' exists and is correct in your fixed bindings.
            av.avformat_close_input(&self.av_format_ctx);
            // After the call, self.av_format_ctx should be null if the close was successful internally.
            self.log(.Debug, "[{d}] FFmpeg context closed.", .{self.id});
        }
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    pub fn log(self: *const Self, comptime level: LogLevel, comptime format: []const u8, args: anytype) void {
        // Now log using the callback function pointer within the struct
        // try_log_fmt allocates memory that needs to be managed (see function below)
        const msg = try_log_fmt(self.allocator, format, args) orelse {
            // Log allocation/format failure via std.log if possible, or handle error
            std.log.err("Stream [{d}] log: Failed to allocate or format log message.", .{self.id});
            // Optionally call the C callback with a static error string
            // self.engine_callbacks.on_log_fn(level, "[Zig log format error]");
            return;
        };
        // Assuming init validated on_log_fn is not null
        self.engine_callbacks.on_log_fn(level, msg);
        // *** MEMORY LEAK WARNING is still relevant here for 'msg' ***
        // The C side needs a way to signal when it's done with 'msg' so Zig can free it.
    }

    pub fn updateStatus(self: *Self, new_status: StreamStatusCode, details: ?[]const u8) void {
        if (self.status == new_status) return;
        self.status = new_status;

        var details_c: [*c]const u8 = null;
        // Convert Zig slice to C string pointer (nul-terminated)
        if (details) |d| {
            // This assumes 'd' is already null-terminated or the C side handles length.
            // If not, allocation + null termination is needed here.
            details_c = @as([*c]const u8, @ptrCast(d.ptr)); // Be careful with lifetime and termination
        }

        // Assuming init validated on_stream_status_fn is not null
        self.stream_callbacks.on_stream_status_fn(self.id, new_status, details_c);

        self.log(.Debug, "[{d}] Status changed to {s}", .{ self.id, @tagName(new_status) });
    }
};

// --- try_log_fmt Helper ---
// *** CORRECTED: Added 'pub' ***
pub fn try_log_fmt(allocator: std.mem.Allocator, comptime format: []const u8, args: anytype) ?[*c]const u8 {
    // Allocate and print, capturing errors
    const result_slice = std.fmt.allocPrintZ(allocator, format, args) catch |err| {
        std.log.err("Failed to format log message (allocPrintZ): {s}", .{@errorName(err)});
        return null; // Return null on error
    };

    // result_slice is already null-terminated ([]const u8)
    // The caller is responsible for freeing result_slice using the allocator.

    // Cast the pointer for the C interface.
    // Note: result_slice.ptr is already a [*]const u8, casting to [*c]const u8 is okay.
    return @as([*c]const u8, @ptrCast(result_slice.ptr));
}
