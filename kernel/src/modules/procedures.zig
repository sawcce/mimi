///! Standard procedures for the kernel such as:
///! - Exceptions handling
///! - Writing to the standard output
const Ports = @import("ports.zig");
const ModuleSpec = @import("module.zig").ModuleSpec;

const Outputs = enum { Serial };

pub var Output = Outputs.Serial;

pub const Module = ModuleSpec{
    .init = init,
    .deinit = null,
};

pub var SerialPort: Ports.SerialPort = undefined;

pub fn init() void {
    SerialPort = Ports.SerialPort.new(0x3F8);
}

pub fn write_message(message: []const u8) void {
    switch (Output) {
        Outputs.Serial => SerialPort.write_string(message),
    }
}
