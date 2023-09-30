package font
import "core:mem"
import "core:fmt"

TTF_Header :: struct {
    scalar_type: u32be,
    num_tables: u16be,
    search_range: u16be,
    entrySelector: u16be,
    rangeShift: u16be,
}


TTF_Table :: struct {
    tag: [4]u8,
    checkSum: u32be,
    offset: u32be,
    length: u32be,
}

TTF_Head :: struct{
    version: u32be,
    font_revision: u32be,
    check_sum_adjustment: u32be,
    magic_number: u32be,
    flags: u16be,
    units_per_em: u16be,
    created: [8]u8,
    modified: [8]u8,
    x_min: i16be,
    y_min: i16be,
    x_max: i16be,
    y_max: i16be,
    mac_style: u16be,
    lowest_rec_ppem: u16be,
    font_direction_hint: i16be,
    index_to_loc_format: i16be,
    glyph_data_format: i16be,
}

TTF_MAXP :: struct{
    version: u32be,
    num_glyphs: u16be,
    max_points: u16be,
    max_contours: u16be,
    max_composite_points: u16be,
    max_composite_contours: u16be,
    max_zones: u16be,
    max_twilight_points: u16be,
    max_storage: u16be,
    max_function_defs: u16be,
    max_instruction_defs: u16be,
    max_stack_elements: u16be,
    max_size_of_instructions: u16be,
    max_component_elements: u16be,
    max_component_depth: u16be,
}

TTF_HHEA :: struct{
    version: u32be,
    ascent: i16be,
    descent: i16be,
    line_gap: i16be,
    advance_width_max: u16be,
    min_left_side_bearing: i16be,
    min_right_side_bearing: i16be,
    x_max_extent: i16be,
    caret_slope_rise: i16be,
    caret_slope_run: i16be,
    caret_offset: i16be,
    reserved1: i16be,
    reserved2: i16be,
    reserved3: i16be,
    reserved4: i16be,
    metric_data_format: i16be,
    number_of_hmetrics: u16be,
}

TTF_CMAP :: struct{
    version: u16be,
    number_of_subtables: u16be,
}

TTF_CMAP_Subtable :: struct{
    platform_id: u16be,
    encoding_id: u16be,
    offset: u32be,
}

TTF_CMAP_Encoding_Record :: struct{
    platform_id: u16be,
    encoding_id: u16be,
    offset: u32be,
}

TTF_CMAP_Format4 :: struct{
    format: u16be,
    length: u16be,
    language: u16be,
    seg_count_x2: u16be,
    search_range: u16be,
    entry_selector: u16be,
    range_shift: u16be,
}

hmtx_entry :: struct{
    advance_width: u16be,
    left_side_bearing: i16be,
}

Glyph :: struct{
    number_of_contours: i16be,
    x_min: i16be,
    y_min: i16be,
    x_max: i16be,
    y_max: i16be,
}

ON_CURVE : u8 : 0x01
X_IS_BYTE : u8 : 0x02
Y_IS_BYTE : u8 : 0x04
REPEAT : u8 : 0x08
X_DELTA : u8 :0x10
Y_DELTA : u8 : 0x20

Glyph_Data :: struct{
    end_pts_of_contours: [dynamic]u16be,
    instruction_length: u16be,
    instructions: [dynamic]u8,
    flags: [dynamic]u8,
    x_coordinates: [dynamic]i16be,
    y_coordinates: [dynamic]i16be,
    x_coodinates_scaled: [dynamic]f32,
    y_coodinates_scaled: [dynamic]f32,
    advance_width: u16be,
    left_side_bearing: i16be,
    base_line_offset: i16be,
    x_min: i16be,
    y_min: i16be,
    x_max: i16be,
    y_max: i16be,
}



load_font :: proc(ttf_data: []u8, font_size: u32 = 32, img_size: i32 = 1024) -> (Rasterizer, [dynamic]BakedChar) {

    r := create_rasterizer(img_size, img_size) 
    // bmp_clear(, 255, 0, 0, 255)

    backed_chars: = make([dynamic]BakedChar, 96) // 32..126 is 95 glyphs


    offset := 0
    buffer := raw_data(ttf_data[0:])
    // fmt.println("buffer size: ", len(ttf_data))

    // header
    header := cast(^TTF_Header)buffer[offset:]
    offset += size_of(TTF_Header)

    // fmt.println(header)

    
    // needed tables
    head_table : ^TTF_Table
    loca_table : ^TTF_Table
    maxp_table : ^TTF_Table
    glyf_table : ^TTF_Table
    cmap_table : ^TTF_Table
    hmtx_table : ^TTF_Table
    hhea_table : ^TTF_Table
    
    
    // iterating tables
    for i := 0; i < int(header.num_tables); i+= 1 {
        table := cast(^TTF_Table)(buffer[offset:])
        offset += size_of(TTF_Table)

        // head table
        if table.tag[0] == 'h' && table.tag[1] == 'e' && table.tag[2] == 'a' && table.tag[3] == 'd' {
            head_table = table
        }

        // loca table
        if table.tag[0] == 'l' && table.tag[1] == 'o' && table.tag[2] == 'c' && table.tag[3] == 'a' {
            loca_table = table
        }

        // maxp table
        if table.tag[0] == 'm' && table.tag[1] == 'a' && table.tag[2] == 'x' && table.tag[3] == 'p' {
            maxp_table = table
        }

        // glyf table
        if table.tag[0] == 'g' && table.tag[1] == 'l' && table.tag[2] == 'y' && table.tag[3] == 'f' {
            glyf_table = table
        }

        // cmap table
        if table.tag[0] == 'c' && table.tag[1] == 'm' && table.tag[2] == 'a' && table.tag[3] == 'p' {
            cmap_table = table
        }

        // htmx table
        if table.tag[0] == 'h' && table.tag[1] == 'm' && table.tag[2] == 't' && table.tag[3] == 'x' {
            hmtx_table = table
        }

        // hhea table
        if table.tag[0] == 'h' && table.tag[1] == 'h' && table.tag[2] == 'e' && table.tag[3] == 'a' {
            hhea_table = table
        }
    }

    // head table
    // fmt.println(head_table)

    head := cast(^TTF_Head)(buffer[head_table.offset:])

    // parse cmap table
    c_to_unicode := parse_cmap_table(buffer, cmap_table)

    // parse hhea
    hhea := cast(^TTF_HHEA)(buffer[hhea_table.offset:])
    // fmt.println("HHEA!!!!!")
    // fmt.println(hhea)

    h_entires := [dynamic]hmtx_entry{}
    defer delete(h_entires)

    hmtx_table_offset := int(hmtx_table.offset)
    for i := 0; i < int(hhea.number_of_hmetrics); i += 1 {
        entry := cast(^hmtx_entry)(buffer[hmtx_table_offset + size_of(hmtx_entry) * i:])
        append(&h_entires, entry^)
    }


    // maxp
    maxp := cast(^TTF_MAXP)(buffer[maxp_table.offset:])
    glyph_count := int(maxp.num_glyphs)

    glyf_table_offset := int(glyf_table.offset)
    loca_table_offset := int(loca_table.offset)

    glyph_info := Glyph_Data{}
    defer delete(glyph_info.end_pts_of_contours)
    defer delete(glyph_info.instructions)
    defer delete(glyph_info.flags)
    defer delete(glyph_info.x_coordinates)
    defer delete(glyph_info.y_coordinates)
    defer delete(glyph_info.x_coodinates_scaled)
    defer delete(glyph_info.y_coodinates_scaled)


    for i := 0; i < glyph_count; i += 1 {
        glyf_offset := 0

        clear_dynamic_array(&glyph_info.end_pts_of_contours)
        clear_dynamic_array(&glyph_info.instructions)
        clear_dynamic_array(&glyph_info.flags)
        clear_dynamic_array(&glyph_info.x_coordinates)
        clear_dynamic_array(&glyph_info.y_coordinates)
        clear_dynamic_array(&glyph_info.x_coodinates_scaled)
        clear_dynamic_array(&glyph_info.y_coodinates_scaled)


        if head.index_to_loc_format == 0 {
            glyf_offset = glyf_table_offset + int((cast(^u16be)(buffer[loca_table_offset + i * 2:]))^ * 2)
        } else {
            glyf_offset = glyf_table_offset + int((cast(^u32be)(buffer[loca_table_offset + i * 4:]))^)
        }


        glyph := cast(^Glyph)(buffer[glyf_offset:])
        if glyph.number_of_contours <= 0 {
            // compound glyph
            continue
        }
        if glyph.x_min >= glyph.x_max || glyph.y_min >= glyph.y_max {
            // empty glyph
            continue
        }

        // fmt.println(glyph.number_of_contours, glyph.x_min, glyph.y_min, glyph.x_max, glyph.y_max)

        // get character code
        unicode := 0
        for c in c_to_unicode {
            if c.codepoint == i {
                unicode = c.unicode
                break
            }
        }
        if unicode == 0 {
            // fmt.println("no unicode for glyph", i)
            continue
        }



        offset = glyf_offset + size_of(Glyph)
        for j := 0; j < int(glyph.number_of_contours); j += 1 {
            contour_end := cast(^u16be)(buffer[offset:])
            append(&glyph_info.end_pts_of_contours, contour_end^)
            offset += 2
        }


        instruction_length := cast(^u16be)(buffer[offset:])
        offset += 2

        for j := 0; j < int(instruction_length^); j += 1 {
            instruction := buffer[offset]
            append(&glyph_info.instructions, instruction)
            offset += 1
        }

        num_points := glyph_info.end_pts_of_contours[glyph.number_of_contours - 1] + 1

        // fmt.println(glyph_info.end_pts_of_contours)

        // flags
        for j := 0; j < int(num_points); j += 1 {
            flag := buffer[offset]
            append(&glyph_info.flags, flag)
            offset += 1

            if flag & REPEAT != 0 {
                repeat_count := buffer[offset]
                offset += 1
                for k := 0; k < int(repeat_count); k += 1 {
                    append(&glyph_info.flags, flag)
                }
            }
        }

        // x coordinates
        for j := 0; j < int(num_points); j += 1{
            is_i8 := (glyph_info.flags[j] & 2) != 0
            is_same := (glyph_info.flags[j] & 16) != 0
            if is_i8{
                if is_same {
                    append(&glyph_info.x_coordinates, i16be(buffer[offset:][0]))
                } else {
                    append(&glyph_info.x_coordinates, i16be(-buffer[offset:][0]))
                }
                offset += 1
            } else {
                if is_same {
                    append(&glyph_info.x_coordinates, 0)
                } else {
                    append(&glyph_info.x_coordinates, ((^i16be)(buffer[offset:]))^)
                }
                offset += 2
            }
        }
        // y coordinates
        for j := 0; j < int(num_points); j += 1{
            is_i8 := (glyph_info.flags[j] & 4) != 0
            is_same := (glyph_info.flags[j] & 32) != 0
            if is_i8{
                if is_same {
                    append(&glyph_info.y_coordinates, i16be(buffer[offset:][0]))
                } else {
                    append(&glyph_info.y_coordinates, i16be(-buffer[offset:][0]))
                }
                offset += 1
            } else {
                if is_same {
                    append(&glyph_info.y_coordinates, 0)
                } else {
                    append(&glyph_info.y_coordinates, ((^i16be)(buffer[offset:]))^)
                }
                offset += 2
            }
        }
        

        x :i16be = 0
        y :i16be = 0
        for j := 0; j < int(num_points); j += 1{
            x += glyph_info.x_coordinates[j] 
            y += glyph_info.y_coordinates[j]
            glyph_info.x_coordinates[j] = x
            glyph_info.y_coordinates[j] = y
        }


        
            
            
        scale := f32(font_size) / f32(head.units_per_em)

        last_contour := 0
        for contours in &glyph_info.end_pts_of_contours {
            contours := int(contours)
            for i := last_contour; i <= contours; i += 1{
                x := glyph_info.x_coordinates[i]
                y := glyph_info.y_coordinates[i]
                x -= glyph.x_min
                y -= glyph.y_min
                new_x := f32(x) * scale
                new_y := f32(y) * scale

                append(&glyph_info.x_coodinates_scaled, new_x)
                append(&glyph_info.y_coodinates_scaled, new_y)
            }
            
            
            x1 := glyph_info.x_coordinates[last_contour]
            y1 := glyph_info.y_coordinates[last_contour]
            x1 -= glyph.x_min
            y1 -= glyph.y_min
            new_x1 := f32(x1) * scale
            new_y1 := f32(y1) * scale   
            
            append(&glyph_info.x_coodinates_scaled, new_x1)
            append(&glyph_info.y_coodinates_scaled, new_y1)
            
            last_contour = int(contours) + 1
        } 

        for contours, i in &glyph_info.end_pts_of_contours {
            contours += 1 * (u16be(i + 1))
        }


        
        // fmt.println(len(glyph_info.x_coordinates))
        // fmt.println(len(glyph_info.y_coordinates))
        // fmt.println(len(glyph_info.x_coodinates_scaled))
        // fmt.println(len(glyph_info.y_coodinates_scaled))

        glyph_info.x_min = glyph.x_min
        glyph_info.y_min = glyph.y_min
        glyph_info.x_max = glyph.x_max
        glyph_info.y_max = glyph.y_max
        glyph_info.advance_width = h_entires[i].advance_width
        glyph_info.left_side_bearing = h_entires[i].left_side_bearing



        if unicode >= 32 && unicode <= 126 {
            baked_char := rasterize_char(&r, &glyph_info, scale, unicode)
            backed_chars[unicode - 32] = baked_char
        }
    }


    return r, backed_chars
}

codepoint_to_unicode :: struct{
    codepoint: int,
    unicode: int,
}

parse_cmap_table :: proc(buffer: [^]u8, table: ^TTF_Table) -> [dynamic]codepoint_to_unicode{
    cmap := cast(^TTF_CMAP)(buffer[table.offset:])
    // fmt.println(cmap)

    assert(cmap.version == 0, "unsupported cmap version")

    // encoding_records: [dynamic]TTF_CMAP_Encoding_Record

    table_offset := int(table.offset)
    for i := 0; i < int(cmap.number_of_subtables); i += 1 {
        encoding_record := cast(^TTF_CMAP_Encoding_Record)(buffer[table_offset + size_of(TTF_CMAP) + i * size_of(TTF_CMAP_Encoding_Record):])

        is_windows_platform := encoding_record.platform_id == 3
        is_unicode_encoding := encoding_record.encoding_id == 1

        offset := table_offset + int(encoding_record.offset)

        if is_windows_platform && is_unicode_encoding {
            subtable := cast(^TTF_CMAP_Subtable)(buffer[offset:])

            format := cast(^u16be)(buffer[offset:])

            if format^ == 4 {
                return parse_cmap_format4(buffer, offset)
            }
        }
    }
    return nil
}

parse_cmap_format4 :: proc(buffer: [^]u8, offset: int) -> [dynamic]codepoint_to_unicode{
    offset := offset

    subtable := cast(^TTF_CMAP_Format4)(buffer[offset:])

    offset += size_of(TTF_CMAP_Format4)

    end_codes: [dynamic]u16be
    start_codes: [dynamic]u16be
    id_deltas: [dynamic]i16be
    id_range_offsets: [dynamic]u16be
    glyph_id_array: [dynamic]codepoint_to_unicode

    defer delete(end_codes)
    defer delete(start_codes)
    defer delete(id_deltas)
    defer delete(id_range_offsets)
    // defer delete(glyph_id_array)

    seg_count := int(subtable.seg_count_x2 / 2)

    for i := 0; i < seg_count; i += 1 {
        append(&end_codes, (cast(^u16be)(buffer[offset:]))^)
        offset += 2
    }

    //reserve pad
    offset += 2

    for i := 0; i < seg_count; i += 1 {
        append(&start_codes, (cast(^u16be)(buffer[offset:]))^)
        offset += 2
    }

    for i := 0; i < seg_count; i += 1 {
        append(&id_deltas, (cast(^i16be)(buffer[offset:]))^)
        offset += 2
    }

    id_range_offset_start := offset

    for i := 0; i < seg_count; i += 1 {
        append(&id_range_offsets, (cast(^u16be)(buffer[offset:]))^)
        offset += 2
    }

    for i := 0; i < seg_count - 1; i += 1 {
        glyph_index : int = 0
        end_code := int(end_codes[i])
        start_code := int(start_codes[i])
        id_delta := int(id_deltas[i])
        id_range_offset := int(id_range_offsets[i])

        for c := start_code; c <= end_code; c += 1 {
            if id_range_offset != 0 {
                start_code_offset := int((c - start_code)) * 2
                current_range_offset := i * 2

                glyph_index_offset := id_range_offset_start + current_range_offset + id_range_offset + start_code_offset 
                glyph_index = int((cast(^u16be)(buffer[glyph_index_offset:]))^)

                if glyph_index != 0 {
                    glyph_index = (glyph_index + id_delta) & 0xffff
                }
            }
            else {
                glyph_index = (c + id_delta) & 0xffff
            }

            append(&glyph_id_array, codepoint_to_unicode{glyph_index, c})
        }
    }

    return glyph_id_array
}

