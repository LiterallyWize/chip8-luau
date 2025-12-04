### A reasonably fast Luau [**CHIP-8**](https://en.wikipedia.org/wiki/CHIP-8) interpreter & emulator

Interpreter is implemented in pure Luau.

## Usage

Pre-built binaries for the emulator can be found in [Releases](https://github.com/literallywize/chip8-luau/releases/latest).

Alternatively, you can build with `lune run build [target]`. All roms in `rom/` will be imported as `StringValue` instances and are loaded from `System.luau` with the `PROGRAM` constant.  
Specifying `[target]` will import only the ROM with the given filename from `rom/`, and it's `StringValue` will be named `TARGET`.

<!-- please make this thing better -->
