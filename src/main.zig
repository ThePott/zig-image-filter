const std = @import("std");
const libspng = @import("libspng");
const expect = std.testing.expect;

fn getImageHeader(spng_context_pointer: *libspng.spng_ctx) !void {
    var image_header: libspng.spng_ihdr = undefined;
    const image_header_result = libspng.spng_get_ihdr(spng_context_pointer, &image_header);
    std.debug.print("image header result: {any}\n", .{image_header_result});
    if (image_header_result != 0) @panic("FAILED TO GET IMAGE HEADER");
}

pub fn main() !void {
    // NOTE: rb - read binary
    const image_file = libspng.fopen("src/assets/target-png-image.png", "rb");
    if (image_file == null) {
        @panic("IMAGE NOT FOUND");
    }
    defer {
        const file_close_result = libspng.fclose(image_file);
        if (file_close_result != 0) @panic("FAILED TO CLOSE FILE");
    }

    std.debug.print("image file: {any}\n", .{image_file});

    // TODO: 도대체 뭐가 0이냐
    const spng_context = libspng.spng_ctx_new(0) orelse unreachable;
    const set_png_file_result = libspng.spng_set_png_file(spng_context, image_file);
    std.debug.print("set png file result: {any}\n", .{set_png_file_result});

    try getImageHeader(spng_context);
}
