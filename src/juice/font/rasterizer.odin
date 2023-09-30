package font

import "core:os"
import "core:fmt"


// BMP_Header :: struct #packed {
//     type: u16,
//     fileSize  : u32,
//     reserved : u32,
//     dataOffset: u32,
//     headerSize: u32,
//     width     : i32,
//     height    : i32,
//     planes    : u16,
//     bitCount  : u16,
//     compression: u32,
//     imageSize : u32,
//     xPixelsPerMeter: i32,
//     yPixelsPerMeter: i32,
//     colorsUsed: u32,
//     importantColors: u32,
// }

// OLD BMP RASTERIZER
// Rasterizer :: struct{
//     width: i32,
//     height: i32,
//     full_data_with_head: []u8,
//     data: [^]u8,
//     current_y: i32,
//     current_x: i32,
//     current_max_height: i32,
// }

// DELETE STUFF TOO
// create_rasterizer :: proc(width, height : i32) -> Rasterizer {
//     bmp := make([]u8, size_of(BMP_Header) + width * height * 4)
//     data := raw_data(bmp)
//     header := cast(^BMP_Header)(data[0:])
//     header.type = 0x4D42
//     header.dataOffset = size_of(BMP_Header)
//     header.fileSize = u32(size_of(BMP_Header) + width * height * 4)
//     header.headerSize = 40 
//     header.width = i32(width)
//     header.height = i32(height)
//     header.planes = 1
//     header.bitCount = 32
//     header.compression = 0
//     header.imageSize = u32(width * height * 4)
//     header.xPixelsPerMeter = 0
//     header.yPixelsPerMeter = 0
//     header.colorsUsed = 0
//     header.importantColors = 0

//     // remember this has bgra format
//     // but we're only setting alpha

//     return Rasterizer{
//         width =  width,
//         height = height,
//         full_data_with_head = bmp,
//         data = data[size_of(BMP_Header):],
//     }
// }

// write_to_file :: proc(r: ^Rasterizer, path: string) {
//     os.write_entire_file(path, r.full_data_with_head)
// }

Rasterizer :: struct{
    width: i32,
    height: i32,
    data: []u8,
    current_y: i32,
    current_x: i32,
    current_max_height: i32,
}

create_rasterizer :: proc(width, height : i32) -> Rasterizer {
    data := make([]u8, width * height * 4)

    return Rasterizer{
        width =  width,
        height = height,
        data = data,
    }
}



put_pixel :: proc(ra: ^Rasterizer, x, y: i32, r,g,b,a: u8) {
    if x < 0 || y < 0 || x >= ra.width || y >= ra.height {
        return
    }

    offset := (y * ra.width + x) * 4
    ra.data[offset] = b
    ra.data[offset + 1] = g
    ra.data[offset + 2] = r
    ra.data[offset + 3] = a
}

put_line :: proc (ra: ^Rasterizer, x1,y1,x3,x4: i32, r,g,b,a: u8){
    x1 := x1
    y1 := y1
    x2 := x3
    y2 := x4

    dx := abs(x2 - x1)
    dy := abs(y2 - y1)

    sx :i32= -1
    if x1 < x2 {
        sx = 1
    }

    sy :i32= -1
    if y1 < y2 {
        sy = 1
    }

    err := dx - dy

    for {
        put_pixel(ra, x1, y1, r,g,b,a)

        if x1 == x2 && y1 == y2 {
            break
        }

        e2 := 2 * err

        if e2 > -dy {
            err -= dy
            x1 += sx
        }

        if e2 < dx {
            err += dx
            y1 += sy
        }
    }
}

// https://gist.github.com/gszauer/0add6695a4c1ccd617b3f4f9e1e9a3c6

BakedChar :: struct {
	x0:       f32,
	y0:       f32,
	x1:       f32,
	y1:       f32,
	xoff:     f32,
	yoff:     f32,
	xadvance: f32,
}

rasterize_char :: proc(r: ^Rasterizer,glyph_data: ^Glyph_Data, scale: f32, unicode: int) -> BakedChar{

    last_contour := 0
    // fmt.printf("%#v",glyph_data)

    width := i32(f32(glyph_data.x_max - glyph_data.x_min) * scale)
    height := i32(f32(glyph_data.y_max - glyph_data.y_min) * scale)

    if height > r.current_max_height {
        r.current_max_height = height
    }

    if r.current_x + width > r.width {
        r.current_x = 0
        r.current_y += r.current_max_height + 2
        r.current_max_height = 0

        if r.current_y + height > r.height {
            panic("ttf: not enough space in rasterizer")
        }
    }

    start_x := r.current_x
    start_y := r.current_y


    // outline don't need
    // for contours, c_index in glyph_data.end_pts_of_contours{
    //     contours := int(contours)

    //     for i:= last_contour; i < contours; i += 1{
    //         x1 := f32(glyph_data.x_coodinates_scaled[i])
    //         y1 := f32(glyph_data.y_coodinates_scaled[i])
    //         x2 := f32(glyph_data.x_coodinates_scaled[i + 1])
    //         y2 := f32(glyph_data.y_coodinates_scaled[i + 1])

    //         // put_line(r, start_x + i32(x1), start_y + i32(y1), start_x + i32(x2), start_y + i32(y2), 255, 255, 255, 255)
    //     }


    //     last_contour = contours + 1
    // }

    if unicode != 32{
        fill_outline(r, glyph_data, start_x, start_y, start_x + width, start_y + height)
    }


    x0 := r.current_x
    y0 := r.current_y
    x1 := x0 + width
    y1 := y0 + height + 2
    xoff := f32(glyph_data.x_min) * scale
    yoff := f32(glyph_data.y_min) * scale
    xadvance := f32(glyph_data.advance_width) * scale

     r.current_x += i32(xadvance)

    return BakedChar{
        f32(x0),
        f32(r.height - y1),
        f32(x1),
        f32(r.height - y0),
        xoff,
        -yoff - f32(height),
        xadvance,
    }
}

fill_outline :: proc (r: ^Rasterizer, g: ^Glyph_Data, start_x, start_y, max_x, max_y: i32){
    data := r.data

    inside := false
    for y := start_y; y <= max_y; y += 1 {
        inside = false
        for x := start_x; x <= max_x; x += 1 {
            // Flip the y-coordinate while writing pixel data
            offset := ((r.height - y - 1) * r.width + x) * 4

            if is_point_inside(f32(x) - f32(start_x), f32(y) - f32(start_y), g){
                data[offset] = 255
                data[offset + 1] = 255
                data[offset + 2] = 255
                data[offset + 3] = 255
            }
        }
    }
}

is_point_inside :: proc(x,y: f32, glyph_data: ^Glyph_Data) -> bool{
    winding := 0
    last_contour := 0
    for contours, c_index in glyph_data.end_pts_of_contours{
        contours := int(contours)
        for i:= last_contour; i < contours; i += 1{
            x1 := f32(glyph_data.x_coodinates_scaled[i])
            y1 := f32(glyph_data.y_coodinates_scaled[i])
            x2 := f32(glyph_data.x_coodinates_scaled[i + 1])
            y2 := f32(glyph_data.y_coodinates_scaled[i + 1])

            if y1 <= y{
                if y2 > y{
                    if is_left(x1, y1, x2, y2, x, y) > 0{
                        winding += 1
                    }
                }
            }
            else{
                if y2 <= y{
                    if is_left(x1, y1, x2, y2, x, y) < 0{
                        winding -= 1
                    }
                }
            }
        }

        last_contour = contours + 1
    }

    return winding != 0
}

is_left :: proc(x1, y1, x2, y2, x, y: f32) -> f32{
    return (x2 - x1) * (y - y1) - (x - x1) * (y2 - y1)
}
