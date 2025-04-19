import signale, { SignaleOptions } from 'signale'
const { Signale } = signale

// Common options (optional)
const baseOptions: SignaleOptions = {
  };

export const tsLogger = new Signale({
    ...baseOptions,
    scope: 'SangeV2-TS', // Scope clearly identifies TS logs
    // You can customize types further if needed
    types: {
      info: {
        badge: 'ℹ️',
        color: 'blue',
        label: 'info',
      },
      debug: {
        badge: '🐛',
        color: 'magenta',
        label: 'debug',
      },
      // Add other types or overrides
    },
  });
  
  // Logger specifically for messages originating from the Zig Engine
  export const zigLogger = new Signale({
    ...baseOptions,
    scope: 'SangeV2-Zig', // Scope clearly identifies Zig logs
    types: {
      info: {
        badge: '⚙️', // Different badge for Zig info
        color: 'cyan',
        label: 'info',
      },
      debug: {
          badge: '🔧', // Different badge for Zig debug
          color: 'gray',
          label: 'debug',
        },
      warn: {
        badge: '⚠️',
        color: 'yellow',
        label: 'warn',
      },
      error: {
        badge: '🔥',
        color: 'red',
        label: 'error',
      },
    },
  });
  
  // Define or import the LogLevel enum mirroring Zig's definition
  export enum LogLevel {
    Debug,
    Info,
    Warn,
    Error,
  }