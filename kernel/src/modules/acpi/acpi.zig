const ModuleSpec = @import("../module.zig").ModuleSpec;
const Procedures = @import("../procedures.zig");
const PhysAlloc = @import("../phys_alloc.zig");

const Limine = @import("limine");
const std = @import("std");

pub export var RSDPRequest: Limine.RsdpRequest = .{};

pub const Module = ModuleSpec{
    .name = "ACPI",
    .init = init,
    .deinit = null,
};

const RSDP = extern struct {
    signature: [8]u8,
    checksum: u8,
    oem_id: [6]u8,
    revision: u8,
    rsdt_address: u32,
};

const XSDP = extern struct {
    rsdp: RSDP,
    length: u32,
    xsdt_address: u64,
    extended_checksum: u8,
    reserved: [3]u8,
};

const XSDT = extern struct {
    header: SDTHeader,

    pub fn getEntriesAmount(self: *const @This()) usize {
        return (self.header.length - @sizeOf(SDTHeader)) / 8;
    }

    pub fn getEntry(self: *const @This(), i: usize) *SDTHeader {
        const addr = @as(*align(1) u64, @ptrFromInt(@intFromPtr(self) + @sizeOf(SDTHeader) + @sizeOf(u64) * i));
        return @as(*SDTHeader, @ptrFromInt(addr.* + PhysAlloc.offset));
    }
};

pub const Signature = enum(u32) {
    APIC = @as(*align(1) const u32, @ptrCast("APIC")).*,
    FACP = @as(*align(1) const u32, @ptrCast("FACP")).*,
    HPET = @as(*align(1) const u32, @ptrCast("HPET")).*,
    MCFG = @as(*align(1) const u32, @ptrCast("MCFG")).*,
    WAET = @as(*align(1) const u32, @ptrCast("WAET")).*,
    _,

    pub fn format(
        self: Signature,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.writeAll(@as(*const [4]u8, @ptrCast(&self)));
    }
};

const SDTHeader = extern struct {
    signature: Signature align(1),
    length: u32,
    revision: u8,
    checksum: u8,
    oem_id: [6]u8,
    oem_table_id: [8]u8,
    oem_revision: u32,
    creator_id: u32,
    creator_revision: u32,
};

pub fn init() void {
    if (RSDPRequest.response == null) return;
    const rsdp_response = RSDPRequest.response.?;
    const rsdp: *RSDP = @ptrCast(@alignCast(rsdp_response.address));

    // TODO: Support for other acpi versions
    if (rsdp.revision != 2) return;
    const xsdp: *align(1) XSDP = @ptrCast(@alignCast(rsdp_response.address));
    const xsdt: *XSDT = @as(*XSDT, @ptrFromInt(xsdp.xsdt_address + PhysAlloc.offset));

    for (0..xsdt.getEntriesAmount()) |i| {
        Procedures.write_fmt("Entry {}\n", .{xsdt.getEntry(i)}) catch {};
    }
}
