pub const REG = enum(u32) {
    ID = 0x020,
    VERSION = 0x030,
    TPR = 0x080,
    APR = 0x090,
    PPR = 0x0a0,
    EOI = 0x0b0,
    RRD = 0x0c0,
    LDR = 0x0d0,
    DFR = 0x0e0,
    SVR = 0x0f0,
    ISR = 0x100,
    TMR = 0x180,
    IRR = 0x200,
    ESR = 0x280,
    ICRLO = 0x300,
    ICRHI = 0x310,
    TIMER = 0x320,
    THERMAL = 0x330,
    PERF = 0x340,
    LINT0 = 0x350,
    LINT1 = 0x360,
    ERROR = 0x370,
    TICR = 0x380,
    TCCR = 0x390,
    TDCR = 0x3e0,
};

pub const LAPIC = struct {
    pub fn readRegister(self: *const @This(), offset: REG) u32 {
        return @as(*volatile u32, @ptrFromInt(@intFromPtr(self) + @intFromEnum(offset))).*;
    }

    pub fn writeRegister(self: *@This(), offset: REG, data: u32) void {
        const ptr: *volatile u32 = @ptrFromInt(@intFromPtr(self) + @intFromEnum(offset));
        ptr.* = data;
    }
};

pub fn initLapic(lapic: *LAPIC) void {
    lapic.writeRegister(REG.TPR, 0);

    // Logical Destination Mode
    lapic.writeRegister(REG.DFR, 0xffffffff); // Flat mode
    lapic.writeRegister(REG.LDR, 0x01000000); // All cpus use logical id 1
    lapic.writeRegister(REG.SVR, 0x100 | 0xff);
}
