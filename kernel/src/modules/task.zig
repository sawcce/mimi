const Procedures = @import("procedures.zig");
const Interrupts = @import("interrupts/idt.zig");

pub var current_task: *Task = undefined;

pub inline fn schedule(frame: *Interrupts.Frame) void {
    const new_task_ = current_task.next_task.?;
    current_task.frame = frame.*;
    current_task = new_task_;

    if (!current_task.started) {
        // Inherit context from last task (SHOULD BE CHANGED!)
        current_task.frame.cs = frame.cs;
        current_task.frame.eflags = frame.eflags;
        current_task.frame.ss = frame.ss;
        current_task.frame.rip = @intFromPtr(current_task.function.?);
        current_task.started = true;
    }

    frame.* = current_task.frame;
}

pub const Task = struct {
    name: []const u8,
    next_task: ?*Task = undefined,
    frame: Interrupts.Frame = undefined,
    started: bool = false,
    function: ?*const fn () void = null,
};
