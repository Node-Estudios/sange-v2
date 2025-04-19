const std = @import("std");
const types = @import("types.zig");

// Global state for the engine
const EngineState = struct {
    allocator: std.mem.Allocator,
    streams: std.AutoHashMap(types.StreamHandle, *types.StreamState),
    mutex: std.Thread.Mutex,
    callbacks: types.EngineCallbacks,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, callbacks: types.EngineCallbacks) !*Self {
        // *** REMOVED THE NULL CHECK FOR on_log_fn ***
        // The type `types.TsCallback_on_log` is non-nullable (*const fn),
        // so the compiler guarantees callbacks.on_log_fn cannot be null here.
        // It's the caller's responsibility (FFI boundary) to provide a valid pointer.

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .streams = std.AutoHashMap(types.StreamHandle, *types.StreamState).init(allocator),
            .mutex = .{},
            .callbacks = callbacks, // Assign the struct directly
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        var iter = self.streams.iterator();
        while (iter.next()) |entry| {
            // Deinit the stream state itself
            entry.value_ptr.*.deinit(); // This frees stream-specific resources
        }
        self.streams.deinit(); // Deinit the hash map structure
        self.allocator.destroy(self); // Free the memory for the EngineState itself
        std.log.info("Engine state deinitialized.", .{});
    }

    pub fn addStream(self: *Self, stream: *types.StreamState) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.streams.put(stream.handle, stream);
        self.log(.Debug, "Stream [{d}] added to engine map.", .{stream.id});
    }

    pub fn getStream(self: *Self, handle: types.StreamHandle) ?*types.StreamState {
        // Locking should be handled by caller if modification occurs after getting pointer
        // std.AutoHashMap get should be thread-safe for reads if no writes occur.
        return self.streams.get(handle);
    }

    pub fn removeStream(self: *Self, handle: types.StreamHandle) ?*types.StreamState {
        self.mutex.lock();
        defer self.mutex.unlock();
        const result = self.streams.fetchRemove(handle);
        if (result) |entry| {
            self.log(.Debug, "Stream [{d}] removed from engine map.", .{entry.value.id});
            return entry.value; // Return the pointer to the removed stream state
        } else {
            self.log(.Warn, "Attempted to remove non-existent stream handle.", .{});
            return null;
        }
    }

    // Helper to log via callback
    pub fn log(self: *const Self, comptime level: types.LogLevel, comptime format: []const u8, args: anytype) void {
        // Use try_log_fmt which handles allocation/formatting errors
        // NOTE: Be aware of memory leak potential from try_log_fmt
        const msg = types.try_log_fmt(self.allocator, format, args) orelse {
            std.log.err("Engine log: Failed to allocate or format log message.", .{});
            // Call C callback with a static error string? Ensure it's handled.
            // self.callbacks.on_log_fn(level, "[Zig log format error]");
            return;
        };

        // Type system guarantees on_log_fn is not null here.
        self.callbacks.on_log_fn(level, msg);
        // TODO: Address potential memory leak of msg. The C side must manage or
        // signal Zig to free the memory pointed to by 'msg'.
    }
};

// --- Global Engine State ---
var g_engine_state: ?*EngineState = null;
var g_allocator: std.mem.Allocator = std.heap.page_allocator;

pub fn initializeGlobalEngine(allocator: std.mem.Allocator, callbacks: types.EngineCallbacks) !types.EngineHandle {
    if (g_engine_state != null) {
        std.log.warn("Global engine already initialized.", .{});
        return @as(types.EngineHandle, g_engine_state.?);
    }

    g_allocator = allocator;
    // EngineState.init now implicitly relies on caller providing valid callbacks
    g_engine_state = try EngineState.init(allocator, callbacks);
    g_engine_state.?.log(.Info, "Global Zig Engine Initialized.", .{});
    return @as(types.EngineHandle, g_engine_state.?);
}

pub fn shutdownGlobalEngine(handle: types.EngineHandle) void {
    if (g_engine_state == null or @intFromPtr(handle) != @intFromPtr(g_engine_state.?)) {
        std.log.err("Attempt to shut down uninitialized or incorrect engine instance.", .{});
        return;
    }
    const state_to_deinit = g_engine_state.?;
    g_engine_state = null;
    state_to_deinit.log(.Info, "Shutting down global Zig Engine...", .{});
    state_to_deinit.deinit();
}

pub fn getGlobalEngine(handle: types.EngineHandle) !*EngineState {
    if (g_engine_state == null or @intFromPtr(handle) != @intFromPtr(g_engine_state.?)) {
        std.log.err("Invalid engine handle provided.", .{});
        return error.InvalidEngineHandle;
    }
    return g_engine_state.?;
}
