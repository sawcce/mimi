pub const Module = struct {
    init: *const fn () void,
    deinit: *const fn () void,
};
