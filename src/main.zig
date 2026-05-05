const std = @import("std");
const libspng = @import("libspng");
const expect = std.testing.expect;

const SpngError = error{ FailedToGetImageHeader, FailedToCalcDecodedSize, FailedToDecodeImage };
const SpngWithAllocError = SpngError || error{OutOfMemory};

fn getImageHeader(spng_context: *libspng.spng_ctx) SpngError!libspng.spng_ihdr {
    var image_header: libspng.spng_ihdr = undefined;
    const image_header_result = libspng.spng_get_ihdr(spng_context, &image_header);
    if (image_header_result != 0) return SpngError.FailedToGetImageHeader;

    return image_header;
}

fn calcDecodedImageSize(spng_context: *libspng.spng_ctx) SpngError!usize {
    var output_size: usize = undefined;
    const output_size_result = libspng.spng_decoded_image_size(spng_context, libspng.SPNG_FMT_RGBA8, &output_size);
    if (output_size_result != 0) return SpngError.FailedToCalcDecodedSize;

    return output_size;
}

/// MUST FREE returned buffer
fn copyImageToBuffer(spng_context: *libspng.spng_ctx, image_buffer: []u8) SpngWithAllocError!void {
    const status = libspng.spng_decode_image(spng_context, image_buffer.ptr, image_buffer.len, libspng.SPNG_FMT_RGBA8, 0);
    if (status != 0) return SpngError.FailedToDecodeImage;
    std.debug.print("image buffer head: {any}\n", .{image_buffer[0..100]});
    // TODO: 왜 끝에는 다 0인지 모르겠다 -> rgba가 아니라 rgb로 해버려서
    std.debug.print("image buffer tail: {any}\n", .{image_buffer[(image_buffer.len - 100)..]});
}

pub fn main() SpngWithAllocError!void {
    // NOTE: rb - read binary
    const image_file = libspng.fopen("src/assets/target-png-image.png", "rb");
    if (image_file == null) {
        @panic("IMAGE NOT FOUND");
    }
    defer {
        const file_close_result = libspng.fclose(image_file);
        if (file_close_result != 0) @panic("FAILED TO CLOSE FILE");
    }

    // TODO: 도대체 뭐가 0이냐
    const spng_context = libspng.spng_ctx_new(0) orelse unreachable;
    const set_png_file_result = libspng.spng_set_png_file(spng_context, image_file);
    std.debug.print("set png file result: {any}\n", .{set_png_file_result});

    const image_header = try getImageHeader(spng_context);
    std.debug.print("image header: {any}\n", .{image_header});

    const decoded_image_size = try calcDecodedImageSize(spng_context);

    var debugger_allocator = std.heap.DebugAllocator(.{}).init;
    const allocator = debugger_allocator.allocator();
    const image_buffer = try allocator.alloc(u8, decoded_image_size);
    @memset(image_buffer, 0);
    defer allocator.free(image_buffer);
    try copyImageToBuffer(spng_context, image_buffer);
}
