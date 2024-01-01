pub const ModuleSpec = struct {
    init: ?*const fn () void,
    deinit: ?*const fn () void,
};
