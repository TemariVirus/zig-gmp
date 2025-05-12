const gmp = @cImport(@cInclude("gmp.h"));

pub const Mpz = @import("mpz.zig").Mpz;

// TODO: figure out printing interface
pub fn print(fmt: []const u8, value: anytype) void {
    _ = gmp.gmp_printf(@ptrCast(fmt), value);
}
