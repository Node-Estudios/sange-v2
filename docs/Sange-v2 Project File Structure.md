
This structure aims to separate concerns based on the defined architectural layers (Zig Engine, TS Middle Layer, TS High Level) and facilitate development and maintenance.

## Top-Level Directory Structure

```Structure
/sange-v2/
|
├── src/                      # Core source code for the library
│   ├── zig/                  # Zig Engine implementation
│   ├── ts/                   # TypeScript implementation (Middle & High Level)
│   └── @zig/                 # Default Zigar output directory (bindings + native module)
│
├── examples/                 # Example usage (e.g., simple Discord bot integrating sange-v)
│   └── basic-bot/
│       └── ...
│
├── tests/                    # Automated tests
│   ├── zig/                  # Unit/integration tests for Zig code
│   └── ts/                   # Unit/integration tests for TypeScript code (all layers)
│
├── docs/                     # Project documentation
│   ├── architecture.md       # High-level overview (like our notes)
│   ├── zig_api.md            # Detailed Zig API documentation
│   └── ts_api.md             # Public TypeScript API documentation
│
├── node_modules/             # Node.js project dependencies
├── .gitignore                # Specifies intentionally untracked files
├── build.zig                 # Zig build script (configuration for Zig compiler)
├── LICENSE                   # Project license file (e.g., MIT, Apache 2.0)
├── node-zigar.config.json    # Zigar build configuration
├── package.json              # Node.js project manifest (dependencies, scripts)
├── README.md                 # Top-level project description and usage guide
└── tsconfig.json             # TypeScript compiler configuration

```

## Detailed `src/` Directory Structure

Markdown