import { openInput, closeInput, getVideoInfo, transcode, freeString, freeVideoInfo, } from '../../zig/src/ffmpeg.zig';
console.log("Iniciando operaciones con FFmpeg (via Zig)...");
const inputFilePath = "/video.mp4";
const outputFilePath = "/output.mp4";
const transcodeOptions = "-c:v libx264 -crf 28 -c:a aac -b:a 128k";
let inputCtx = null;
let errorMsgPtr = null;
let videoInfoPtr = null;
try {
    const openResult = openInput(inputFilePath);
    inputCtx = openResult.ctx;
    errorMsgPtr = openResult.err_msg;
    if (errorMsgPtr) {
        const errorMessage = errorMsgPtr.read ? errorMsgPtr.read() : `Error al abrir (mensaje no legible: ${errorMsgPtr.ptr})`;
        console.error(`Error en openInput: ${errorMessage}`);
        freeString(errorMsgPtr);
        errorMsgPtr = null;
        process.exit(1);
    }
    if (!inputCtx) {
        console.error("Error en openInput: No se devolvió ni contexto ni mensaje de error.");
        process.exit(1);
    }
    console.log("Archivo de entrada abierto con éxito. Contexto:", inputCtx.ptr);
    const infoResult = getVideoInfo(inputCtx);
    videoInfoPtr = infoResult.info;
    errorMsgPtr = infoResult.err_msg;
    if (errorMsgPtr) {
        const errorMessage = errorMsgPtr.read ? errorMsgPtr.read() : `Error en getVideoInfo (mensaje no legible: ${errorMsgPtr.ptr})`;
        console.error(`Error en getVideoInfo: ${errorMessage}`);
        freeString(errorMsgPtr);
        errorMsgPtr = null;
    }
    else if (videoInfoPtr) {
        console.log("Información del Video obtenida:");
        const codecNamePtr = videoInfoPtr.codecName;
        const codecName = codecNamePtr?.read ? codecNamePtr.read() : "N/A";
        console.log(`  Codec: ${codecName}`);
        console.log(`  Dimensiones: ${videoInfoPtr.width ?? 'N/A'}x${videoInfoPtr.height ?? 'N/A'}`);
        console.log(`  Duración: ${videoInfoPtr.durationSeconds?.toFixed(2) ?? 'N/A'} segundos`);
        freeVideoInfo(videoInfoPtr);
        videoInfoPtr = null;
    }
    else {
        console.warn("getVideoInfo no devolvió ni información ni error.");
    }
    console.log(`Iniciando transcodificación a ${outputFilePath} con opciones: ${transcodeOptions}`);
    const transcodeResult = transcode(inputFilePath, outputFilePath, transcodeOptions);
    errorMsgPtr = transcodeResult.message;
    if (transcodeResult.success) {
        console.log("Transcodificación completada con éxito.");
        if (errorMsgPtr) {
            const successMessage = errorMsgPtr.read ? errorMsgPtr.read() : "(Mensaje adicional no legible)";
            console.log(`  Mensaje adicional: ${successMessage}`);
            freeString(errorMsgPtr);
            errorMsgPtr = null;
        }
    }
    else {
        const errorMessage = errorMsgPtr?.read ? errorMsgPtr.read() : `Fallo en transcodificación (sin mensaje específico)`;
        console.error(`Error en transcode: ${errorMessage}`);
        if (errorMsgPtr) {
            freeString(errorMsgPtr);
            errorMsgPtr = null;
        }
    }
}
catch (e) {
    console.error("Error inesperado durante la ejecución:", e);
}
finally {
    if (inputCtx) {
        console.log("Cerrando contexto de entrada...");
        closeInput(inputCtx);
        console.log("Contexto cerrado.");
        inputCtx = null;
    }
    if (errorMsgPtr) {
        console.warn("Liberando puntero de error pendiente en finally...");
        freeString(errorMsgPtr);
    }
    if (videoInfoPtr) {
        console.warn("Liberando puntero de VideoInfo pendiente en finally...");
        freeVideoInfo(videoInfoPtr);
    }
    console.log("Operaciones con FFmpeg finalizadas.");
}
//# sourceMappingURL=main.js.map