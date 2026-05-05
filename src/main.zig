const std = @import("std");
const libspng = @import("libspng");
const expect = std.testing.expect;

const SpngError = error{
    FailedToOpenFile,
    FailedToCloseFile,
    FailedToSetPngFile,
    FailedToCreateContext,
    FailedToGetImageHeader,
    FailedToCalcDecodedSize,
    FailedToDecodeImage,
    FailedToEncodeImage,
};
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

fn grayscaleImage(rgba_image_buffer: []u8) void {
    const red_coefficient: f16 = 0.2126;
    const green_coefficient: f16 = 0.7152;
    const blue_coefficient: f16 = 0.0722;

    var index: usize = 0;
    while (index < rgba_image_buffer.len) : (index += 4) {
        const weighted_red = red_coefficient * rgba_image_buffer[index];
        const weighted_green = green_coefficient * rgba_image_buffer[index + 1];
        const weighted_blue = blue_coefficient * rgba_image_buffer[index + 2];

        const brightness: f16 = weighted_red + weighted_green + weighted_blue;

        @memset(rgba_image_buffer[index .. index + 3], @intFromFloat(brightness));
    }
}

/// MUST FREE returned buffer
fn copyImageToBuffer(spng_context: *libspng.spng_ctx, image_buffer: []u8) SpngWithAllocError!void {
    const status = libspng.spng_decode_image(spng_context, image_buffer.ptr, image_buffer.len, libspng.SPNG_FMT_RGBA8, 0);
    if (status != 0) return SpngError.FailedToDecodeImage;
    std.debug.print("image buffer head: {any}\n", .{image_buffer[0..100]});
    // TODO: 왜 끝에는 다 0인지 모르겠다 -> rgba가 아니라 rgb로 해버려서
    std.debug.print("image buffer tail: {any}\n", .{image_buffer[(image_buffer.len - 100)..]});
}

fn createImageFromBuffer(spng_context: *libspng.spng_ctx, image_buffer: []u8) SpngWithAllocError!void {
    const status = libspng.spng_encode_image(spng_context, image_buffer.ptr, image_buffer.len, libspng.SPNG_FMT_PNG, libspng.SPNG_ENCODE_PROGRESSIVE);
    if (status != 0) return SpngWithAllocError.FailedToEncodeImage;
}

const OpenImageFileMode = enum { rb, wb };

/// NOTE: fclose the image file
fn openImageFile(
    relative_path: [:0]const u8,
    mode: OpenImageFileMode,
) SpngError!struct {
    image_file: *libspng.FILE,
    spng_context: *libspng.spng_ctx,
} {
    const image_file = libspng.fopen(relative_path, @tagName(mode));
    if (image_file == null) return SpngError.FailedToOpenFile;

    const context_flag = if (mode == .wb) libspng.SPNG_CTX_ENCODER else 0;
    const spng_context = libspng.spng_ctx_new(context_flag) orelse return SpngError.FailedToCreateContext;
    const status = libspng.spng_set_png_file(spng_context, image_file);
    if (status != 0) return SpngError.FailedToSetPngFile;

    return .{ .image_file = image_file, .spng_context = spng_context };
}
// defer {
//     const file_close_result = libspng.fclose(image_file);
//     if (file_close_result != 0) @panic("FAILED TO CLOSE FILE");
// }

pub fn main() SpngWithAllocError!void {
    // NOTE: rb - read binary
    const read_result = try openImageFile("src/assets/target-png-image.png", .rb);
    defer {
        const status = libspng.fclose(read_result.image_file);
        if (status != 0) @panic("FAILED TO CLOSE FILE");
    }
    defer libspng.spng_ctx_free(read_result.spng_context);

    var image_header = try getImageHeader(read_result.spng_context);
    const decoded_image_size = try calcDecodedImageSize(read_result.spng_context);

    var debugger_allocator = std.heap.DebugAllocator(.{}).init;
    const allocator = debugger_allocator.allocator();
    const image_buffer = try allocator.alloc(u8, decoded_image_size);
    @memset(image_buffer, 0);
    defer allocator.free(image_buffer);
    try copyImageToBuffer(read_result.spng_context, image_buffer);

    grayscaleImage(image_buffer);
    std.debug.print("grayscaled image buffer: {any}\n", .{image_buffer[0..100]});

    const write_result = try openImageFile("src/assets/grayscaled.png", .wb);
    defer libspng.spng_ctx_free(write_result.spng_context);
    defer {
        const status = libspng.fclose(write_result.image_file);
        if (status != 0) @panic("FAILED TO CLOSE FILE");
    }
    _ = libspng.spng_set_ihdr(write_result.spng_context, &image_header);

    const encode_status = libspng.spng_encode_image(
        write_result.spng_context,
        image_buffer.ptr,
        image_buffer.len,
        libspng.SPNG_FMT_PNG,
        libspng.SPNG_ENCODE_FINALIZE,
    );
    std.debug.print("encode status: {any}\n", .{encode_status});
}
