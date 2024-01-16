const ModuleSpec = @import("../module.zig").ModuleSpec;
const Procedures = @import("../procedures.zig");
const PCI = @import("../pci/pci.zig");

pub const Module = ModuleSpec{
    .name = "USB Support",
    .init = init,
    .deinit = null,
};

pub fn init() void {
    const functions = PCI.getFunctions();
    for (functions) |function_wrapper| {
        const function = function_wrapper.function_ptr;
        if (function.class_code & 0xFFFF00 != 0x0C0300) continue;

        const usb_type: USBType = @enumFromInt(function.class_code & 0xFF);
        Procedures.write_fmt("USB Type: {}\n", .{usb_type}) catch {};
    }
}

const USBType = enum(u32) {
    UHCI = 0,
    OHCI = 0x10,
    EHCI = 0x20,
    XHCI = 0x30,
    USB4 = 0x40,
    Unspecified = 0x80,
    USBDevice = 0xFE,
};
