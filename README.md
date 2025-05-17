### zig-gmp-bindings

This library provides Zig bindings for libgmp.

Zig version required: 0.14.0

Libgmp version packaged: 6.3.0

Currently supported targets (the main problem with supporting new targets is that I need to manually run `m4` to generate the assembly files, since there does't exist an `m4` wrapper for the Zig build system yet).

Arch \\ OS|Windows|Linux|macOS
-|:-:|:-:|:-:
`x86_64`|❌|✅|❌
`aarch64`|❌|❌|✅
