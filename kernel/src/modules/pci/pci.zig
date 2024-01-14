pub const ModuleSpec = @import("../module.zig").ModuleSpec;

pub const Module = ModuleSpec{
    .name = "PCI(e) support",
    .init = null,
    .deinit = null,
};
