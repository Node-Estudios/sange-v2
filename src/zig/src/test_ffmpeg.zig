// src/test_ffmpeg.zig
const std = @import("std");
const av = @import("av"); // Importamos el módulo "av"

// Ejemplo: Función simple para obtener la versión de libavformat
// NOTA: avformat_version no está disponible en allyourcodebase/ffmpeg/av.zig
// pub export fn getAvFormatVersion() u32 { ... }

// --- CORRECCIÓN AQUÍ: Cambiar tipo de retorno y añadir 'return' ---
// Ejemplo: Función para inicializar FFmpeg y devolver un estado
pub export fn initializeFFmpegAndGetStatus() *const [36:0]u8 { // Devolvemos un string ([:0]const u8)
    // NOTA: avformat_network_init no está disponible
    // _ = av.avformat_network_init();
    // std.log.info(...)

    // Configurar nivel de log (opcional)
    av.av_log_set_level(av.LOG.INFO);
    std.log.info("FFmpeg log level set", .{});

    // Devolvemos una cadena simple como confirmación
    return "FFmpeg log level set to INFO via Zig";
}
// --- FIN DE LA CORRECCIÓN ---

// --- Tu función sha1 original (si todavía la necesitas) ---
// ... (código de la función sha1) ...
// pub export fn sha1(...) ...
