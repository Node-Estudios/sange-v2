// src/ts/types/test_ffmpeg.ts (o como lo llames)
declare module '@zig/test_ffmpeg' {
  // Cambia la firma de la función
export function initializeFFmpegAndGetStatus(): { string: string };
  // export function initializeFFmpeg(): void; // Comenta o elimina la antigua si cambiaste el nombre
  
  // Añade aquí cualquier otra función que exportes desde Zig
}