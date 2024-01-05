const ModuleSpec = @import("../module.zig").ModuleSpec;
const PhysAlloc = @import("../phys_alloc.zig");

const Limine = @import("limine");

pub const Display = struct {
    width: u32,
    height: u32,
};

pub const Module = ModuleSpec{
    .name = "Display",
    .init = init,
    .deinit = null,
};

pub fn init() void {}
