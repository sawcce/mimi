const ModuleSpec = @import("../module.zig").ModuleSpec;

pub const Module = ModuleSpec{
    .name = "USB Support",
    .init = null,
    .deinit = null,
};
