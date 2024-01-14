const ModuleSpec = @import("../module.zig").ModuleSpec;

pub const Module = ModuleSpec{
    .name = "Global Descriptor Table",
    .init = null,
    .deinit = null,
};
