const limine = @import("limine");
const std = @import("std");
const Ports = @import("modules/ports.zig");
const Module = @import("modules/module.zig");

// Set the base revision to 1, this is recommended as this is the latest
// base revision described by the Limine boot protocol specification.
// See specification for further info.
pub export var base_revision: limine.BaseRevision = .{ .revision = 1 };

inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

const GDT = @import("modules/gdt/gdt.zig");
const Procedures = @import("modules/procedures.zig");
const Interrupts = @import("modules/interrupts/interrupts.zig");
const PhysAlloc = @import("modules/phys_alloc.zig");
const ACPI = @import("modules/acpi/acpi.zig");
const Display = @import("modules/display/display.zig");

const Modules = [_]Module.ModuleSpec{
    Procedures.Module,
    Interrupts.ExceptionsModule,
    ACPI.Module,
    Interrupts.InterruptsModule,
    Display.Module,
};

// The following will be our kernel's entry point.
export fn _start() callconv(.C) noreturn {
    // Ensure the bootloader actually understands our base revision (see spec).
    if (!base_revision.is_supported()) {
        done();
    }

    main() catch |e| {
        Procedures.write_fmt("Error: {}", .{e}) catch {};
    };

    // We're done, just hang...
    done();
}

fn main() !void {
    if (PhysAlloc.Module.init) |init| init();

    Module.init();
    try Module.loaded_modules.append(PhysAlloc.Module);

    try Module.init_modules(&Modules);
    Procedures.write_message("Modules successfully initialized!\n");
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, e: ?usize) noreturn {
    @setCold(true);

    _ = error_return_trace;
    _ = e;

    try Procedures.write_fmt("[PANIC!] {s}\n", .{msg});

    done();
}
