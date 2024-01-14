pub const Procedures = @import("../procedures.zig");
pub const std = @import("std");

pub var GLOBAL_IOAPIC: ?*IOAPIC = null;

const IO_REG_SELECT = 0x00;
const IO_REG_WIN = 0x10;

pub const Register = enum(u32) {
    APICID = 0x00,
    APICVER = 0x01,
    APICARB = 0x02,
    REDTBL = 0x10,
    _,

    pub fn REDTBL_Low(i: u32) Register {
        return @enumFromInt(0x10 + 2 * i);
    }

    pub fn REDTBL_High(i: u32) Register {
        return @enumFromInt(0x10 + 2 * i + 1);
    }
};

pub const IOREDTBL = packed struct {
    vector: u8,
    delivery_mode: u3,
    destination_mode: bool,
    delivery_status: bool,
    pin_polarity: bool,
    remote_irr: bool,
    trigger_mode: bool,
    mask: bool,
    reserved: u39 = 0,
    destination: u8,
};

pub const IOAPIC = struct {
    pub fn read(self: *const @This(), register: Register) u32 {
        const sel: *volatile u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_SELECT);
        sel.* = @intFromEnum(register);

        const res: *volatile u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_WIN);
        return res.*;
    }

    pub fn write(self: *@This(), register: Register, data: u32) void {
        const sel: *volatile u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_SELECT);
        sel.* = @intFromEnum(register);

        const dest: *volatile u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_WIN);
        dest.* = data;
    }

    pub fn write_ioredtbl(self: *@This(), i: u32, data_: IOREDTBL) void {
        const low = self.read(@enumFromInt(0x10 + i * 2));
        const high = self.read(@enumFromInt(0x11 + i * 2));
        const prev_data: u64 = low + std.math.shl(u64, @as(u64, @intCast(high)), 32);
        const prev_entry: *const IOREDTBL = @ptrCast(&prev_data);
        var data = data_;

        data.reserved = prev_entry.reserved;
        const new_low = @as(*const u32, @ptrCast(&data)).*;
        const new_high = @as(*u32, @ptrFromInt(@intFromPtr(&data) + @sizeOf(u32))).*;

        self.write(@enumFromInt(0x10 + i * 2), new_low);
        self.write(@enumFromInt(0x11 + i * 2), new_high);
    }
};
