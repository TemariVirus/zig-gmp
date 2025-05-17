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
        var self: Mpz = undefined;
        gmp.mpz_init(@ptrCast(&self));
        return self;
    }

    /// Allocates a new `Mpz` with its value set to 0 and enough space for
    /// `bits`-bit numbers. `deinit` must be called to free memory.
    pub fn initCapacity(bits: BitCountInt) Mpz {
        var self: Mpz = undefined;
        gmp.mpz_init2(@ptrCast(&self), bits);
        return self;
    }

    pub fn deinit(self: *Mpz) void {
        gmp.mpz_clear(@ptrCast(self));
    }

    /// Change the space allocated to `bits` bits. The value is preserved if it
    /// fits, or is set to 0 if not.
    pub fn resize(self: *Mpz, bits: BitCountInt) void {
        gmp.mpz_realloc2(@ptrCast(self), bits);
    }

    /// Set the value of `self` to `op`.
    /// Supported types: `int`, `float`, `Mpz`, `Mpq`, `Mpf`.
    /// If `op` is `float`, `Mpq` or `Mpf`, `op` is truncated to make it an integer.
    pub fn set(self: *Mpz, op: anytype) void {
        const T = @TypeOf(op);
        switch (@typeInfo(T)) {
            .int => |info| switch (info.signedness) {
                .signed => gmp.mpz_set_si(@ptrCast(self), op),
                .unsigned => gmp.mpz_set_ui(@ptrCast(self), op),
            },
            .comptime_int => if (op < 0) {
                gmp.mpz_set_si(@ptrCast(self), op);
            } else {
                gmp.mpz_set_ui(@ptrCast(self), op);
            },
            .float, .comptime_float => gmp.mpz_set_d(@ptrCast(self), op),
            else => switch (T) {
                Mpz => gmp.mpz_set(@ptrCast(self), @ptrCast(&op)),
                // TODO: support rational and float types
                else => @compileError(std.fmt.comptimePrint("Unsupported type '{s}'", .{@typeName(T)})),
            },
        }
    }

    pub const SetStrError = error{ InvalidBase, NotANumber };

    /// Set the value of `self` from `str`, a string in base `base`. White space is ignored.
    /// The base may vary from 2 to 62, or if base is `null`, then the leading characters are used:
    /// 0x and 0X for hexadecimal, 0b and 0B for binary, 0 for octal, or decimal otherwise.
    /// For bases up to 36, case is ignored; upper-case and lower-case letters have the same value.
    /// For bases 37 to 62, upper-case letters represent the usual 10..35 while lower-case letters represent 36..61.
    pub fn setStr(self: *Mpz, str: []const u8, base: ?u6) SetStrError!void {
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

    /// Allocates a new `Mpz` and set the initial numeric value from `op`.
    /// Supported types: `int`, `float`, `Mpz`.
    pub fn initSet(op: anytype) Mpz {
        var self: Mpz = undefined;

        const T = @TypeOf(op);
        switch (@typeInfo(T)) {
            .int => |info| switch (info.signedness) {
                .signed => gmp.mpz_init_set_si(@ptrCast(&self), op),
                .unsigned => gmp.mpz_init_set_ui(@ptrCast(&self), op),
            },
            .comptime_int => if (op < 0) {
                gmp.mpz_init_set_si(@ptrCast(&self), op);
            } else {
                gmp.mpz_init_set_ui(@ptrCast(&self), op);
            },
            .float, .comptime_float => gmp.mpz_init_set_d(@ptrCast(&self), op),
            else => switch (T) {
                Mpz => gmp.mpz_init_set(@ptrCast(&self), @ptrCast(&op)),
                else => @compileError(std.fmt.comptimePrint("Unsupported type '{s}'", .{@typeName(T)})),
            },
        }
        return self;
    }

    /// Allocates a new `Mpz` and set its value like `setStr` (see its documentation for details).
    pub fn initSetStr(str: []const u8, base: ?u6) SetStrError!Mpz {
        if (base) |b| {
            if (b < 2 or b > 62) {
                return error.InvalidBase;
            }
        }

        var self: Mpz = undefined;
        errdefer self.deinit();
        const result = gmp.mpz_init_set_str(@ptrCast(&self), @ptrCast(str), base orelse 0);
        if (result != 0) {
            return error.NotANumber;
        }
        return self;
    }

    // TODO: Conversion functions

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

    /// Set `self` to `op1 times op2`.
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

    /// Set `self` to `self + (op1 times op2)`.
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

    /// Set `self` to `self - (op1 times op2)`.
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

    /// Set `self` to `op1 times (2 raised to op2)`. This operation can also be defined as a left shift by `op2` bits.
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

    fn isZero(self: Mpz) bool {
        // "Zero is represented by _mp_size set to zero"
        return self._mp_size == 0;
    }

    /// Divide `n` by `d`, forming a quotient `q`. Rounds `q` up towards +infinity.
    pub fn divCeilQ(q: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_cdiv_q(@ptrCast(q), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` up towards +infinity, and `r` will have the opposite sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    pub fn divCeilR(r: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_cdiv_r(@ptrCast(r), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` up towards +infinity, and `r` will have the opposite sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The same variable cannot be passed for both `q` and `r`, or results will be unpredictable.
    pub fn divCeilQR(q: *Mpz, r: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_cdiv_qr(@ptrCast(q), @ptrCast(r), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` up towards +infinity, and `r` will have the opposite sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divCeilQUlong(q: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_cdiv_q_ui(@ptrCast(q), @ptrCast(&n), d);
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` up towards +infinity, and `r` will have the opposite sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divCeilRUlong(r: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_cdiv_r_ui(@ptrCast(r), @ptrCast(&n), d);
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` up towards +infinity, and `r` will have the opposite sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The same variable cannot be passed for both `q` and `r`, or results will be unpredictable.
    /// The return value is the absolute value of the remainder.
    pub fn divCeilQRUlong(q: *Mpz, r: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_cdiv_qr_ui(@ptrCast(q), @ptrCast(r), @ptrCast(&n), d);
    }

    //// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` up towards +infinity, and `r` will have the opposite sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divCeilUlong(n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_cdiv_ui(@ptrCast(&n), d);
    }

    /// Divide `n` by `2^b`, forming a quotient `q`. Rounds `q` up towards +infinity.
    /// This function is implemented as a right shift.
    pub fn divCeilQ2exp(q: *Mpz, n: Mpz, b: BitCountInt) void {
        gmp.mpz_cdiv_q_2exp(@ptrCast(q), @ptrCast(&n), b);
    }

    /// Divide `n` by `2^b`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` up towards +infinity, and `r` will have the opposite sign to `2^b`.
    /// `q` and `r` will satisfy `n=q*(2^b)+r`, and `r` will satisfy `0<=abs(r)<abs(2^b)`.
    /// This function is implemented as a bit mask.
    pub fn divCeilR2exp(q: *Mpz, n: Mpz, b: BitCountInt) void {
        gmp.mpz_cdiv_r_2exp(@ptrCast(q), @ptrCast(&n), b);
    }

    /// Divide `n` by `d`, forming a quotient `q`. Rounds `q` down towards -infinity.
    pub fn divFloorQ(q: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_fdiv_q(@ptrCast(q), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` down towards -infinity, and `r` will have the same sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    pub fn divFloorR(r: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_fdiv_r(@ptrCast(r), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` down towards -infinity, and `r` will have the same sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The same variable cannot be passed for both `q` and `r`, or results will be unpredictable.
    pub fn divFloorQR(q: *Mpz, r: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_fdiv_qr(@ptrCast(q), @ptrCast(r), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` down towards -infinity, and `r` will have the same sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divFloorQUlong(q: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_fdiv_q_ui(@ptrCast(q), @ptrCast(&n), d);
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` down towards -infinity, and `r` will have the same sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divFloorRUlong(r: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_fdiv_r_ui(@ptrCast(r), @ptrCast(&n), d);
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` down towards -infinity, and `r` will have the same sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The same variable cannot be passed for both `q` and `r`, or results will be unpredictable.
    /// The return value is the absolute value of the remainder.
    pub fn divFloorQRUlong(q: *Mpz, r: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_fdiv_qr_ui(@ptrCast(q), @ptrCast(r), @ptrCast(&n), d);
    }

    //// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` down towards -infinity, and `r` will have the same sign to `d`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divFloorUlong(n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_fdiv_ui(@ptrCast(&n), d);
    }

    /// Divide `n` by `2^b`, forming a quotient `q`. Rounds `q` down towards -infinity.
    /// For positive `n` this is a simple bitwise right shift. For negative `n`, this is
    /// effectively an arithmetic right shift treating `n` as two’s complement the same
    /// as the bitwise logical functions do.
    pub fn divFloorQ2exp(q: *Mpz, n: Mpz, b: BitCountInt) void {
        gmp.mpz_fdiv_q_2exp(@ptrCast(q), @ptrCast(&n), b);
    }

    /// Divide `n` by `2^b`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` down towards -infinity, and `r` will have the same sign to `2^b`.
    /// `q` and `r` will satisfy `n=q*(2^b)+r`, and `r` will satisfy `0<=abs(r)<abs(2^b)`.
    /// This function is implemented as a bit mask.
    pub fn divFloorR2exp(q: *Mpz, n: Mpz, b: BitCountInt) void {
        gmp.mpz_fdiv_r_2exp(@ptrCast(q), @ptrCast(&n), b);
    }

    /// Divide `n` by `d`, forming a quotient `q`. Rounds `q` towards 0.
    pub fn divTruncQ(q: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_tdiv_q(@ptrCast(q), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` towards 0, and `r` will have the same sign as `n`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    pub fn divTruncR(r: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_tdiv_r(@ptrCast(r), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` towards 0, and `r` will have the same sign as `n`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The same variable cannot be passed for both `q` and `r`, or results will be unpredictable.
    pub fn divTruncQR(q: *Mpz, r: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_tdiv_qr(@ptrCast(q), @ptrCast(r), @ptrCast(&n), @ptrCast(&d));
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` towards 0, and `r` will have the same sign as `n`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divTruncQUlong(q: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_tdiv_q_ui(@ptrCast(q), @ptrCast(&n), d);
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` towards 0, and `r` will have the same sign as `n`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divTruncRUlong(r: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_tdiv_r_ui(@ptrCast(r), @ptrCast(&n), d);
    }

    /// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` towards 0, and `r` will have the same sign as `n`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The same variable cannot be passed for both `q` and `r`, or results will be unpredictable.
    /// The return value is the absolute value of the remainder.
    pub fn divTruncQRUlong(q: *Mpz, r: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_tdiv_qr_ui(@ptrCast(q), @ptrCast(r), @ptrCast(&n), d);
    }

    //// Divide `n` by `d`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` towards 0, and `r` will have the same sign as `n`.
    /// `q` and `r` will satisfy `n=q*d+r`, and `r` will satisfy `0<=abs(r)<abs(d)`.
    /// The return value is the absolute value of the remainder.
    pub fn divTruncUlong(n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_tdiv_ui(@ptrCast(&n), d);
    }

    /// Divide `n` by `2^b`, forming a quotient `q`. Rounds `q` towards 0.
    /// For positive `n` this is a simple bitwise right shift. For negative `n`, this is
    /// effectively an arithmetic right shift treating `n` as sign and magnitude.
    pub fn divTruncQ2exp(q: *Mpz, n: Mpz, b: BitCountInt) void {
        gmp.mpz_tdiv_q_2exp(@ptrCast(q), @ptrCast(&n), b);
    }

    /// Divide `n` by `2^b`, forming a quotient `q` and remainder `r`.
    /// Rounds `q` towards 0, and `r` will have the opposite sign to `2^b`.
    /// `q` and `r` will satisfy `n=q*(2^b)+r`, and `r` will satisfy `0<=abs(r)<abs(2^b)`.
    /// This function is implemented as a bit mask.
    pub fn divTruncR2exp(q: *Mpz, n: Mpz, b: BitCountInt) void {
        gmp.mpz_tdiv_r_2exp(@ptrCast(q), @ptrCast(&n), b);
    }

    /// Set `self` to `n mod d`.
    /// The sign of the divisor is ignored; the result is always non-negative.
    pub fn mod(self: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_mod(@ptrCast(self), @ptrCast(&n), @ptrCast(&d));
    }

    /// Set `self` to `n mod d`.
    /// The sign of the divisor is ignored; the result is always non-negative.
    /// This is identical to `divFloorRUlong`, returning the remainder as well as setting `self`.
    /// See `divFloorUlong` if only the return value is wanted.
    pub fn modUlong(self: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!c_ulong {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        return gmp.mpz_mod_ui(@ptrCast(self), @ptrCast(&n), d);
    }

    /// Set `q` to `n/d`.
    /// This function produces correct results only when it is known in advance that `d` divides `n`.
    /// This routine is much faster than the other division functions,
    /// and is the best choice when exact division is known to occur,
    /// for example reducing a rational to lowest terms.
    pub fn divExact(q: *Mpz, n: Mpz, d: Mpz) error{DivisionByZero}!void {
        if (d.isZero()) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_divexact(@ptrCast(q), @ptrCast(&n), @ptrCast(&d));
    }

    /// Set `q` to `n/d`.
    /// This function produces correct results only when it is known in advance that `d` divides `n`.
    /// This routine is much faster than the other division functions,
    /// and is the best choice when exact division is known to occur,
    /// for example reducing a rational to lowest terms.
    pub fn divExactUlong(q: *Mpz, n: Mpz, d: c_ulong) error{DivisionByZero}!void {
        if (d == 0) {
            @branchHint(.cold);
            return error.DivisionByZero;
        }
        gmp.mpz_divexact_ui(@ptrCast(q), @ptrCast(&n), d);
    }

    /// Return `true` if `self` is exactly divisible by `d`.
    /// `self` is divisible by `d` if there exists an integer `q` satisfying `self = q*d`.
    /// Unlike the other division functions, `d=0` is accepted and following the rule it
    /// can be seen that only 0 is considered divisible by 0.
    pub fn isDivisible(self: Mpz, d: Mpz) bool {
        return gmp.mpz_divisible_p(@ptrCast(&self), @ptrCast(&d)) != 0;
    }

    /// Return `true` if `self` is exactly divisible by `d`.
    /// `self` is divisible by `d` if there exists an integer `q` satisfying `self = q*d`.
    /// Unlike the other division functions, `d=0` is accepted and following the rule it
    /// can be seen that only 0 is considered divisible by 0.
    pub fn isDivisibleUlong(self: Mpz, d: c_ulong) bool {
        return gmp.mpz_divisible_ui_p(@ptrCast(&self), d) != 0;
    }

    /// Return `true` if `self` is exactly divisible by `2^b`.
    /// `self` is divisible by `2^b` if there exists an integer `q` satisfying `n = q*(2^b)`.
    pub fn isDivisible2exp(self: Mpz, b: BitCountInt) bool {
        return gmp.mpz_divisible_2exp_p(@ptrCast(&self), b) != 0;
    }

    /// Return `true` if `self` is congruent to `c modulo d`.
    /// `self` is congruent to `c mod d` if there exists an integer `q` satisfying `self = c + (q*d)`.
    /// Unlike the other division functions, `d=0` is accepted and following the rule it
    /// can be seen that `self` and `c` are considered congruent mod 0 only when exactly equal.
    pub fn isCongruent(self: Mpz, c: Mpz, d: Mpz) bool {
        return gmp.mpz_congruent_p(@ptrCast(&self), @ptrCast(&c), @ptrCast(&d)) != 0;
    }

    /// Return `true` if `self` is congruent to `c modulo d`.
    /// `self` is congruent to `c mod d` if there exists an integer `q` satisfying `self = c + (q*d)`.
    /// Unlike the other division functions, `d=0` is accepted and following the rule it
    /// can be seen that `self` and `c` are considered congruent mod 0 only when exactly equal.
    pub fn isCongruentUlong(self: Mpz, c: c_ulong, d: c_ulong) bool {
        return gmp.mpz_congruent_ui_p(@ptrCast(&self), c, d) != 0;
    }

    /// Return `true` if `self` is congruent to `c modulo (2^b)`.
    /// `self` is congruent to `c mod (2^b)` if there exists an integer `q` satisfying `self = c + (q*(2^d))`.
    pub fn isCongruent2exp(self: Mpz, c: Mpz, b: BitCountInt) bool {
        return gmp.mpz_congruent_2exp_p(@ptrCast(&self), @ptrCast(&c), b) != 0;
    }

    /// Compare `self` and `other`. Return `.gt` if `self > other`,
    /// `.gt` if `self = other`, or `.lt` if `self < other`.
    /// `other` can be an infinity, but results are undefined for a NaN.
    /// Supported types: `int`, `float`, `Mpz`.
    pub fn order(self: Mpz, other: anytype) std.math.Order {
        const T = @TypeOf(other);
        // Type must be explicit because mpz_cmp_ui and mpz_cmp_si are macros
        const ptr: [*c]const gmp.__mpz_struct = @ptrCast(&self);
        const result =
            switch (@typeInfo(T)) {
                .int => |info| switch (info.signedness) {
                    .unsigned => gmp.mpz_cmp_ui(ptr, other),
                    .signed => gmp.mpz_cmp_si(ptr, other),
                },
                .comptime_int => if (other < 0)
                    gmp.mpz_cmp_si(ptr, other)
                else
                    gmp.mpz_cmp_ui(ptr, other),
                .float, .comptime_float => gmp.mpz_cmp_d(ptr, other),
                else => switch (T) {
                    Mpz => gmp.mpz_cmp(ptr, @ptrCast(&other)),
                    else => @compileError(std.fmt.comptimePrint("Unsupported type '{s}'", .{@typeName(T)})),
                },
            };
        return switch (result) {
            std.math.minInt(@TypeOf(result))...-1 => .lt,
            0 => .eq,
            1...std.math.maxInt(@TypeOf(result)) => .gt,
        };
    }

    /// Compare the absolute values of `self` and `other`.
    /// Return `.gt` if `abs(self) > abs(other)`, `.gt` if `abs(self) = abs(other)`,
    /// or `.lt` if `abs(self) < abs(other)`.
    /// `other` can be an infinity, but results are undefined for a NaN.
    /// Supported types: `unsigned int`, `float`, `Mpz`.
    pub fn orderAbs(self: Mpz, other: anytype) std.math.Order {
        const T = @TypeOf(other);
        const result =
            switch (@typeInfo(T)) {
                .int => |info| switch (info.signedness) {
                    .unsigned => gmp.mpz_cmpabs_ui(@ptrCast(&self), other),
                    .signed => @compileError("'other' must be an unsigned integer"),
                },
                .comptime_int => gmp.mpz_cmpabs_ui(@ptrCast(&self), other),
                .float, .comptime_float => gmp.mpz_cmpabs_d(@ptrCast(&self), other),
                else => switch (T) {
                    Mpz => gmp.mpz_cmpabs(@ptrCast(&self), @ptrCast(&other)),
                    else => @compileError(std.fmt.comptimePrint("Unsupported type '{s}'", .{@typeName(T)})),
                },
            };
        return switch (result) {
            std.math.minInt(@TypeOf(result))...-1 => .lt,
            0 => .eq,
            1...std.math.maxInt(@TypeOf(result)) => .gt,
        };
    }

    /// Return `+1` if `self > 0`, `0` if `self = 0`, and `-1` if `self < 0`.
    pub fn sign(self: Mpz) i32 {
        // Own implementation because Zig doesn't translate GMP's macro properly
        return switch (self._mp_size) {
            std.math.minInt(@TypeOf(self._mp_size))...-1 => -1,
            0 => 0,
            1...std.math.maxInt(@TypeOf(self._mp_size)) => 1,
        };
    }
};
