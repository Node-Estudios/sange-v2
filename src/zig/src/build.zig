const std = @import("std");
const builtin = @import("builtin");
// Asumiendo que build-cfg.zig existe y es necesario por node-zigar
const cfg = @import("build-cfg.zig");

pub fn build(b: *std.Build) void {
    // Comprobación de versión de Zig (parece parte de la plantilla)
    if (builtin.zig_version.major != 0 or builtin.zig_version.minor != 14) {
        @compileError("Unsupported Zig version");
    }
    const host_type = if (cfg.is_wasm) "wasm" else "napi";
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Dependencia FFmpeg ---
    const ffmpeg_dep = b.dependency("ffmpeg", .{
        .target = target,
        .optimize = optimize,
    });
    // --- Módulo "av" de la dependencia ---
    const ffmpeg_av_module = ffmpeg_dep.module("av");

    // --- Configuración de la librería compartida (de la plantilla zigar) ---
    const lib = b.addSharedLibrary(.{
        .name = cfg.module_name,
        .root_source_file = .{ .cwd_relative = cfg.zigar_src_path ++ "stub-" ++ host_type ++ ".zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = !cfg.multithreaded,
    });

    // --- Módulo Zigar (de la plantilla zigar) ---
    const zigar = b.createModule(.{
        .root_source_file = .{ .cwd_relative = cfg.zigar_src_path ++ "zigar.zig" },
    });

    // ---- CORRECCIÓN AQUÍ: Añadir "av" a las importaciones del módulo usuario ----
    // Define la lista de módulos que tu código (test_ffmpeg.zig) necesita importar
    const user_module_imports = [_]std.Build.Module.Import{
        .{ .name = "zigar", .module = zigar }, // El import existente de zigar
        .{ .name = "av", .module = ffmpeg_av_module }, // ¡Añadimos el import de "av"!
    };

    // --- Módulo 'mod' que envuelve tu código (test_ffmpeg.zig) ---
    const mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = cfg.module_path }, // Esto apunta a test_ffmpeg.zig
        .imports = &user_module_imports, // <-- Usamos la lista corregida
    });
    mod.addIncludePath(.{ .cwd_relative = cfg.module_dir }); // De la plantilla zigar

    // Añade tu módulo 'mod' a la librería final 'lib' (de la plantilla zigar)
    lib.root_module.addImport("module", mod);
    // ---- FIN DE LA CORRECCIÓN ----

    // --- Código de la plantilla zigar (resto) ---
    if (cfg.use_libc) {
        lib.linkLibC();
    }
    // ... (resto de la configuración WASM/opciones si aplica) ...
    // Nota: La definición de 'exe' y sus llamadas ('exe.root_module.addImport',
    // 'b.installArtifact(exe)', 'b.addRunArtifact(exe)') que teníamos antes
    // probablemente ya no son necesarias si node-zigar solo construye 'lib'.
    // Puedes borrarlas para limpiar el archivo si causan confusión.

    // --- Configuración de opciones (de la plantilla zigar) ---
    const options = b.addOptions();
    options.addOption(comptime_int, "eval_branch_quota", cfg.eval_branch_quota);
    options.addOption(bool, "omit_functions", cfg.omit_functions);
    options.addOption(bool, "omit_variables", cfg.omit_variables);
    lib.root_module.addOptions("export-options.zig", options);

    // --- Paso final de copia (de la plantilla zigar) ---
    const wf = switch (@hasDecl(std.Build, "addUpdateSourceFiles")) {
        true => b.addUpdateSourceFiles(),
        false => b.addWriteFiles(),
    };
    wf.addCopyFileToSource(lib.getEmittedBin(), cfg.output_path);
    wf.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&wf.step);
}
