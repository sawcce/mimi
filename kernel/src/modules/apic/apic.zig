const Procedures = @import("../procedures.zig");
const PhysAlloc = @import("../phys_alloc.zig");
const Interrupts = @import("../interrupts.zig");
const ACPI = @import("../acpi/acpi.zig");
const LocalAPIC = @import("local_apic.zig");
const IOAPIC = @import("io_apic.zig");
const std = @import("std");

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

const MADTNMI = packed struct { flags: u16, gsi: u32 };

// https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/05_ACPI_Software_Programming_Model/ACPI_Software_Programming_Model.html#interrupt-source-override-structure
const MADTINTSourceOverride = packed struct {
    bus: u8,
    source: u8,
    gsi: u32,
    flags: u16,
};

pub var CPU_COUNT: u8 = 0;
pub var CPU_APIC_ID: [256]u8 = undefined;

var LAPIC_REF: ?*LocalAPIC.LAPIC = null;

pub fn apic(entry: *APICHeader) void {
    const lapic: *LocalAPIC.LAPIC = @ptrFromInt(entry.interrupt_controller_addr + PhysAlloc.offset);
    LAPIC_REF = lapic;

    LocalAPIC.initLapic(lapic);

    const lapic_id = lapic.readRegister(LocalAPIC.REG.ID);
    Procedures.write_fmt("Local APIC id: {}\n", .{lapic_id}) catch {};

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
                IOAPIC.GLOBAL_IOAPIC = @ptrFromInt(io_apic.addr + PhysAlloc.offset);
                IOAPIC.GLOBAL_IOAPIC.?.write(IOAPIC.Register.APICID, lapic_id);
            },
            EntryType.IntSourceOverride => {
                const override = structure.cast_data(MADTINTSourceOverride);
                const ioredtbl = IOAPIC.IOREDTBL{
                    .vector = override.source + 0x20,
                    .delivery_mode = 0,
                    .destination_mode = false,
                    .pin_polarity = false,
                    .trigger_mode = false,
                    .mask = false,
                    .remote_irr = false,
                    .delivery_status = false,
                    .destination = @as(u8, @intCast(lapic_id)),
                };

                IOAPIC.GLOBAL_IOAPIC.?.write_ioredtbl(override.gsi, ioredtbl);
            },
            EntryType.NMISource => {
                const nmi = structure.cast_data(MADTNMI);
                Procedures.write_fmt("NMI: {}\n", .{nmi}) catch {};
            },
            else => {},
        }
        curr_addr += structure.length;
    }

    Procedures.write_fmt("[APIC] Found {} processors\n", .{CPU_COUNT}) catch {};
}
