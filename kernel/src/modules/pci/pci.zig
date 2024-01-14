pub const ModuleSpec = @import("../module.zig").ModuleSpec;
pub const ACPI = @import("../acpi/acpi.zig");
pub const Procedures = @import("../procedures.zig");

pub const Module = ModuleSpec{
    .name = "PCI(e) support",
    .init = init,
    .deinit = null,
};

pub var MCFG_table: *MCFGTable = undefined;

pub fn init() void {
    if (ACPI.MCFG_table_ptr) |ptr| MCFG_table = @ptrCast(ptr);
    Procedures.write_fmt("Found MCFG table: {}\n", .{MCFG_table}) catch {};
}

pub const MCFGTable = extern struct {
    header: ACPI.SDTHeader,
    _: u8,
};
