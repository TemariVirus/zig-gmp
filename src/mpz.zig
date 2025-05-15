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

    pub const BitCountInt = usize; // 'unsigned long int' in C

    /// Allocates a new `Mpz` with its value set to 0. `deinit` must be called
    /// to free memory.
    pub fn init() Mpz {
        var z: Mpz = undefined;
        gmp.mpz_init(@ptrCast(&z));
        return z;
    }

    /// Allocates a new `Mpz` with its value set to 0 and enough space for
    /// `bits`-bit numbers. `deinit` must be called to free memory.
    pub fn initCapacity(bits: BitCountInt) Mpz {
        var z: Mpz = undefined;
        gmp.mpz_init2(@ptrCast(&z), bits);
        return z;
    }

    pub fn deinit(self: *Mpz) void {
        gmp.mpz_clear(@ptrCast(self));
    }

    /// Change the space allocated to `bits` bits. The value is preserved if it
    /// fits, or is set to 0 if not.
    pub fn resize(self: *Mpz, bits: BitCountInt) void {
        gmp.mpz_realloc2(@ptrCast(self), bits);
    }

    /// Set the value of `self` to `value`.
    /// Supported types: `int`, `float`, `Mpz`, `Mpq`, `Mpf`.
    pub fn set(self: *Mpz, value: anytype) void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .int => |info| switch (info.signedness) {
                .signed => gmp.mpz_set_si(@ptrCast(self), value),
                .unsigned => gmp.mpz_set_ui(@ptrCast(self), value),
            },
            .comptime_int => if (value < 0) {
                gmp.mpz_set_si(@ptrCast(self), value);
            } else {
                gmp.mpz_set_ui(@ptrCast(self), value);
            },
            .float, .comptime_float => gmp.mpz_set_d(@ptrCast(self), value),
            else => switch (T) {
                Mpz => gmp.mpz_set(@ptrCast(self), @ptrCast(&value)),
                // TODO: support rational and float types
                else => @compileError(std.fmt.comptimePrint("Unsupported type '{s}'", .{@typeName(T)})),
            },
        }
    }

    /// Set the value of `self` from `str`, a string in base `base`. White space is ignored.
    /// The base may vary from 2 to 62, or if base is `null`, then the leading characters are used:
    /// 0x and 0X for hexadecimal, 0b and 0B for binary, 0 for octal, or decimal otherwise.
    /// For bases up to 36, case is ignored; upper-case and lower-case letters have the same value.
    /// For bases 37 to 62, upper-case letters represent the usual 10..35 while lower-case letters represent 36..61.
    pub fn setStr(self: *Mpz, str: []const u8, base: ?u6) error{ InvalidBase, NotANumber }!void {
        if (base) |b| {
            if (b < 2 or b > 62) {
                return error.InvalidBase;
            }
        }

        const result = gmp.mpz_set_str(@ptrCast(self), @ptrCast(str), base orelse 0);
        if (result != 0) {
            return error.NotANumber;
        }
    }

    /// Swap the values `self` and `other` efficiently.
    pub fn swap(self: *Mpz, other: *Mpz) void {
        gmp.mpz_swap(@ptrCast(self), @ptrCast(other));
    }

    /// Set `self` to `op1 + op2`.
    /// Supported types: `unsigned int`, `Mpz`.
    pub fn add(self: *Mpz, op1: Mpz, op2: anytype) void {
        const T = @TypeOf(op2);
        switch (@typeInfo(T)) {
            .int => |info| switch (info.signedness) {
                .unsigned => gmp.mpz_add_ui(@ptrCast(self), @ptrCast(&op1), op2),
                .signed => @compileError("'op2' must be an unsigned integer"),
            },
            .comptime_int => gmp.mpz_add_ui(@ptrCast(self), @ptrCast(&op1), op2),
            else => gmp.mpz_add(@ptrCast(self), @ptrCast(&op1), @ptrCast(&op2)),
        }
    }

    /// Set `self` to `op1 - op2`.
    /// Supported types: `unsigned int`, `Mpz`.
    pub fn sub(self: *Mpz, op1: anytype, op2: anytype) void {
        const T1 = @TypeOf(op1);
        const T2 = @TypeOf(op2);
        switch (@typeInfo(T1)) {
            .int => |info| switch (info.signedness) {
                .unsigned => gmp.mpz_ui_sub(@ptrCast(self), op1, @ptrCast(&op2)),
                .signed => @compileError("'op1' must be an unsigned integer"),
            },
            .comptime_int => gmp.mpz_ui_sub(@ptrCast(self), op1, @ptrCast(&op2)),
            // Assume `op1` is of type `Mpz`
            else => switch (@typeInfo(T2)) {
                .int => |info| switch (info.signedness) {
                    .unsigned => gmp.mpz_sub_ui(@ptrCast(self), @ptrCast(&op1), op2),
                    .signed => @compileError("'op2' must be an unsigned integer"),
                },
                .comptime_int => gmp.mpz_sub_ui(@ptrCast(self), @ptrCast(&op1), op2),
                else => gmp.mpz_sub(@ptrCast(self), @ptrCast(&op1), @ptrCast(&op2)),
            },
        }
    }

    /// Set `self` to `op1 * op2`.
    /// Supported types: `int`, `Mpz`.
    pub fn mul(self: *Mpz, op1: Mpz, op2: anytype) void {
        const T = @TypeOf(op2);
        switch (@typeInfo(T)) {
            .int => |info| switch (info.signedness) {
                .signed => gmp.mpz_mul_si(@ptrCast(self), @ptrCast(&op1), op2),
                .unsigned => gmp.mpz_mul_ui(@ptrCast(self), @ptrCast(&op1), op2),
            },
            .comptime_int => if (op2 < 0) {
                gmp.mpz_mul_si(@ptrCast(self), @ptrCast(&op1), op2);
            } else {
                gmp.mpz_mul_ui(@ptrCast(self), @ptrCast(&op1), op2);
            },
            else => gmp.mpz_mul(@ptrCast(self), @ptrCast(&op1), @ptrCast(&op2)),
        }
    }

    /// Set `self` to `self + (op1 * op2)`.
    /// Supported types: `unsigned int`, `Mpz`.
    pub fn addMul(self: *Mpz, op1: Mpz, op2: anytype) void {
        const T = @TypeOf(op2);
        switch (@typeInfo(T)) {
            .int => |info| switch (info.signedness) {
                .signed => @compileError("'op2' must be an unsigned integer"),
                .unsigned => gmp.mpz_addmul_ui(@ptrCast(self), @ptrCast(&op1), op2),
            },
            .comptime_int => gmp.mpz_addmul_ui(@ptrCast(self), @ptrCast(&op1), op2),
            else => gmp.mpz_addmul(@ptrCast(self), @ptrCast(&op1), @ptrCast(&op2)),
        }
    }

    /// Set `self` to `self - (op1 * op2)`.
    /// Supported types: `unsigned int`, `Mpz`.
    pub fn subMul(self: *Mpz, op1: Mpz, op2: anytype) void {
        const T = @TypeOf(op2);
        switch (@typeInfo(T)) {
            .int => |info| switch (info.signedness) {
                .signed => @compileError("'op2' must be an unsigned integer"),
                .unsigned => gmp.mpz_submul_ui(@ptrCast(self), @ptrCast(&op1), op2),
            },
            .comptime_int => gmp.mpz_submul_ui(@ptrCast(self), @ptrCast(&op1), op2),
            else => gmp.mpz_submul(@ptrCast(self), @ptrCast(&op1), @ptrCast(&op2)),
        }
    }

    /// Set `self` to `op1 * (2 ^ op2)`. This operation can also be defined as a left shift by `op2` bits.
    pub fn mul2exp(self: *Mpz, op1: Mpz, op2: BitCountInt) void {
        gmp.mpz_mul_2exp(@ptrCast(self), @ptrCast(&op1), op2);
    }

    /// Set `self` to `−op`.
    pub fn neg(self: *Mpz, op: Mpz) void {
        gmp.mpz_neg(@ptrCast(self), @ptrCast(&op));
    }

    /// Set `self` to the absolute value of `op`.
    pub fn abs(self: *Mpz, op: Mpz) void {
        gmp.mpz_abs(@ptrCast(self), @ptrCast(&op));
    }
};
