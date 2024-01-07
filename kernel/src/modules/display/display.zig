const ModuleSpec = @import("../module.zig").ModuleSpec;
const Procedures = @import("../procedures.zig");
const PhysAlloc = @import("../phys_alloc.zig");

const Limine = @import("limine");

pub export var FramebufferRequest: Limine.FramebufferRequest = .{};

pub const Module = ModuleSpec{
    .name = "Display",
    .init = init,
    .deinit = null,
};

pub const Display = struct {
    width: u64,
    height: u64,
    framebuffer: []u8,
    backbuffer: Framebuffer,

    pub fn swap(self: *const @This()) void {
        @memcpy(self.framebuffer, self.backbuffer.data);
        @memset(self.backbuffer.data, 0);
    }
};

pub const Framebuffer = struct {
    width: u64,
    height: u64,
    data: []u8,
    pitch: u64,

    pub fn clear(self: *const @This()) void {
        for (0..self.width) |x| {
            for (0..self.height) |y| {
                self.setPixel(x, y, 0, 0, 0, 0);
            }
        }
    }

    pub inline fn setPixel(self: *const @This(), x: u64, y: u64, r: u8, g: u8, b: u8, a: u8) void {
        self.data[x * 4 + y * self.pitch] = r;
        self.data[x * 4 + 1 + y * self.pitch] = g;
        self.data[x * 4 + 2 + y * self.pitch] = b;
        self.data[x * 4 + 3 + y * self.pitch] = a;
    }
};

var displays: [4]Display = undefined;
var main_display: ?usize = null;

pub fn init() void {
    if (FramebufferRequest.response == null) {
        Procedures.write_fmt("No display attached\n", .{}) catch {};
        return;
    }

    const response = FramebufferRequest.response.?;

    for (0..response.framebuffer_count) |i| {
        const framebuffer = response.framebuffers_ptr[i];

        if (framebuffer.bpp != 32) {
            Procedures.write_fmt("BPP not supported: {}\n", .{framebuffer.bpp}) catch {};
            continue;
        }

        const backbuffer = PhysAlloc.allocator().alloc(u8, framebuffer.width * framebuffer.height * (framebuffer.bpp / 8)) catch {
            return;
        };

        Procedures.write_fmt("{}, X: {}, Y: {}\n", .{ framebuffer, backbuffer.len, framebuffer.data().len }) catch {};

        const display = Display{
            .height = framebuffer.height,
            .width = framebuffer.width,
            .backbuffer = Framebuffer{
                .width = framebuffer.width,
                .height = framebuffer.height,
                .data = backbuffer,
                .pitch = framebuffer.pitch,
            },
            .framebuffer = framebuffer.data(),
        };

        main_display = i;

        displays[i] = display;
    }

    if (main_display) |i| {
        const display = displays[i];

        Procedures.write_fmt("Test\n", .{}) catch {};
        display.backbuffer.clear();
        Procedures.write_fmt("Test\n", .{}) catch {};
        display.backbuffer.setPixel(0, 0, 255, 255, 255, 0);
        Procedures.write_fmt("Test\n", .{}) catch {};
        display.swap();
        Procedures.write_fmt("Test\n", .{}) catch {};
    }
}
