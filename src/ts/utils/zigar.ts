// src/ts/utils/zigar.ts
import { TextDecoder } from 'util';

// Helper function to find symbols by description
function findSymbol(obj: any, description: string): symbol | undefined {
    if (!obj || typeof obj !== 'object') return undefined;
    return Object.getOwnPropertySymbols(obj).find(sym => sym.description === description);
}

/**
 * Decodes a null-terminated C string from a Zigar pointer object ([*c]const u8).
 * Relies on accessing internal Zigar symbols (like 'slots' and 'memory').
 * WARNING: This approach is fragile and may break with Zigar updates.
 *
 * @param zigarPointer The pointer object returned by Zigar.
 * @param maxLen Maximum number of bytes to read to prevent infinite loops.
 * @returns The decoded JavaScript string, or null if decoding fails.
 */
export function decodeZigarCString(zigarPointer: unknown, maxLen: number = 1024): string | null {
    if (!zigarPointer || typeof zigarPointer !== 'object') {
        console.error("decodeZigarCString: Input is not a valid Zigar pointer object.", zigarPointer);
        return null;
    }

    let dataView: DataView | null = null;

    // --- Attempt to access the DataView via internal Symbols ---
    const symSlots = findSymbol(zigarPointer, 'slots');
    const symMemory = findSymbol(zigarPointer, 'memory'); 

    if (!symSlots || !symMemory) {
        console.error("decodeZigarCString: Could not find required internal Zigar symbols ('slots', 'memory'). Zigar internals might have changed.");
        return null;
    }

    try {
        const pointedToSlice = (zigarPointer as any)[symSlots]?.[0];
        if (pointedToSlice && typeof pointedToSlice === 'object') {
            const innerMemoryView = (pointedToSlice as any)[symMemory];
            if (innerMemoryView instanceof DataView) {
                dataView = innerMemoryView;
            } else {
                 console.error("decodeZigarCString: Found slots[0] object, but its 'memory' symbol did not yield a DataView.", pointedToSlice);
            }
        } else {
             console.error("decodeZigarCString: Could not access pointed-to slice object via slots[0].", zigarPointer);
        }
    } catch (error) {
        console.error("decodeZigarCString: Error accessing internal Zigar structure:", error);
        return null;
    }
    // --- End of DataView access attempt ---


    if (!dataView) {
        console.error("decodeZigarCString: Failed to obtain DataView from Zigar pointer object using internal symbols.");
        return null;
    }

    // --- Decoding Logic ---
    const bytes: number[] = [];
    try {
        for (let i = 0; i < maxLen; i++) {
            if (i >= dataView.byteLength) {
                console.warn(`decodeZigarCString: Reached end of DataView (length ${dataView.byteLength}) at index ${i} without finding null terminator.`);
                 if(i > 0 && dataView.getUint8(i - 1) === 0) break; 
                 if(i === 0 && dataView.byteLength === 0) break; 
                 if(i < dataView.byteLength && dataView.getUint8(i) === 0) break; 
                 else if (i >= dataView.byteLength) break; 
            }
            
            const byte = dataView.getUint8(i);
            
            if (byte === 0) break; 
            bytes.push(byte);
        }

        const textDecoder = new TextDecoder('utf-8', { fatal: true }); 
        return textDecoder.decode(Uint8Array.from(bytes));

    } catch (error) {
        console.error("decodeZigarCString: Error reading from DataView or decoding:", error);
        return null;
    }
}