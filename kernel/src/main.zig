const limine = @import("limine");
const std = @import("std");
const Ports = @import("modules/ports.zig");
const Module = @import("modules/module.zig");

// The Limine requests can be placed anywhere, but it is important that
// the compiler does not optimise them away, so, usually, they should
// be made volatile or equivalent. In Zig, `export var` is what we use.
pub export var framebuffer_request: limine.FramebufferRequest = .{};

// Set the base revision to 1, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
// See specification for further info.
pub export var base_revision: limine.BaseRevision = .{ .revision = 1 };

inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

const Procedures = @import("modules/procedures.zig");

const Modules = [_]Module.ModuleSpec{
    Procedures.Module,
};

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        done();
    }

    Module.init_modules(&Modules);
    Procedures.write_message("Modules successfully initialized!\n");

    // We're done, just hang...
    done();
}
