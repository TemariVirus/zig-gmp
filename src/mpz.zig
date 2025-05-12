const std = @import("std");
const gmp = @cImport(@cInclude("gmp.h"));

pub const Mpz = extern struct {
    /// Number of *limbs* allocated and pointed to by the _mp_d field.
    _mp_alloc: c_int,
    /// @abs(_mp_size) is the number of limbs the last field points to.
    /// If _mp_size is negative this is a negative number.
    _mp_size: c_int,
    /// Pointer to the limbs.
    _mp_d: [*]c_longlong,

    /// Allocates a new `Mpz` with its value set to 0. `deinit` must be called
    /// to free memory.
    pub fn init() Mpz {
        var z: Mpz = undefined;
        gmp.mpz_init(@ptrCast(&z));
        return z;
    }

    /// Allocates a new `Mpz` with its value set to 0 and enough space for
    /// `bits`-bit numbers. `deinit` must be called to free memory.
    pub fn initCapacity(bits: u64) Mpz {
        var z: Mpz = undefined;
        gmp.mpz_init2(@ptrCast(&z), bits);
        return z;
    }

    pub fn deinit(self: *Mpz) void {
        gmp.mpz_clear(@ptrCast(self));
    }

    /// Change the space allocated to `bits` bits. The value is preserved if it
    /// fits, or is set to 0 if not.
    pub fn resize(self: *Mpz, bits: u64) void {
        gmp.mpz_realloc2(@ptrCast(self), bits);
    }

    /// Set the value of `self` to `value`.
    /// Supported types: `int`, `float`, `Mpz`, `Mpq`, `Mpf`.
    pub fn set(self: *Mpz, value: anytype) void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .pointer => |info| switch (info.child) {
                Mpz => gmp.mpz_set(@ptrCast(self), @ptrCast(value)),
                // TODO: support rational and float types
                else => @compileError("Unsupported type " ++ @typeName(info.child)),
            },
            .int => |info| switch (info.signedness) {
                .signed => gmp.mpz_set_si(@ptrCast(self), value),
                .unsigned => gmp.mpz_set_ui(@ptrCast(self), value),
            },
            .float => gmp.mpz_set_d(@ptrCast(self), value),
            .comptime_int, .comptime_float => @compileError("TODO"),
            else => @call(.always_inline, set, .{ self, &value }),
        }
    }

    /// Set the value of `self` from `str`, a string in base `base`. White space is ignored.
    /// The base may vary from 2 to 62, or if base is `null`, then the leading characters are used:
    /// 0x and 0X for hexadecimal, 0b and 0B for binary, 0 for octal, or decimal otherwise.
    /// For bases up to 36, case is ignored; upper-case and lower-case letters have the same value.
    /// For bases 37 to 62, upper-case letters represent the usual 10..35 while lower-case letters represent 36..61.
    pub fn setStr(self: *Mpz, str: []const u8, base: ?u6) error{ InvalidBase, NotANumber }!void {
        const _base = base orelse 0;
        if (_base == 1 or _base > 62) {
            return error.InvalidBase;
        }

        const result = gmp.mpz_set_str(@ptrCast(self), @ptrCast(str), _base);
        if (result != 0) {
            return error.NotANumber;
        }
    }

    /// Swap the values `self` and `other` efficiently.
    pub fn swap(self: *Mpz, other: *Mpz) void {
        gmp.mpz_swap(@ptrCast(self), @ptrCast(other));
    }
};
