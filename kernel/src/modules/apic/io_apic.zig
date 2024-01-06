const IO_REG_SELECT = 0x00;
const IO_REG_WIN = 0x10;

pub const Register = enum(u8) {
    APICID = 0x00,
    APICVER = 0x01,
    APICARB = 0x02,
    REDTBL = 0x10,
};

pub const IOAPIC = struct {
    pub fn read(self: *const @This(), register: Register) u32 {
        const sel: *u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_SELECT);
        sel.* = @intFromEnum(register);

        const res: *u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_WIN);o
        return res;
    }

    pub fn write(self: *@This(), register: Register, data: u32) void {
        const sel: *u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_SELECT);
        sel.* = @intFromEnum(register);

        const dest: *u32 = @ptrFromInt(@intFromPtr(self) + IO_REG_WIN);
        dest.* = data;
    }
};
