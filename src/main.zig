const std = @import("std");
const libspng = @import("libspng");
const expect = std.testing.expect;

const SpngError = error{ FailedToGetImageHeader, FailedToCalcDecodedSize };

fn getImageHeader(spng_context: *libspng.spng_ctx) SpngError!libspng.spng_ihdr {
    var image_header: libspng.spng_ihdr = undefined;
    const image_header_result = libspng.spng_get_ihdr(spng_context, &image_header);
    if (image_header_result != 0) return SpngError.FailedToGetImageHeader;

    return image_header;
}

fn calcDecodedImageSize(spng_context: *libspng.spng_ctx) usize {
    var output_size: usize = undefined;
    const output_size_result = libspng.spng_decoded_image_size(spng_context, libspng.SPNG_FMT_RGBA8, &output_size);
    if (output_size_result != 0) return SpngError.FailedToCalcDecodedSize;

    return output_size;
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

    // TODO: 도대체 뭐가 0이냐
    const spng_context = libspng.spng_ctx_new(0) orelse unreachable;
    const set_png_file_result = libspng.spng_set_png_file(spng_context, image_file);
    std.debug.print("set png file result: {any}\n", .{set_png_file_result});

    const image_header = try getImageHeader(spng_context);
    std.debug.print("image header: {any}\n", .{image_header});

    const decoded_image_size = calcDecodedImageSize(spng_context);
    std.debug.print("decoded image size: {any}\n", .{decoded_image_size});
}
