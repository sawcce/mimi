const Procedures = @import("../procedures.zig");
const PhysAlloc = @import("../phys_alloc.zig");
const ACPI = @import("../acpi/acpi.zig");
const LocalAPIC = @import("local_apic.zig");

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

const MADTLocalAPIC = packed struct {
    proc_uid: u8,
    apic_id: u8,
    enabled: bool,
    online_capable: bool,
    _: u30,
};

const MADTIOAPIC = packed struct {
    id: u8,
    _: u8,
    addr: u32,
    gsi_base: u32,
};

const MADTLocalAPICNMI = packed struct {
    proc_uid: u8,
    flags: u16,
    apic_lint: u8,
};

pub var CPU_COUNT: u8 = 0;
pub var CPU_APIC_ID: [256]u8 = undefined;

pub fn apic(entry: *APICHeader) void {
    const lapic: *LocalAPIC.LAPIC = @ptrFromInt(entry.interrupt_controller_addr + PhysAlloc.offset);
    LocalAPIC.initLapic(lapic);

    var curr_addr = @intFromPtr(entry) + 44;
    const end_addr = @intFromPtr(entry) + entry.header.length;

    while (curr_addr < end_addr) {
        const structure: *APICEntry = @ptrFromInt(curr_addr);

        switch (structure.entry_type) {
            EntryType.ProcLocalApic => {
                const lapic_s = structure.cast_data(MADTLocalAPIC);
                CPU_APIC_ID[lapic_s.proc_uid] = lapic_s.apic_id;
                CPU_COUNT += 1;
            },
            EntryType.IOApic => {
                const io_apic = structure.cast_data(MADTIOAPIC);
                Procedures.write_fmt("IO Apic: {}\n", .{io_apic}) catch {};
            },
            else => {},
        }
        curr_addr += structure.length;
    }

    Procedures.write_fmt("[APIC] Found {} processors\n", .{CPU_COUNT}) catch {};
}
