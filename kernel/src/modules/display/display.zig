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

pub const Color = packed struct(u32) {
    b: u8,
    g: u8,
    r: u8,
    _: u8 = 0,

    pub fn from_u32(i: u32) Color {
        return @as(*const Color, @ptrCast(&i)).*;
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

    pub fn fill(self: *const @This(), color: Color) void {
        for (0..self.width) |x| {
            for (0..self.height) |y| {
                self.setPixel(x, y, color.r, color.g, color.b, color._);
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

        display.backbuffer.fill(Color.from_u32(0x121212));
        display.swap();
    }
}

pub fn fade() void {
    var color: u8 = 0;
    if (main_display) |i| {
        while (true) {
            const display = displays[i];
            display.backbuffer.fill(Color{ .r = color, .g = color, .b = color });
            display.swap();
            color +%= 1;
        }
    }
}
