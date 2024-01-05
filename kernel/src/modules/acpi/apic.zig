const Procedures = @import("../procedures.zig");
const PhysAlloc = @import("../phys_alloc.zig");
const ACPI = @import("acpi.zig");

const APICHeader = extern struct {
    header: ACPI.SDTHeader,
    interrupt_controller_addr: u32,
    flags: u32,
};

const EntryType = enum(u8) {
    ProcLocalApic = 0,
    IOApic = 1,
    IntSourceOverride = 2,
    NMISource = 3,
    LocalApicNMI = 4,
    LocalApicAddrOverride = 5,
    IOSApic = 6,
    LocalSApic = 7,
    PlatformIntSources = 8,
    ProcLocalx2APIC = 9,
    Localx2ApicNMI = 0xA,
    GICC = 0xB,
    GICD = 0xC,
    GICMSIFrame = 0xD,
    GICR = 0xE,
    GICITS = 0xF,
    MultiProcWakeup = 0x10,
    _,
};

const APICEntry = extern struct {
    entry_type: EntryType,
    length: u8,

    fn cast_data(self: *@This(), comptime T: type) *align(2) T {
        return @ptrFromInt(@intFromPtr(self) + @sizeOf(APICEntry));
    }
};

const LocalApic = packed struct {
    proc_uid: u8,
    apic_id: u8,
    enabled: bool,
    online_capable: bool,
    _: u30,
};

const LocalApicNMI = packed struct {
    proc_uid: u8,
    flags: u16,
    apic_lint: u8,
};

pub var CPU_COUNT: u8 = 0;
pub var CPU_APIC_ID: [256]u8 = undefined;

pub fn apic(entry: *APICHeader) void {
    const lapic: *LAPIC = @ptrFromInt(entry.interrupt_controller_addr + PhysAlloc.offset);
    initLapic(lapic);

    var curr_addr = @intFromPtr(entry) + 44;
    const end_addr = @intFromPtr(entry) + entry.header.length;

    while (curr_addr < end_addr) {
        const structure: *APICEntry = @ptrFromInt(curr_addr);

        switch (structure.entry_type) {
            EntryType.ProcLocalApic => {
                const lapic_s = structure.cast_data(LocalApic);
                CPU_APIC_ID[lapic_s.proc_uid] = lapic_s.apic_id;
                CPU_COUNT += 1;
            },
            else => {},
        }
        curr_addr += structure.length;
    }

    Procedures.write_fmt("[APIC] Found {} processors\n", .{CPU_COUNT}) catch {};
}

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

const LAPIC = struct {
    pub fn readRegister(self: *const @This(), offset: REG) u32 {
        return @as(*u32, @ptrFromInt(@intFromPtr(self) + @intFromEnum(offset))).*;
    }

    pub fn writeRegister(self: *@This(), offset: REG, data: u32) void {
        const ptr: *u32 = @ptrFromInt(@intFromPtr(self) + @intFromEnum(offset));
        ptr.* = data;
    }
};

pub fn initLapic(lapic: *LAPIC) void {
    _ = lapic;
}
