# emlua

Yet another Lua port using Emscripten.

## Features

* Compatible with both Lua 5.2 and 5.3, will be compatible with Lua 5.1 eventually.
* Provides some parts of Lua C API, will provide most of it.
* Allows binding arbitrary JavaScript values to full userdata. Allows writing your own Lua <-> JS interoperability layer.
* Allows pushing JavaScript functions disguised as Lua C functions.

## Building

* Activate Emscripten tools.
* Run `make`.

## Examples

See `test.js`.

## Status

Some things work. Module is not browser friendly.
