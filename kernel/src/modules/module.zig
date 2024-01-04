pub const ModuleSpec = struct {
    name: []const u8,
    init: ?*const fn () void,
    deinit: ?*const fn () void,
};

// TODO: Keep track of loaded modules and support for deinit

pub fn init_modules(modules: []const ModuleSpec) void {
    for (modules) |module| {
        if (module.init) |init| init();
    }
}
