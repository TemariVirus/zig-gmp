const std = @import("std");
const gmp = @cImport(@cInclude("gmp.h"));

pub const Mpz = @import("mpz.zig").Mpz;

// TODO: figure out printing interface
pub fn print(fmt: []const u8, value: anytype) void {
    _ = gmp.gmp_printf(@ptrCast(fmt), value);
}

var gmp_allocator: std.mem.Allocator = undefined;

/// Replace the current allocator. If `allocator` is `null`, the default allocator is used.
/// This allocator will be used for all memory allocation done by GMP, apart from temporary
/// space from `alloca` if that function is available and GMP is configured to use it (see Build Options).
/// Be sure to call `setAllocator` only when there are no active GMP objects allocated using the previous memory functions!
/// Usually that means calling it before any other GMP function.
pub fn setAllocator(allocator: ?std.mem.Allocator) void {
    if (allocator) |alloc| {
        gmp.mp_set_memory_functions(&gmpAllocate, &gmpReallocate, &gmpFree);
        gmp_allocator = alloc;
    } else {
        gmp.mp_set_memory_functions(null, null, null);
        gmp_allocator = undefined;
    }
}

fn gmpAllocate(alloc_size: usize) callconv(.c) *anyopaque {
    const memory = gmp_allocator.alloc(u8, alloc_size) catch @panic("OOM");
    return @ptrCast(memory.ptr);
}

fn gmpReallocate(ptr: ?*anyopaque, old_size: usize, new_size: usize) callconv(.c) *anyopaque {
    // "ptr is never NULL, it’s always a previously allocated block."
    const old_mem = @as([*]u8, @ptrCast(ptr.?))[0..old_size];
    const new_mem = gmp_allocator.realloc(old_mem, new_size) catch @panic("OOM");
    return @ptrCast(new_mem.ptr);
}

fn gmpFree(ptr: ?*anyopaque, size: usize) callconv(.c) void {
    // "ptr is never NULL, it’s always a previously allocated block"
    const memory = @as([*]u8, @ptrCast(ptr.?))[0..size];
    gmp_allocator.free(memory);
}

test {
    std.testing.refAllDecls(@This());
}
