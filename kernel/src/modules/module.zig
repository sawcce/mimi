const Procedures = @import("procedures.zig");
const PhysAlloc = @import("phys_alloc.zig");

const std = @import("std");

pub const ModuleSpec = struct {
    name: []const u8,
    init: ?*const fn () void,
    deinit: ?*const fn () void,
};

pub var loaded_modules: std.ArrayList(ModuleSpec) = undefined;

// TODO: Support for deinit

pub fn init() void {
    loaded_modules = std.ArrayList(ModuleSpec).init(PhysAlloc.allocator());
}

pub fn init_modules(modules: []const ModuleSpec) !void {
    for (modules) |module| {
        if (module.init) |init_| {
            init_();
            try loaded_modules.append(module);
            Procedures.write_fmt("Module {s} successfully initialized\n", .{module.name}) catch {};
        }
    }
}
