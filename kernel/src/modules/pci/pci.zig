pub const ModuleSpec = @import("../module.zig").ModuleSpec;
pub const ACPI = @import("../acpi/acpi.zig");
pub const Procedures = @import("../procedures.zig");
pub const PhysAlloc = @import("../phys_alloc.zig");

pub const std = @import("std");

pub const Module = ModuleSpec{
    .name = "PCI(e) support",
    .init = init,
    .deinit = null,
};

pub var MCFG_table: *align(4) MCFGTable = undefined;
var functions: std.ArrayList(FunctionWrapper) = undefined;

pub fn init() void {
    if (ACPI.MCFG_table_ptr) |ptr| MCFG_table = @ptrCast(ptr);
    Procedures.write_fmt("[PCIE] Found MCFG table: {}, with {} entries\n", .{ MCFG_table, MCFG_table.getEntriesAmount() }) catch {};
    functions = std.ArrayList(FunctionWrapper).initCapacity(PhysAlloc.allocator(), 10) catch {
        return;
    };

    for (0..MCFG_table.getEntriesAmount()) |i| {
        const controller = MCFG_table.getEntry(i);
        Procedures.write_fmt("[PCIE] Bus: {}\n", .{controller}) catch {};

        for (controller.start_pci_bus..controller.end_pci_bus) |bus_id| {
            for (0..16) |device_id| {
                for (0..8) |function_id| {
                    handlePCIEFunction(controller.base_address, i, bus_id, device_id, function_id);
                }
            }
        }
    }

    for (functions.items) |function_| {
        const function = function_.function_ptr;
        Procedures.write_fmt("[PCIE Function] Class code: {x}, Vendor ID: {x}, Device ID: {x}\n", .{ function.class_code, function.vendor_id, function.device_id }) catch {};
    }
}

pub fn getFunctions() []FunctionWrapper {
    return functions.items;
}

inline fn handlePCIEFunction(base_address: u64, controller_id: usize, bus_id: usize, device_id: usize, function_id: usize) void {
    const function: *align(1) PCIEFunction = @ptrFromInt(base_address + PhysAlloc.offset + (bus_id << 20) + (device_id << 15) + (function_id << 12));
    if (function.class_code == 0xffffff) return;

    functions.append(FunctionWrapper{
        .controller_id = controller_id,
        .bus_id = @intCast(bus_id),
        .device_id = @intCast(device_id),
        .function_id = @intCast(function_id),
        .function_ptr = function,
    }) catch {
        return;
    };
}

pub const FunctionWrapper = struct {
    controller_id: usize,
    bus_id: u8,
    device_id: u8,
    function_id: u8,
    function_ptr: *align(1) PCIEFunction,
};

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

pub const PCIEFunction = packed struct {
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
