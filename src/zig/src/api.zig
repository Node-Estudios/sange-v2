const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");
// Assuming av.zig is importable and WILL BE CORRECTED
const av = @import("av");

// --- Engine Lifecycle ---

pub export fn initializeEngine(callbacks: types.EngineCallbacks) ?types.EngineHandle {
    // Consider using a more specific allocator if needed, e.g., GeneralPurposeAllocator
    const allocator = std.heap.page_allocator;

    // FFmpeg network init is often needed *before* opening network streams.
    // Calling it here is reasonable, but ensure it's okay to call multiple times
    // or handle initialization state elsewhere if necessary.
    // Check FFmpeg documentation for avformat_network_init behavior.
    // If avformat_network_init returns an error code, handle it:
    // if (av.avformat_network_init() != 0) {
    //     std.log.err("Failed to initialize FFmpeg network.", .{});
    //     return null;
    // }
    // Assuming it's safe to call or doesn't return errors critical here.
    // You might need to link against libraries providing these symbols if using static FFmpeg.
    // _ = av.avformat_network_init(); // Call if needed and available in bindings
    std.log.info("FFmpeg network initialization (if needed) should be handled.", .{});

    // Call the renamed internal function
    return engine.initializeGlobalEngine(allocator, callbacks) catch |err| {
        std.log.err("Failed to initialize global engine: {s}", .{@errorName(err)});
        // If network was initialized, consider deinitializing on failure
        // _ = av.avformat_network_deinit(); // Call if needed and available
        return null;
    };
}

pub export fn shutdownEngine(handle: types.EngineHandle) void {
    // Call the renamed internal function
    engine.shutdownGlobalEngine(handle);
    // Deinitialize network capabilities if they were initialized
    // _ = av.avformat_network_deinit(); // Call if needed and available in bindings
    std.log.info("Engine shutdown complete. FFmpeg network deinitialization (if needed) should be handled.", .{});
}

// --- Stream Management ---

pub export fn createStream(
    engine_handle: types.EngineHandle,
    stream_id: u64,
    source_url_c: [*c]const u8,
    callbacks: types.StreamCallbacks,
) ?types.StreamHandle {
    const eng = engine.getGlobalEngine(engine_handle) catch |err| {
        // Avoid logging within getGlobalEngine AND here. Log once.
        std.log.err("createStream failed: Invalid engine handle. Error: {s}", .{@errorName(err)});
        return null;
    };

    // Convert C string to Zig slice for StreamState.init
    const source_url_slice = std.mem.sliceTo(source_url_c, 0);

    // Initialize StreamState first
    const stream = types.StreamState.init(stream_id, eng.allocator, &eng.callbacks, callbacks, source_url_slice) catch |err| {
        // Use engine's logger if available, otherwise std.log
        eng.log(.Error, "Failed to init StreamState for id {d}: {s}", .{ stream_id, @errorName(err) });
        return null;
    };
    // If init succeeds, we must eventually call deinit or addStream (which handles deinit on failure)

    stream.log(.Info, "[{d}] StreamState initialized.", .{stream_id});

    // --- Basic FFmpeg Init ---
    // Use the stream's allocator for potential Ffmpeg related allocations if applicable
    // var format_ctx: ?*av.AVFormatContext = null; // Use the correct type from bindings
    var format_ctx: ?*av.FormatContext = null; // Matching type in StreamState
    const format_ctx_ptr: *?*av.FormatContext = &format_ctx;

    // Ensure `av.avformat_open_input` exists and is correct in your fixed bindings
    const ret = av.avformat_open_input(format_ctx_ptr, source_url_c, null, null);

    if (ret < 0 or format_ctx == null) {
        var err_buf: [av.AV_ERROR_MAX_STRING_SIZE]u8 = undefined; // Use FFmpeg constant if available
        _ = av.av_strerror(ret, &err_buf, err_buf.len); // Ensure av_strerror is available
        const err_slice = std.mem.sliceTo(&err_buf, 0); // Get slice of the error string

        // Use stream's logger
        stream.log(.Error, "[{d}] Failed to open input URL '{s}': FFmpeg error {d} ({s})", .{ stream_id, source_url_slice, ret, err_slice });
        stream.deinit(); // Clean up the partially initialized stream state
        return null;
    }
    stream.av_format_ctx = format_ctx; // Assign the successfully opened context
    stream.log(.Info, "[{d}] Successfully opened input URL '{s}' with FFmpeg.", .{ stream_id, source_url_slice });
    // ----------------------

    // Add the fully initialized stream (including FFmpeg context) to the engine
    eng.addStream(stream) catch |err| {
        stream.log(.Error, "[{d}] Failed to add stream to engine map: {s}", .{ stream_id, @errorName(err) });
        // If adding fails, we need to deinitialize the stream state (which closes the ffmpeg context)
        stream.deinit();
        return null;
    };

    // Return the handle which points to the StreamState instance
    return stream.handle;
}

pub export fn destroyStream(engine_handle: types.EngineHandle, stream_handle: types.StreamHandle) bool {
    const eng = engine.getGlobalEngine(engine_handle) catch {
        std.log.err("destroyStream failed: Invalid engine handle.", .{});
        return false;
    };

    // removeStream logs internally if handle is not found
    if (eng.removeStream(stream_handle)) |stream_ptr| {
        // If stream was successfully removed from map, deinitialize it
        stream_ptr.log(.Info, "[{d}] Destroy command received. Deinitializing stream state.", .{stream_ptr.id});
        stream_ptr.deinit();
        return true;
    } else {
        // Handle was not found in the map (already destroyed or never existed)
        // eng.log(.Warn, "destroyStream called with invalid or already destroyed handle.", .{}); // Already logged by removeStream
        return false;
    }
}

// --- Stream Control (Basic Implementation) ---

pub export fn playStream(engine_handle: types.EngineHandle, stream_handle: types.StreamHandle) bool {
    const eng = engine.getGlobalEngine(engine_handle) catch return false;
    eng.mutex.lock(); // Lock for potential status update
    defer eng.mutex.unlock();

    if (eng.getStream(stream_handle)) |stream| {
        // Check current status before allowing play
        switch (stream.status) {
            .Paused, .Stopped, .Initializing, .Ended, .Error => { // Allow play from these states
                stream.log(.Info, "[{d}] Play command received.", .{stream.id});
                stream.updateStatus(.Playing, null); // Update status first
                // TODO: Start actual playback thread/task here
                // Signal or start the component responsible for reading/decoding/playing
                return true;
            },
            .Playing, .Buffering, .Seeking => { // Already playing or in transient state
                stream.log(.Warn, "[{d}] Play command ignored, stream status is {s}", .{ stream.id, @tagName(stream.status) });
                return false;
            },
        }
    } else {
        eng.log(.Warn, "playStream called with invalid stream handle.", .{});
        return false;
    }
}

pub export fn pauseStream(engine_handle: types.EngineHandle, stream_handle: types.StreamHandle) bool {
    const eng = engine.getGlobalEngine(engine_handle) catch return false;
    eng.mutex.lock();
    defer eng.mutex.unlock();

    if (eng.getStream(stream_handle)) |stream| {
        // Can only pause if playing or buffering
        switch (stream.status) {
            .Playing, .Buffering => {
                stream.log(.Info, "[{d}] Pause command received.", .{stream.id});
                stream.updateStatus(.Paused, null);
                // TODO: Signal playback thread/task to pause
                return true;
            },
            else => {
                stream.log(.Warn, "[{d}] Pause command ignored, stream status is {s}", .{ stream.id, @tagName(stream.status) });
                return false;
            },
        }
    } else {
        eng.log(.Warn, "pauseStream called with invalid stream handle.", .{});
        return false;
    }
}

pub export fn stopStream(engine_handle: types.EngineHandle, stream_handle: types.StreamHandle) bool {
    const eng = engine.getGlobalEngine(engine_handle) catch return false;
    eng.mutex.lock();
    defer eng.mutex.unlock();

    if (eng.getStream(stream_handle)) |stream| {
        // Can stop from most states, except maybe already stopped/error/ended?
        // Depends on desired behavior. Stopping usually means reset.
        switch (stream.status) {
            .Stopped, .Ended, .Error => { // Already stopped or terminal state
                stream.log(.Warn, "[{d}] Stop command ignored, stream status is already {s}", .{ stream.id, @tagName(stream.status) });
                return false;
            },
            else => {
                stream.log(.Info, "[{d}] Stop command received.", .{stream.id});
                stream.updateStatus(.Stopped, null);
                // TODO: Signal playback thread/task to stop *and potentially reset* state (e.g., seek to beginning).
                // Stopping might involve more than just pausing, like closing/reopening parts of ffmpeg pipeline?
                return true;
            },
        }
    } else {
        eng.log(.Warn, "stopStream called with invalid stream handle.", .{});
        return false;
    }
}

pub export fn setStreamVolume(engine_handle: types.EngineHandle, stream_handle: types.StreamHandle, volume: f32) bool {
    const eng = engine.getGlobalEngine(engine_handle) catch return false;
    // Lock might not be strictly necessary if volume is atomic or only read elsewhere,
    // but safer if multiple threads could call this or interact with volume.
    eng.mutex.lock();
    defer eng.mutex.unlock();

    if (eng.getStream(stream_handle)) |stream| {
        const clamped_volume = std.math.clamp(volume, 0.0, 1.0);
        stream.log(.Info, "[{d}] Set volume command received: {d:.2}", .{ stream.id, clamped_volume });
        stream.volume = clamped_volume;
        // TODO: Apply volume during audio processing/mixing stage.
        // This might involve passing the value to an audio callback or mixer component.
        return true;
    } else {
        eng.log(.Warn, "setStreamVolume called with invalid stream handle.", .{});
        return false;
    }
}

// Simple ping function for testing C interop (returning C string literal)
pub export fn ping() [*c]const u8 {
    // String literals in Zig are null-terminated.
    return "pong";
}
