pub const ModuleSpec = @import("../module.zig").ModuleSpec;
pub const ACPI = @import("../acpi/acpi.zig");
pub const Procedures = @import("../procedures.zig");
pub const PhysAlloc = @import("../phys_alloc.zig");

pub const Module = ModuleSpec{
    .name = "PCI(e) support",
    .init = init,
    .deinit = null,
};

pub var MCFG_table: *align(4) MCFGTable = undefined;

pub fn init() void {
    if (ACPI.MCFG_table_ptr) |ptr| MCFG_table = @ptrCast(ptr);
    Procedures.write_fmt("Found MCFG table: {}, with {} entries\n", .{ MCFG_table, MCFG_table.getEntriesAmount() }) catch {};

    for (0..MCFG_table.getEntriesAmount()) |i| {
        const e = MCFG_table.getEntry(i);
        Procedures.write_fmt("Entry: {}\n", .{e}) catch {};
    }
}

pub const MCFGTable = extern struct {
    header: ACPI.SDTHeader,
    _: u64 align(1),

    pub fn getEntriesAmount(self: *align(4) const @This()) usize {
        return (self.header.length - @sizeOf(MCFGTable)) / 16;
    }

    pub fn getEntry(self: *align(4) @This(), i: usize) *align(1) ConfigurationEntry {
        return @ptrFromInt(@intFromPtr(self) + 44 + @sizeOf(ConfigurationEntry) * i);
    }
};

pub const ConfigurationEntry = packed struct {
    base_address: u64,
    segment_group_number: u16,
    start_pci_bus: u8,
    end_pci_bus: u8,
    _: u32,
};

pub const ExtendedConfigSpace = packed struct {
    vendor_id: u16,
    device_id: u16,
    command: u16,
    status: u16,
    revision_id: u8,
    class_code: u24,
    cache_line: u8,
    lat_timer: u8,
    header_type: u8,
    bist: u8,
    bar: u192,
    cardbus_cis: u32,
    subsystem_vendor_id: u16,
    subsystem_id: u16,
    expansion_rom_addr: u32,
    cap_pointer: u8,
    _: u24,
    __: u32,
    int_line: u8,
    int_pin: u8,
    min_gnt: u8,
    max_lat: u8,
};
