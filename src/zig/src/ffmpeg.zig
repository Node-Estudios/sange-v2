// src/zig/ffmpeg.zig
const av = @import("av"); // Asumiendo que av.zig está disponible

// --- Estructuras de Contexto y Resultado ---

pub const InputContext = extern struct {
    // Corregido: Hacer fmt_ctx opcional
    fmt_ctx: ?*av.FormatContext = null,
    stream_index: c_int,
    stream: ?*av.Stream = null, // Hacer opcional también por seguridad inicial
    codec_ctx: ?*av.Codec.Context = null,
    codec: ?*const av.Codec = null,
    codec_name: ?[*:0]const u8 = null,
    width: c_int = 0,
    height: c_int = 0,
    duration_seconds: f64 = 0,

    const Self = @This();

    fn destroy(self: *Self) void {
        if (self.codec_ctx) |ctx| {
            av.Codec.Context.free(ctx);
            self.codec_ctx = null;
            self.codec = null;
        }

        if (self.codec_name) |name_ptr| {
            av.free(@as(?*anyopaque, @ptrCast(@constCast(name_ptr))));
            self.codec_name = null;
        }

        // Ahora la comprobación es válida porque fmt_ctx es opcional
        if (self.fmt_ctx) |ctx| {
            av.FormatContext.free(ctx);
            self.fmt_ctx = null;
        }
        av.free(self);
    }
};

// Corregido: Añadir 'extern' para compatibilidad ABI C
pub const OpenResult = extern struct {
    ctx: ?*InputContext = null,
    err_msg: ?[*:0]const u8 = null,
};

// Corregido: Añadir 'extern'
pub const VideoInfoResult = extern struct {
    info: ?*VideoInfo = null,
    err_msg: ?[*:0]const u8 = null,
};

// VideoInfo ya era extern struct, está bien
pub const VideoInfo = extern struct {
    codecName: ?[*:0]const u8 = null,
    width: i32,
    height: i32,
    durationSeconds: f64,
};

// Corregido: Añadir 'extern'
pub const TranscodeResult = extern struct {
    success: bool,
    message: ?[*:0]const u8 = null,
};

// --- Variables Globales y Funciones Auxiliares ---

var ffmpeg_initialized: bool = false;

fn ensureFFmpegInit() void {
    if (!ffmpeg_initialized) {
        av.LOG.set_level(.FATAL);
        ffmpeg_initialized = true;
    }
}

fn cStrLen(ptr: [*c]const u8) usize {
    var len: usize = 0;
    while (ptr[len] != 0) : (len += 1) {}
    return len;
}

fn createErrorString(comptime prefix: []const u8, err_param: anytype) ?[*:0]const u8 {
    const error_name = @errorName(err_param);
    const len = prefix.len + error_name.len + 2;

    const buf_ptr = av.malloc(len) catch {
        return "Failed to allocate memory for error message".ptr;
    };
    if (buf_ptr == null) {
        return "Failed to allocate memory for error message".ptr;
    }

    const buffer: [*]u8 = @as([*]u8, @ptrCast(buf_ptr));
    @memcpy(buffer[0..prefix.len], prefix);
    buffer[prefix.len] = ':';
    buffer[prefix.len + 1] = ' ';
    @memcpy(buffer[prefix.len + 2 .. prefix.len + 2 + error_name.len], error_name);
    buffer[len - 1] = 0;

    return @as([*:0]const u8, @ptrCast(buffer));
}

fn createFFmpegErrorString(comptime prefix: []const u8, c_error_code: c_int) ?[*:0]const u8 {
    var errbuf: [av.ERROR.str_error_buf_size]u8 = undefined;
    _ = av.strerror(c_error_code, &errbuf);

    const err_len = cStrLen(errbuf[0..].ptr);

    const total_len = prefix.len + 2 + err_len + 1;

    const buf_ptr = av.malloc(total_len) catch {
        return "Failed to allocate memory for FFmpeg error message".ptr;
    };
    if (buf_ptr == null) {
        return "Failed to allocate memory for FFmpeg error message".ptr;
    }
    const buffer: [*]u8 = @as([*]u8, @ptrCast(buf_ptr));

    @memcpy(buffer[0..prefix.len], prefix);
    buffer[prefix.len] = ':';
    buffer[prefix.len + 1] = ' ';
    @memcpy(buffer[prefix.len + 2 .. prefix.len + 2 + err_len], errbuf[0..err_len]);
    buffer[total_len - 1] = 0;

    return @as([*:0]const u8, @ptrCast(buffer));
}

// --- Funciones Exportadas ---

pub export fn freeString(ptr: ?[*:0]const u8) void {
    if (ptr) |p| {
        av.free(@as(?*anyopaque, @ptrCast(@constCast(p))));
    }
}

pub export fn openInput(file_path_zig: [*:0]const u8) OpenResult {
    ensureFFmpegInit();

    const input_ctx_ptr_any = av.malloc(@sizeOf(InputContext)) catch |err| {
        return .{ .ctx = null, .err_msg = createErrorString("Failed to allocate InputContext wrapper", err) };
    };
    if (input_ctx_ptr_any == null) {
        return .{ .ctx = null, .err_msg = "av.malloc returned null for InputContext".ptr };
    }
    var input_ctx: *InputContext = @as(*InputContext, @ptrCast(input_ctx_ptr_any));

    // Inicializar valores opcionales a null explícitamente
    input_ctx.* = .{
        .fmt_ctx = null, // Inicializar a null
        .stream_index = -1,
        .stream = null, // Inicializar a null
        .codec_ctx = null,
        .codec = null,
        .codec_name = null,
        .width = 0,
        .height = 0,
        .duration_seconds = 0.0,
    };

    // Asignar fmt_ctx después de abrir
    input_ctx.fmt_ctx = av.FormatContext.open_input(file_path_zig, null, null, null) catch |err| {
        av.free(input_ctx);
        return .{ .ctx = null, .err_msg = createErrorString("FormatContext.open_input", err) };
    };

    // find_stream_info puede fallar, no es crítico
    input_ctx.fmt_ctx.?.find_stream_info(null) catch {}; // Ignorar error

    var best_stream_index: c_int = -1;
    var best_codec: ?*const av.Codec = null;
    var stream_found = false;

    const video_result = input_ctx.fmt_ctx.?.find_best_stream(.VIDEO, -1, -1);
    if (video_result) |res| {
        best_stream_index = @intCast(res[0]);
        best_codec = res[1];
        stream_found = true;
    } else |err_video| {
        const audio_result = input_ctx.fmt_ctx.?.find_best_stream(.AUDIO, -1, -1);
        if (audio_result) |res| {
            best_stream_index = @intCast(res[0]);
            best_codec = res[1];
            stream_found = true;
        } else |err_audio| {
            input_ctx.destroy();
            return .{ .ctx = null, .err_msg = createErrorString("No video or audio stream found", err_audio) };
        }
        _ = err_video;
    }

    if (!stream_found or best_stream_index < 0) {
        input_ctx.destroy();
        return .{ .ctx = null, .err_msg = "Could not find suitable stream".ptr };
    }

    input_ctx.stream_index = best_stream_index;
    input_ctx.codec = best_codec;

    // Asignar stream (check de índice contra nb_streams)
    if (@as(u32, @intCast(input_ctx.stream_index)) < input_ctx.fmt_ctx.?.nb_streams) {
        input_ctx.stream = input_ctx.fmt_ctx.?.streams[input_ctx.stream_index];
    } else {
        input_ctx.destroy();
        const msg = "Invalid stream index obtained";
        const buf = av.malloc(msg.len + 1) catch {
            return .{ .ctx = null, .err_msg = "Allocation failed for error msg".ptr };
        };
        if (buf == null) return .{ .ctx = null, .err_msg = "Allocation failed for error msg".ptr };
        @memcpy(@as([*]u8, @ptrCast(buf))[0..msg.len], msg);
        @as([*]u8, @ptrCast(buf))[msg.len] = 0;
        return .{ .ctx = null, .err_msg = @as([*:0]const u8, @ptrCast(buf)) };
    }

    // Verificar que el stream asignado no sea null
    if (input_ctx.stream == null) {
        input_ctx.destroy();
        return .{ .ctx = null, .err_msg = "Assigned stream is null".ptr };
    }

    return .{ .ctx = input_ctx, .err_msg = null };
}

pub export fn closeInput(ctx: ?*InputContext) void {
    if (ctx) |ctx_unwrapped| {
        ctx_unwrapped.destroy();
    }
}

pub export fn getVideoInfo(ctx: ?*InputContext) VideoInfoResult {
    if (ctx == null) {
        return .{ .info = null, .err_msg = "InputContext is null".ptr };
    }
    const context = ctx.?;

    if (context.fmt_ctx == null or context.stream == null or context.stream_index < 0) {
        return .{ .info = null, .err_msg = "Invalid InputContext state for getVideoInfo".ptr };
    }
    // Necesitamos desenvolver stream aquí porque lo usamos mucho
    const stream = context.stream.?;

    if (context.codec_ctx == null) {
        if (context.codec == null) {
            return .{ .info = null, .err_msg = "Codec not found in InputContext".ptr };
        }
        const codec_ctx = av.Codec.Context.alloc(context.codec.?) catch |err| {
            return .{ .info = null, .err_msg = createErrorString("CodecContext.alloc", err) };
        };
        context.codec_ctx = codec_ctx;

        codec_ctx.parameters_to_context(stream.codecpar) catch |err| {
            av.Codec.Context.free(codec_ctx);
            context.codec_ctx = null;
            return .{ .info = null, .err_msg = createErrorString("parameters_to_context", err) };
        };

        codec_ctx.open(context.codec.?, null) catch |err| {
            av.Codec.Context.free(codec_ctx);
            context.codec_ctx = null;
            return .{ .info = null, .err_msg = createErrorString("codec_ctx.open", err) };
        };
    }

    const info_ptr_any = av.malloc(@sizeOf(VideoInfo)) catch |err| {
        return .{ .info = null, .err_msg = createErrorString("Failed to allocate VideoInfo struct", err) };
    };
    if (info_ptr_any == null) {
        return .{ .info = null, .err_msg = "av.malloc returned null for VideoInfo".ptr };
    }
    var info: *VideoInfo = @as(*VideoInfo, @ptrCast(info_ptr_any));

    info.* = .{
        .codecName = null,
        .width = 0,
        .height = 0,
        .durationSeconds = 0.0,
    };

    info.width = stream.codecpar.*.width;
    info.height = stream.codecpar.*.height;

    const codec_desc = av.Codec.get_descriptor(stream.codecpar.*.codec_id);
    if (codec_desc) |desc| {
        const name_len = cStrLen(desc.name);
        if (name_len > 0) {
            const name_buf_info_any = av.malloc(name_len + 1) catch |err| {
                av.free(info);
                return .{ .info = null, .err_msg = createErrorString("Failed to allocate codecName for VideoInfo", err) };
            };
            if (name_buf_info_any == null) {
                av.free(info);
                return .{ .info = null, .err_msg = "av.malloc returned null for codecName".ptr };
            }
            const name_buf_info: [*]u8 = @as([*]u8, @ptrCast(name_buf_info_any));
            @memcpy(name_buf_info[0..name_len], desc.name[0..name_len]);
            name_buf_info[name_len] = 0;
            info.codecName = @as([*:0]const u8, @ptrCast(name_buf_info));

            if (context.codec_name == null) {
                const name_buf_ctx_any = av.malloc(name_len + 1) catch null; // Ignorar error de caché
                if (name_buf_ctx_any) |ptr| {
                    const name_buf_ctx: [*]u8 = @as([*]u8, @ptrCast(ptr));
                    @memcpy(name_buf_ctx[0..name_len], desc.name[0..name_len]);
                    name_buf_ctx[name_len] = 0;
                    context.codec_name = @as([*:0]const u8, @ptrCast(name_buf_ctx));
                }
            }
        }
    }

    if (context.fmt_ctx.?.duration != av.NOPTS_VALUE) {
        info.durationSeconds = @as(f64, @floatFromInt(context.fmt_ctx.?.duration)) / @as(f64, @floatFromInt(av.TIME_BASE));
    } else if (stream.duration != av.NOPTS_VALUE) {
        const tb = stream.time_base;
        if (tb.den != 0) {
            info.durationSeconds = @as(f64, @floatFromInt(stream.duration)) * @as(f64, @floatFromInt(tb.num)) / @as(f64, @floatFromInt(tb.den));
        } else {
            info.durationSeconds = 0.0;
        }
    } else {
        info.durationSeconds = 0.0;
    }

    return .{ .info = info, .err_msg = null };
}

pub export fn freeVideoInfo(info_ptr: ?*VideoInfo) void {
    if (info_ptr) |info| {
        if (info.codecName) |name_ptr| {
            av.free(@as(?*anyopaque, @ptrCast(@constCast(name_ptr))));
        }
        av.free(info);
    }
}

pub export fn transcode(inputFile: [*:0]const u8, outputFile: [*:0]const u8, options: [*:0]const u8) TranscodeResult {
    _ = inputFile;
    _ = outputFile;
    _ = options;
    const msg = "Transcode not implemented";
    const buf = av.malloc(msg.len + 1) catch {
        return .{ .success = false, .message = "Alloc failed for error".ptr };
    };
    if (buf == null) return .{ .success = false, .message = "Alloc failed for error".ptr };
    const buf_slice: [*]u8 = @as([*]u8, @ptrCast(buf));
    @memcpy(buf_slice[0..msg.len], msg);
    buf_slice[msg.len] = 0;
    return .{ .success = false, .message = @as([*:0]const u8, @ptrCast(buf_slice)) };
}
