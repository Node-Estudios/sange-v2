// src/ts/types/ffmpeg.d.ts (REVISADO)

// Define un tipo para representar los punteros opacos que devuelve Zig/Zigar
// Puede ser simplemente `unknown`, `object`, o una interfaz específica si Zigar la define.
// Usaremos una interfaz genérica por ahora. Asumimos que Zigar añade un método
// `.read()` o similar para leer strings C (esto es una suposición).
interface ZigPtr {
  ptr: string | bigint; // Zigar a menudo usa string o bigint para punteros
  read?(): string; // Hipotético método para leer un string C apuntado
}

// Interfaz que representa los datos DENTRO de la struct VideoInfo de Zig
// Asumimos que Zigar nos permite acceder a estos campos directamente
// a través del puntero devuelto (VideoInfoPtr).
interface VideoInfoData {
    codecName: ZigPtr | null; // Puntero al string C del nombre
    width: number;
    height: number;
    durationSeconds: number;
}

// El puntero a la struct VideoInfo en memoria Zig
// Combinamos el puntero opaco con el acceso a los datos.
type VideoInfoPtr = ZigPtr & VideoInfoData;


declare module '@zig/ffmpeg' {
  // --- Tipos de Resultado ---
  export interface OpenResult {
    ctx: ZigPtr | null;       // Puntero a InputContext si éxito
    err_msg: ZigPtr | null;   // Puntero a string C de error si falla
  }

  export interface VideoInfoResult {
      info: VideoInfoPtr | null; // Puntero a struct VideoInfo si éxito
      err_msg: ZigPtr | null;    // Puntero a string C de error si falla
  }

  export interface TranscodeResult {
    success: boolean;
    message: ZigPtr | null; // Puntero a string C si !success
  }

  // --- Funciones Exportadas de Zig ---
  export function openInput(filePath: string): OpenResult;
  export function closeInput(contextPtr: ZigPtr): void;
  export function getVideoInfo(contextPtr: ZigPtr): VideoInfoResult;
  export function transcode(inputFile: string, outputFile: string, options: string): TranscodeResult;

  // --- Funciones de Gestión de Memoria ---
  export function freeString(ptr: ZigPtr): void;
  export function freeVideoInfo(info_ptr: ZigPtr): void; // Pasamos el VideoInfoPtr

}