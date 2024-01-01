pub const ModuleSpec = struct {
    init: ?*const fn () void,
    deinit: ?*const fn () void,
};

pub fn init_modules(modules: []ModuleSpec) void {
    for (modules) |module| {
        module.init();
    }
}
