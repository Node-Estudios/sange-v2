// src/ts/main.ts

// Importar las funciones y tipos (excepto ZigPtr)
import {
    openInput,
    closeInput,
    getVideoInfo,
    transcode,
    freeString,
    freeVideoInfo,
    type OpenResult,       // Importar interfaces de resultado
    type VideoInfoResult,
    type TranscodeResult,
    // No importar ZigPtr
  } from '@zig/ffmpeg'; // Asegúrate que el nombre del módulo es correcto
  
  // Definir un tipo localmente para representar los punteros de Zigar
  // Ajusta esto según lo que realmente devuelva Zigar (comúnmente { ptr: string } o { ptr: bigint })
  // Incluimos el hipotético .read() para strings
  type ZigPointer = {
      ptr: string | bigint;
      read?(): string;
      // Añadir otros campos si Zigar los incluye (como acceso a campos de struct)
      codecName?: ZigPointer | null; // Para VideoInfoPtr
      width?: number;
      height?: number;
      durationSeconds?: number;
  };
  
  
  console.log("Iniciando operaciones con FFmpeg (via Zig)...");
  
  // Rutas de ejemplo (ajústalas a tu entorno)
  const inputFilePath = "/video.mp4"; // CAMBIAR ESTO
  const outputFilePath = "/output.mp4"; // CAMBIAR ESTO
  const transcodeOptions = "-c:v libx264 -crf 28 -c:a aac -b:a 128k"; // Opciones de ejemplo
  
  // Usar el tipo local ZigPointer en lugar de ZigPtr importado
  let inputCtx: ZigPointer | null = null;
  let errorMsgPtr: ZigPointer | null = null;
  let videoInfoPtr: ZigPointer | null = null;
  
  try {
    // 1. Abrir el archivo de entrada
    const openResult: OpenResult = openInput(inputFilePath);
    inputCtx = openResult.ctx;
    errorMsgPtr = openResult.err_msg;
  
    if (errorMsgPtr) {
      const errorMessage = errorMsgPtr.read ? errorMsgPtr.read() : `Error al abrir (mensaje no legible: ${errorMsgPtr.ptr})`;
      console.error(`Error en openInput: ${errorMessage}`);
      freeString(errorMsgPtr); // Liberar la memoria del string de error
      errorMsgPtr = null;
      process.exit(1);
    }
  
    if (!inputCtx) {
        console.error("Error en openInput: No se devolvió ni contexto ni mensaje de error.");
        process.exit(1);
    }
  
    console.log("Archivo de entrada abierto con éxito. Contexto:", inputCtx.ptr);
  
  
    // 2. Obtener información del video
    const infoResult: VideoInfoResult = getVideoInfo(inputCtx);
    videoInfoPtr = infoResult.info;
    errorMsgPtr = infoResult.err_msg;
  
    if (errorMsgPtr) {
        const errorMessage = errorMsgPtr.read ? errorMsgPtr.read() : `Error en getVideoInfo (mensaje no legible: ${errorMsgPtr.ptr})`;
        console.error(`Error en getVideoInfo: ${errorMessage}`);
        freeString(errorMsgPtr);
        errorMsgPtr = null;
    } else if (videoInfoPtr) {
        console.log("Información del Video obtenida:");
        // Acceder a los campos (asumiendo que Zigar los mapea en el objeto puntero)
        const codecNamePtr = videoInfoPtr.codecName;
        const codecName = codecNamePtr?.read ? codecNamePtr.read() : "N/A";
  
        console.log(`  Codec: ${codecName}`);
        // Asegúrate de que estos campos existan en el objeto que Zigar devuelve para VideoInfoPtr
        console.log(`  Dimensiones: ${videoInfoPtr.width ?? 'N/A'}x${videoInfoPtr.height ?? 'N/A'}`);
        console.log(`  Duración: ${videoInfoPtr.durationSeconds?.toFixed(2) ?? 'N/A'} segundos`);
  
        // Liberar la memoria de VideoInfo AHORA
        freeVideoInfo(videoInfoPtr);
        videoInfoPtr = null; // Resetear
  
    } else {
        console.warn("getVideoInfo no devolvió ni información ni error.");
    }
  
    // 3. Transcodificar el archivo
    console.log(`Iniciando transcodificación a ${outputFilePath} con opciones: ${transcodeOptions}`);
    const transcodeResult: TranscodeResult = transcode(inputFilePath, outputFilePath, transcodeOptions);
    errorMsgPtr = transcodeResult.message;
  
    if (transcodeResult.success) {
      console.log("Transcodificación completada con éxito.");
      if (errorMsgPtr) {
          const successMessage = errorMsgPtr.read ? errorMsgPtr.read() : "(Mensaje adicional no legible)";
          console.log(`  Mensaje adicional: ${successMessage}`);
          freeString(errorMsgPtr);
          errorMsgPtr = null;
      }
    } else {
      const errorMessage = errorMsgPtr?.read ? errorMsgPtr.read() : `Fallo en transcodificación (sin mensaje específico)`;
      console.error(`Error en transcode: ${errorMessage}`);
      if (errorMsgPtr) {
          freeString(errorMsgPtr);
          errorMsgPtr = null;
      }
    }
  
  } catch (e) {
    console.error("Error inesperado durante la ejecución:", e);
  } finally {
    // 4. Cerrar el contexto de entrada (MUY IMPORTANTE)
    if (inputCtx) {
      console.log("Cerrando contexto de entrada...");
      closeInput(inputCtx);
      console.log("Contexto cerrado.");
      inputCtx = null;
    }
    // Asegurarse de liberar memoria pendiente
    if (errorMsgPtr) {
        console.warn("Liberando puntero de error pendiente en finally...");
        freeString(errorMsgPtr);
    }
    if (videoInfoPtr) { // Aunque debería ser null aquí, por seguridad
         console.warn("Liberando puntero de VideoInfo pendiente en finally...");
         freeVideoInfo(videoInfoPtr);
    }
    console.log("Operaciones con FFmpeg finalizadas.");
  }