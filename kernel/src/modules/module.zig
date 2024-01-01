pub const ModuleSpec = struct {
    init: ?*const fn () void,
    deinit: ?*const fn () void,
};

// TODO: Keep track of loaded modules and support for deinit

pub fn init_modules(modules: []ModuleSpec) void {
    for (modules) |module| {
        module.init();
    }
}
