package juice

import "core:fmt"
import image "core:image"
import png "core:image/png"

import glm "core:math/linalg/glsl"
import "core:strings"
import "core:mem"
import "core:unicode/utf8"
import "core:strconv"

import "font"


when ODIN_OS == .Windows do import gl "vendor:OpenGL"
when ODIN_OS == .JS do import gl "vendor:wasm/WebGL"

Color :: [4]f32

Origin_Top_Left :: Vec2 {0, 0}
Origin_Top_Right :: Vec2 {1, 0}
Origin_Bottom_Left :: Vec2 {0, 1}
Origin_Bottom_Right :: Vec2 {1, 1}
Origin_Center :: Vec2 {0.5, 0.5}
Origin_Center_Left :: Vec2 {0, 0.5}
Origin_Center_Right :: Vec2 {1, 0.5}
Origin_Top_Center :: Vec2 {0.5, 0}
Origin_Bottom_Center :: Vec2 {0.5, 1}

when ODIN_OS == .Windows {
	_load_gl :: proc(set_proc_adress: proc(p: rawptr, name: cstring)) {
		gl.load_up_to(4, 1, set_proc_adress)
	}

	_load_shaders_source :: proc(vs_source, fs_source: string) -> (program_id: u32, ok: bool) {
		return gl.load_shaders_source(vs_source, fs_source)
	}
}
when ODIN_OS == .JS {
	_load_gl :: proc() {
		gl.SetCurrentContextById(CANVAS_ID)
	}

	_load_shaders_source :: proc(
		vs_source, fs_source: string,
	) -> (
		program_id: gl.Program,
		ok: bool,
	) {
		program := gl.CreateProgram()
		vs := gl.CreateShader(gl.VERTEX_SHADER)
		fs := gl.CreateShader(gl.FRAGMENT_SHADER)

		gl.ShaderSource(vs, {vs_source})
		gl.ShaderSource(fs, {fs_source})

		gl.CompileShader(vs)
		gl.CompileShader(fs)

		if gl.GetShaderiv(vs, gl.COMPILE_STATUS) == 0 {
			fmt.println("Failed to compile vertex shader")
			buf: [4096]byte
			log := gl.GetShaderInfoLog(vs, buf[:])
			fmt.println(log)
			return 0, false
		}

		if gl.GetShaderiv(fs, gl.COMPILE_STATUS) == 0 {
			fmt.println("Failed to compile fragment shader")
			buf: [4096]byte
			log := gl.GetShaderInfoLog(fs, buf[:])
			fmt.println(log)
			return 0, false
		}

		gl.AttachShader(program, vs)
		gl.AttachShader(program, fs)

		gl.LinkProgram(program)

		if gl.GetProgramParameter(program, gl.LINK_STATUS) == 0 {
			fmt.println("Failed to link program")
			buf: [4096]byte
			log := gl.GetProgramInfoLog(program, buf[:])
			fmt.println(log)
			return 0, false
		}

		gl.DeleteShader(vs)
		gl.DeleteShader(fs)

		return program, true
	}
}

Vertex :: struct {
	mesh_pos: [3]f32,
	color:    [4]f32,
	uv:       [2]f32,
	tex:      i32,
	pos:      Vec2,
	rot:      f32,
	scale:    Vec2,
}

when ODIN_OS == .Windows {
	Graphics :: struct {
		vertices:                  [dynamic]Vertex,
		vertices_index:            [dynamic]u32,
		projection_location:       i32,
		view_matrix_location:      i32,
		texture_location:          i32,
		vertex_gl_buffer:          u32,
		index_gl_buffer:           u32,
		vao:                       u32,
		last_size:                 [2]f32,
		textures:                  [dynamic]Texture,
		textures_current_bindings: [16]i32,
		fonts:                     [dynamic]Font,
		chars_to_draw:             [dynamic]Char_To_Draw,
		default_camera:            Camera,
	}
}
when ODIN_OS == .JS {
	Graphics :: struct {
		vertices:                  [dynamic]Vertex,
		vertices_index:            [dynamic]u32,
		projection_location:       i32,
		view_matrix_location:      i32,
		texture_location:          i32,
		vertex_gl_buffer:          gl.Buffer,
		index_gl_buffer:           gl.Buffer,
		vao:                       gl.VertexArrayObject,
		last_size:                 [2]f32,
		textures:                  [dynamic]Texture,
		textures_current_bindings: [16]i32,
		fonts:                     [dynamic]Font,
		chars_to_draw:             [dynamic]Char_To_Draw,
		default_camera:            Camera,
	}
}

GRAPHICS : Graphics

_init_resources :: proc() {
	vert := `#version 300 es
    precision mediump float;

    layout(location = 0) in vec3 aVertexMeshPos;
    layout(location = 1) in vec4 aVertexColor;
    layout(location = 2) in vec2 aVertexUV;
	layout(location = 3) in int aVertexTextureIndex;
	layout(location = 4) in vec2 aVertexPos;
	layout(location = 5) in vec2 aVertexScale;
	layout(location = 6) in float aVertexRot;


	uniform mat4 uProjection;
	uniform mat4 uViewMatrix;

    out vec4 fColor;
	out vec2 fVertexUV;
	flat out int fTexIndex;

    void main(void) {

		vec3 pos = aVertexMeshPos;
		pos *= vec3(aVertexScale, 1.0);
		pos = vec3(
			pos.x * cos(aVertexRot) - pos.y * sin(aVertexRot),
			pos.x * sin(aVertexRot) + pos.y * cos(aVertexRot),
			0	
		);
		pos += vec3(aVertexPos, 0);

        fColor = aVertexColor;
		fVertexUV = aVertexUV;
		fTexIndex = int(aVertexTextureIndex);
        gl_Position = uProjection * uViewMatrix * vec4(pos, 1.0);
    }`
	frag := `#version 300 es
    precision mediump float;

	uniform sampler2D uTextures[16];

    in vec4 fColor;
	in vec2 fVertexUV;
	flat in int fTexIndex;

    out vec4 fragColor;

    void main(void) {
		vec4 tex;
		if (fTexIndex == 0) {
			tex = texture(uTextures[0], fVertexUV);
		} else if (fTexIndex == 1) {
			tex = texture(uTextures[1], fVertexUV);
		} else if (fTexIndex == 2) {
			tex = texture(uTextures[2], fVertexUV);
		} else if (fTexIndex == 3) {
			tex = texture(uTextures[3], fVertexUV);
		} else if (fTexIndex == 4) {
			tex = texture(uTextures[4], fVertexUV);
		} else if (fTexIndex == 5) {
			tex = texture(uTextures[5], fVertexUV);
		} else if (fTexIndex == 6) {
			tex = texture(uTextures[6], fVertexUV);
		} else if (fTexIndex == 7) {
			tex = texture(uTextures[7], fVertexUV);
		} else if (fTexIndex == 8) {
			tex = texture(uTextures[8], fVertexUV);
		} else if (fTexIndex == 9) {
			tex = texture(uTextures[9], fVertexUV);
		} else if (fTexIndex == 10) {
			tex = texture(uTextures[10], fVertexUV);
		} else if (fTexIndex == 11) {
			tex = texture(uTextures[11], fVertexUV);
		} else if (fTexIndex == 12) {
			tex = texture(uTextures[12], fVertexUV);
		} else if (fTexIndex == 13) {
			tex = texture(uTextures[13], fVertexUV);
		} else if (fTexIndex == 14) {
			tex = texture(uTextures[14], fVertexUV);
		} else {
			tex = texture(uTextures[15], fVertexUV);
		}


        fragColor = tex * fColor;
    }
    `

	// set circle segments
	for i in 0 ..= CIRCLE_SEGMENTS {
		angle: f32 = f32(i) / f32(CIRCLE_SEGMENTS) * 2 * glm.PI
		x_cos: f32 = glm.cos(angle)
		y_sin: f32 = glm.sin(angle)
		CRICLE_SEGMENTS_COS_SIN[i] = Vec2{x_cos, y_sin}
	}

	AMOUNT_OF_VERTS :int= 200_000
	GRAPHICS.vertices = make([dynamic]Vertex, AMOUNT_OF_VERTS)
	GRAPHICS.vertices_index = make([dynamic]u32, AMOUNT_OF_VERTS / 3)
	GRAPHICS.textures_current_bindings = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1}

	prog_id, ok := _load_shaders_source(vert, frag)
	if !ok {
		fmt.println("Failed to load shaders")
		return
	}

	gl.UseProgram(prog_id)


	when ODIN_OS == .Windows {
		gl.GenVertexArrays(1, &GRAPHICS.vao)
		gl.BindVertexArray(GRAPHICS.vao)

		gl.GenBuffers(1, &GRAPHICS.vertex_gl_buffer)
		gl.BindBuffer(gl.ARRAY_BUFFER, GRAPHICS.vertex_gl_buffer)
		gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * 4 * AMOUNT_OF_VERTS, nil, gl.DYNAMIC_DRAW)

		gl.EnableVertexAttribArray(0)
		gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, mesh_pos))

		gl.EnableVertexAttribArray(1)
		gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))

		gl.EnableVertexAttribArray(2)
		gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

		gl.EnableVertexAttribArray(3)
		gl.VertexAttribIPointer(3, 1, gl.INT, size_of(Vertex), offset_of(Vertex, tex))

		gl.EnableVertexAttribArray(4)
		gl.VertexAttribPointer(4, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))

		gl.EnableVertexAttribArray(5)
		gl.VertexAttribPointer(5, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, scale))

		gl.EnableVertexAttribArray(6)
		gl.VertexAttribPointer(6, 1, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, rot))

		gl.GenBuffers(1, &GRAPHICS.index_gl_buffer)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, GRAPHICS.index_gl_buffer)
		gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u32) * 6 * AMOUNT_OF_VERTS, nil, gl.DYNAMIC_DRAW)
	}
	when ODIN_OS == .JS {
		GRAPHICS.vao = gl.CreateVertexArray()
		gl.BindVertexArray(GRAPHICS.vao)

		GRAPHICS.vertex_gl_buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ARRAY_BUFFER, GRAPHICS.vertex_gl_buffer)
		gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * 4 * AMOUNT_OF_VERTS, nil, gl.DYNAMIC_DRAW)

		gl.EnableVertexAttribArray(0)
		gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, mesh_pos))

		gl.EnableVertexAttribArray(1)
		gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))

		gl.EnableVertexAttribArray(2)
		gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

		gl.EnableVertexAttribArray(3)
		gl.VertexAttribIPointer(3, 1, gl.INT, size_of(Vertex), offset_of(Vertex, tex))

		gl.EnableVertexAttribArray(4)
		gl.VertexAttribPointer(4, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))

		gl.EnableVertexAttribArray(5)
		gl.VertexAttribPointer(5, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, scale))

		gl.EnableVertexAttribArray(6)
		gl.VertexAttribPointer(6, 1, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, rot))

		GRAPHICS.index_gl_buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, GRAPHICS.index_gl_buffer)
		gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u32) * 6 * AMOUNT_OF_VERTS, nil, gl.DYNAMIC_DRAW)
	}

	GRAPHICS.projection_location = gl.GetUniformLocation(prog_id, "uProjection")
	GRAPHICS.view_matrix_location = gl.GetUniformLocation(prog_id, "uViewMatrix")

	for i := 0; i < 16; i += 1 {
		name := fmt.tprintf("uTextures[%d]", i)

		when ODIN_OS == .Windows {
			c_string := strings.clone_to_cstring(name)

			loc := gl.GetUniformLocation(prog_id, c_string)
			gl.Uniform1i(loc, auto_cast i)

			delete(c_string)
		}
		when ODIN_OS == .JS {
			loc := gl.GetUniformLocation(prog_id, name)
			gl.Uniform1i(loc, auto_cast i)
		}

	}

	// enable transparency
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	// gl.BlendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ZERO, gl.ONE);
	// gl.Enable(gl.ALPHA_TEST)

	// 1x1 white pixel png
	//odinfmt: disable
	data :[]u8 = {
		0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 
		0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 
		0x89, 0x00, 0x00, 0x00, 0x01, 0x73, 0x52, 0x47, 0x42, 0x00, 0xAE, 0xCE, 0x1C, 0xE9, 0x00, 0x00, 
		0x00, 0x04, 0x67, 0x41, 0x4D, 0x41, 0x00, 0x00, 0xB1, 0x8F, 0x0B, 0xFC, 0x61, 0x05, 0x00, 0x00, 
		0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00, 0x0E, 0xC3, 0x00, 0x00, 0x0E, 0xC3, 0x01, 0xC7, 
		0x6F, 0xA8, 0x64, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x18, 0x57, 0x63, 0xF8, 0xFF, 
		0xFF, 0xFF, 0x7F, 0x00, 0x09, 0xFB, 0x03, 0xFD, 0x05, 0x43, 0x45, 0xCA, 0x00, 0x00, 0x00, 0x00, 
		0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82}
	//odinfmt: enable 
	load_texture(data)


	w, h := window_width(), window_height()
	GRAPHICS.default_camera = create_camera({0, 0, w, h})
	use_camera(GRAPHICS.default_camera)
}

_check_window_size :: proc() {
	w, h := window_width(), window_height()
	if GRAPHICS.last_size.x != w || GRAPHICS.last_size.y != h {
		gl.Viewport(0, 0, auto_cast w, auto_cast h)
		GRAPHICS.last_size.x = w
		GRAPHICS.last_size.y = h


		GRAPHICS.default_camera.rect = {0, 0, w, h}
	}
}


when ODIN_OS == .Windows {
	Texture :: struct {
		id:     u32,
		gl_id:  u32,
		width:  i32,
		height: i32,
		uv:  	Rect,
	}
}
when ODIN_OS == .JS {
	Texture :: struct {
		id:     u32,
		gl_id:  gl.Texture,
		width:  i32,
		height: i32,
		uv:  	Rect,
	}
}


load_texture :: proc(png_bytes: []u8, filter: TexFilter = TexFilter.Nearest) -> u32 {
	img, err := png.load_from_bytes(png_bytes)
	assert(err == nil, "Failed to load image. Is it a valid PNG?")
	assert(img.depth == 8, "Image depth must be 8 bits per channel.")
	defer image.destroy(img)

	gl_filter := gl.NEAREST
	if filter == TexFilter.Linear {
		gl_filter = gl.LINEAR
	}

	gl_internal_format: u32
	gl_format: u32
	switch img.channels {
	case 1:
		gl_format = auto_cast gl.RED
		gl_internal_format = auto_cast gl.R8
	case 2:
		gl_format = auto_cast gl.RG
		gl_internal_format = auto_cast gl.RG8
	case 3:
		gl_format = auto_cast gl.RGB
		gl_internal_format = auto_cast gl.RGB8
	case 4:
		gl_format = auto_cast gl.RGBA
		gl_internal_format = auto_cast gl.RGBA8
	}

	when ODIN_OS == .Windows {
		tex_id: u32 = 0
		gl.GenTextures(1, &tex_id)
		gl.BindTexture(gl.TEXTURE_2D, tex_id)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)

		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			auto_cast gl_internal_format,
			auto_cast img.width,
			auto_cast img.height,
			0,
			gl_format,
			gl.UNSIGNED_BYTE,
			raw_data(img.pixels.buf),
		)

		len := len(GRAPHICS.textures)
		tex := Texture{auto_cast len, tex_id, auto_cast img.width, auto_cast img.height, {0, 0, 1, 1}}
		append(&GRAPHICS.textures, tex)
		return tex.id
	}

	when ODIN_OS == .JS {
		tex_id := gl.CreateTexture()
		gl.BindTexture(gl.TEXTURE_2D, tex_id)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, auto_cast gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, auto_cast gl.CLAMP_TO_EDGE)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)


		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			auto_cast gl_internal_format,
			auto_cast img.width,
			auto_cast img.height,
			0,
			auto_cast gl_format,
			gl.UNSIGNED_BYTE,
			len(img.pixels.buf),
			raw_data(img.pixels.buf),
		)

		len := len(GRAPHICS.textures)
		tex := Texture{auto_cast len, tex_id, auto_cast img.width, auto_cast img.height, {0, 0, 1, 1}}
		append(&GRAPHICS.textures, tex)

		return tex.id
	}

	return {}
}

load_texture_atlas :: proc(png_bytes: []u8, sprite_count_x: u32, sprite_count_y: u32, filter: TexFilter = TexFilter.Nearest) -> [2]u32{
	tex_id := load_texture(png_bytes, filter)
	full_atlas_tex := GRAPHICS.textures[tex_id]

	start := tex_id + 1
	end := start + sprite_count_x * sprite_count_y - 1

	slice_x :f32= 1.0 / f32(sprite_count_x) 
	slice_y :f32= 1.0 / f32(sprite_count_y)

	i:= start
	for y in 0 ..<sprite_count_y {
		for x in 0 ..<sprite_count_x {
			uvs:= Rect{
				f32(x) * slice_x,
				f32(y) * slice_y,
				(f32(x) + 1) * slice_x,
				(f32(y) + 1) * slice_y,
			}

			full_atlas_tex.uv = uvs
			append(&GRAPHICS.textures, full_atlas_tex)
			i += 1
		}
	}


	return {start, end}
}


TTBakedChar :: struct #packed {
	x0:       u16,
	y0:       u16,
	x1:       u16,
	y1:       u16,
	xoff:     f32,
	yoff:     f32,
	xadvance: f32,
}
// BakedChar :: struct {
// 	x0:       f32,
// 	y0:       f32,
// 	x1:       f32,
// 	y1:       f32,
// 	xoff:     f32,
// 	yoff:     f32,
// 	xadvance: f32,
// }

Font :: struct {
	id:     u32,
	tex_id: u32,
	i_width: f32,
	i_height: f32,
	font_height_px: u32,
	new_line_px: f32,
	chars:  [dynamic]font.BakedChar,
}

load_bmfont :: proc(
	fnt_file: string,
	png_bytes: []u8,
	filter: TexFilter = TexFilter.Nearest,
) -> u32 {
	gl_filter := gl.NEAREST
	if filter == TexFilter.Linear {
		gl_filter = gl.LINEAR
	}

	img, err := png.load_from_bytes(png_bytes)
	defer image.destroy(img)
	assert(err == nil, "load_bmfont. Failed to load image. Is it a valid PNG?")
	assert(img.depth == 8, "load_bmfont. Image depth must be 8 bits per channel.")

	gl_internal_format: u32
	gl_format: u32
	switch img.channels {
	case 1:
		gl_format = auto_cast gl.RED
		gl_internal_format = auto_cast gl.R8
	case 2:
		gl_format = auto_cast gl.RG
		gl_internal_format = auto_cast gl.RG8
	case 3:
		gl_format = auto_cast gl.RGB
		gl_internal_format = auto_cast gl.RGB8
	case 4:
		gl_format = auto_cast gl.RGBA
		gl_internal_format = auto_cast gl.RGBA8
	}



	f_tex_id: u32 = 0
	when ODIN_OS == .Windows {
		tex_id: u32 = 0
		gl.GenTextures(1, &tex_id)
		gl.BindTexture(gl.TEXTURE_2D, tex_id)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)


		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			auto_cast gl_internal_format,
			auto_cast img.width,
			auto_cast img.height,
			0,
			auto_cast gl_format,
			gl.UNSIGNED_BYTE,
			raw_data(img.pixels.buf),
		)

		tex_len := len(GRAPHICS.textures)
		tex := Texture{auto_cast tex_len, tex_id, auto_cast img.width, auto_cast img.height, {0, 0, 1, 1}}
		append(&GRAPHICS.textures, tex)
		f_tex_id = tex.id
	}

	when ODIN_OS == .JS {
		tex_id := gl.CreateTexture()
		gl.BindTexture(gl.TEXTURE_2D, tex_id)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, auto_cast gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, auto_cast gl.CLAMP_TO_EDGE)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)

		// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_R, auto_cast gl.ONE)

		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			auto_cast gl_internal_format,
			auto_cast img.width,
			auto_cast img.height,
			0,
			auto_cast gl_format,
			gl.UNSIGNED_BYTE,
			len(img.pixels.buf),
			raw_data(img.pixels.buf),
		)

		tex_len := len(GRAPHICS.textures)
		tex := Texture{auto_cast tex_len, tex_id, auto_cast img.width, auto_cast img.height, {0, 0, 1, 1}}
		append(&GRAPHICS.textures, tex)
		f_tex_id = tex.id
	}

	// 32..126 is 95 glyphs
	chars :[dynamic]font.BakedChar = make([dynamic]font.BakedChar, 96)
	// chars: [dynamic]font.BakedChar

	lines := strings.split_lines(fnt_file)
	defer delete(lines)

	number_builder := strings.builder_make()

	// get size
	size := 0
	l := lines[0]
	size_tmp := 0
	size_tmp_write := false
	for c in l {
		if c == ' ' && size_tmp_write {
			break
		}
		if size_tmp_write {
			strings.write_rune(&number_builder, c)
		}
		if c == '=' {
			size_tmp += 1
			if size_tmp == 2 {
				size_tmp_write = true
			}
		}
	}
	str := strings.to_string(number_builder)
	number, ok := strconv.parse_int(str) 
	size = number
	delete(str)
	strings.builder_reset(&number_builder)

	// line height
	line_height	:= 0
	l = lines[1]
	line_write := false
	for c in l{
		if c == ' ' && line_write {
			break
		}
		if line_write {
			strings.write_rune(&number_builder, c)
		}
		if c == '=' {
			line_write = true
		}
	}
	str = strings.to_string(number_builder)
	l_height, _ := strconv.parse_int(str)
	line_height = l_height
	strings.builder_reset(&number_builder)

	for l in lines{
		if len(l) == 0 {
			continue
		}

		if l[0:7] != "char id"{
			continue
		}
		
		baked_char : font.BakedChar
		read := false
		break_loop := false
		it_type := 0
		char_id := 0
		for c in l {
			if break_loop {
				break
			}

			if c == ' ' {
				read = false
				if strings.builder_len(number_builder) > 0 {
					str := strings.to_string(number_builder)
					number, ok := strconv.parse_int(str) 
					strings.builder_reset(&number_builder)


					switch it_type {
						case 0:
							if number < 32 || number > 126 {
								break_loop = true
							}
							char_id = number
						case 1:
							baked_char.x0 = auto_cast number
						case 2:
							baked_char.y0 = auto_cast number
						case 3:
							baked_char.x1 = auto_cast number
						case 4:
							baked_char.y1 = auto_cast number
						case 5:
							baked_char.xoff = auto_cast number
						case 6:
							baked_char.yoff = auto_cast number
						case 7:
							baked_char.xadvance = auto_cast number
							chars[char_id - 32] = baked_char
						case 8:
							break_loop = true
							break
					}
					it_type += 1
				}
			}
			if read {
				strings.write_rune(&number_builder, c)
			}
			if c == '=' {
				read = true
			}
		}
	}

	// add height because flipped
	width := f32(img.width)
	height := f32(img.height)
	for &c, i in chars{
		c.x1 = c.x0 + c.x1
		c.y1 = c.y0 + c.y1
	}

	font_len := len(GRAPHICS.fonts)
	font := Font{auto_cast font_len, f_tex_id, width, height, auto_cast size, f32(line_height), chars}
	append(&GRAPHICS.fonts, font)

	return font.id
}

load_font :: proc (ttf_file_bytes: []u8, size: u32 = 64, internal_tex_size: i32 = 1024, filter: TexFilter = TexFilter.Nearest) -> u32 {
	r, chars := font.load_font(ttf_file_bytes, size, internal_tex_size)
	// clear rasterizer
	defer delete(r.data)

	gl_filter := gl.NEAREST
	if filter == TexFilter.Linear {
		gl_filter = gl.LINEAR
	}
	f_tex_id: u32 = 0
	when ODIN_OS == .Windows {
		tex_id: u32 = 0
		gl.GenTextures(1, &tex_id)
		gl.BindTexture(gl.TEXTURE_2D, tex_id)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)


		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			auto_cast internal_tex_size,
			auto_cast internal_tex_size,
			0,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			raw_data(r.data),
		)

		tex_len := len(GRAPHICS.textures)
		tex := Texture{auto_cast tex_len, tex_id, auto_cast internal_tex_size, auto_cast internal_tex_size, {0, 0, 1, 1}}
		append(&GRAPHICS.textures, tex)
		f_tex_id = tex.id
	}

	when ODIN_OS == .JS {
		tex_id := gl.CreateTexture()
		gl.BindTexture(gl.TEXTURE_2D, tex_id)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, auto_cast gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, auto_cast gl.CLAMP_TO_EDGE)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)

		// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_R, auto_cast gl.ONE)

		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			auto_cast internal_tex_size,
			auto_cast internal_tex_size,
			0,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			int(internal_tex_size * internal_tex_size) * 4,
			raw_data(r.data),
		)

		tex_len := len(GRAPHICS.textures)
		tex := Texture{auto_cast tex_len, tex_id, auto_cast internal_tex_size, auto_cast internal_tex_size, {0, 0, 1, 1}}
		append(&GRAPHICS.textures, tex)
		f_tex_id = tex.id
	}

	// font.write_to_file(&r, "idk.bmp")

	// get M height
	m_for_spacing := chars[int('M') - 32]
	line_height := f32((m_for_spacing.y1 - m_for_spacing.y0)) + 10

	font_len := len(GRAPHICS.fonts)
	font := Font{auto_cast font_len, f_tex_id, f32(internal_tex_size), f32(internal_tex_size), size, line_height, chars}
	append(&GRAPHICS.fonts, font)


	return font.id
}

Text_Align :: enum {
	Left,
	Center,
	Right,
}
draw_text :: proc(
	font_id: u32,
	pos: Vec2,
	size_px: f32 = 64,
	text: string,
	rotation: f32 = 0.,
	max_width: f32 = 0.,
	color: Color = {1., 1., 1., 1.},
	origin: Vec2 = {0, 0},
	line_height: f32 = 0.,

) {
	font := GRAPHICS.fonts[font_id]
	texture_slot := _bind_texture_to_a_slot(font.tex_id)

	index_that_fits :: proc(
		text: string,
		font: Font,
		start_index: int,
		max_width: f32,
		scale: f32,
	) -> (
		width: f32,
		index: int,
	) {
		cur_width: f32 = 0
		last_width: f32 = 0
		for i in start_index ..< len(text) {

			if text[i] == '\n' {
				cur_width -= last_width
				return cur_width, i + 1
			}
			char_render := int(text[i]) - 32


			if char_render >= len(font.chars) {
				char_render = 0
			}

			char_info := font.chars[char_render]
			cur_width += char_info.xadvance * scale
			last_width = (char_info.xadvance - (char_info.x1 - char_info.x0)) * scale

			if (char_render == 0 || i == len(text) -1) && cur_width > max_width {
				width_before_substract := cur_width
				// go back
				for j := i; j >= start_index; j -= 1 {
					char_info := font.chars[int(text[j]) - 32]
					cur_width -= char_info.xadvance * scale
					last_width = (char_info.xadvance - (char_info.x1 - char_info.x0)) * scale

					if text[j] == ' ' {
						char_info = font.chars[int(text[j-1]) - 32]
						last_width = (char_info.xadvance - (char_info.x1 - char_info.x0)) * scale
						cur_width -= last_width
						return cur_width, j + 1
					}
				}

				width_before_substract -= last_width
				return width_before_substract, i + 1
			}
		}
		cur_width -= last_width
		return cur_width, len(text)
	}

	max_width := max_width
	if max_width == 0 {
		max_width = 9999999999
	}

	size_scale := (size_px / f32(font.font_height_px))
	start_index := 0
	x_advance :f32 = 0
	y_advance: f32 = 0

	// just measure height
	all_height :f32= 0
	lines :f32= 0
	for start_index < len(text) {
		width, index := index_that_fits(text, font, start_index, max_width, size_scale)
		all_height += font.new_line_px * size_scale
		start_index = index
		lines += 1
	}
	start_index = 0
	all_height += line_height * (lines - 1) // for extra height

	dir_x :=  glm.normalize(dir_from_angle(rotation))
	dir_y := glm.normalize(dir_from_angle(rotation + glm.PI / 2))

	for start_index < len(text) {
		width, index := index_that_fits(text, font, start_index, max_width, size_scale)

		new_pos := pos
		new_pos -= dir_x * (width * origin.x)
		new_pos -= dir_y * (all_height * origin.y)

			
		for i in start_index ..< index {
			if text[i] == '\n' {
				break
			}

			angle_advance_x := dir_x * x_advance
			angle_advance_y := dir_y * y_advance

			draw_char(font_id, new_pos + angle_advance_x + angle_advance_y, size_scale, int(text[i]), rotation, color)


			char_render := int(text[i]) - 32
			if char_render >= len(font.chars) {
				char_render = 0
			}

			x_advance += font.chars[char_render].xadvance * size_scale
		}
		x_advance = 0
		y_advance += font.new_line_px * size_scale 
		y_advance += line_height
		start_index = index
	}
}


Char_To_Draw :: struct {
	font_id: u32,
	char: int,
	pos: Vec2,
	size: f32,
	color: Color,
	rotation: f32,
	style_code: int,
	ln: int,
	col: int,
}
prepare_draw_text :: proc(
	#any_int font_id: u32,
	pos: Vec2,
	size_px: f32 = 64,
	text: string,
	origin: Vec2 = {0, 0},
	color: Color = {1, 1, 1, 1},
	rotation: f32 = 0.,
	max_width: f32 = 0.,
	line_height: f32 = 0.,
) -> [dynamic]Char_To_Draw {
	clear_dynamic_array(&GRAPHICS.chars_to_draw)

	font := GRAPHICS.fonts[font_id]
	texture_slot := _bind_texture_to_a_slot(font.tex_id)

	index_that_fits :: proc(
		text: string,
		font: Font,
		start_index: int,
		max_width: f32,
		scale: f32,
	) -> (
		width: f32,
		index: int,
	) {
		cur_width: f32 = 0
		last_width: f32 = 0
		magic_string_start := int('{')
		magic_string_end := int('}')
		magic_string_slash := int('/')
		is_magic_string := false
		for i in start_index ..< len(text) {

			if text[i] == '\n' {
				cur_width -= last_width
				return cur_width, i + 1
			}

			if is_magic_string {
				if int(text[i]) == magic_string_end {
					is_magic_string = false
				}
				continue
			}

			if int(text[i]) == magic_string_start {
				is_magic_string = true
				continue
			}


			char_render := int(text[i]) - 32


			if char_render >= len(font.chars) {
				char_render = 0
			}

			char_info := font.chars[char_render]
			cur_width += char_info.xadvance * scale
			last_width = (char_info.xadvance - (char_info.x1 - char_info.x0)) * scale

			if (char_render == 0 || i == len(text) -1) && cur_width > max_width {
				width_before_substract := cur_width
				// go back
				for j := i; j >= start_index; j -= 1 {
					char_info := font.chars[int(text[j]) - 32]
					cur_width -= char_info.xadvance * scale
					last_width = (char_info.xadvance - (char_info.x1 - char_info.x0)) * scale

					if text[j] == ' ' {
						char_info = font.chars[int(text[j-1]) - 32]
						last_width = (char_info.xadvance - (char_info.x1 - char_info.x0)) * scale
						cur_width -= last_width
						return cur_width, j + 1
					}
				}

				width_before_substract -= last_width
				return width_before_substract, i + 1
			}
		}
		cur_width -= last_width
		return cur_width, len(text)
	}

	max_width := max_width
	if max_width == 0 {
		max_width = 9999999999
	}


	size_scale := (size_px / f32(font.font_height_px))
	start_index := 0
	x_advance :f32 = 0
	y_advance: f32 = 0
	pos_x := pos.x
	ln := 0
	col := 0
	current_style_code := -1


	// just measure height
	all_height :f32= 0
	lines :f32= 0
	for start_index < len(text) {
		width, index := index_that_fits(text, font, start_index, max_width, size_scale)
		all_height += font.new_line_px * size_scale
		start_index = index
		lines += 1
	}
	start_index = 0
	all_height += line_height * (lines - 1) // for extra height


	dir_x :=  glm.normalize(dir_from_angle(rotation))
	dir_y := glm.normalize(dir_from_angle(rotation + glm.PI / 2))

	for start_index < len(text) {
		width, index := index_that_fits(text, font, start_index, max_width, size_scale)
		pos_x = pos.x

		new_pos := pos
		new_pos -= dir_x * (width * origin.x)
		new_pos -= dir_y * (all_height * origin.y)

		for i := start_index; i < index; i += 1 {

			magic_string_start := int('{')
			magic_string_end := int('}')
			magic_string_slash := int('/')
			end := false
			number_iteration := 0
			if int(text[i]) == magic_string_start {
				// skip magic string
				for j in i + 1 ..< len(text) {
					if int(text[j]) == magic_string_end {
						i += j - i
						break
					}
					if int(text[j]) == magic_string_slash {
						current_style_code = -1
						end = true
					}
					else if end == false {
						if number_iteration == 0{
							current_style_code = int(text[j]) - 48
						}
						else {
							current_style_code *= 10
							current_style_code += int(text[j]) - 48
						}
						number_iteration += 1
					}
				}
				continue
			}

			if text[i] == '\n' {
				ln += 1
				col = 0
				break
			}

			// new_pos : Vec2 = {pos_x, pos.y} + {x_advance, y_advance}
			angle_advance_x := dir_x * x_advance
			angle_advance_y := dir_y * y_advance

			char_to_draw := Char_To_Draw{
				font_id = font_id,
				char = int(text[i]),
				pos = new_pos + angle_advance_x + angle_advance_y,
				size = size_scale,
				color = color,
				rotation = rotation,
				style_code = current_style_code,
				ln = ln,
				col = col,
			}

			char_render := int(text[i]) - 32
			x_advance += font.chars[char_render].xadvance * size_scale 
			col += 1

			append(&GRAPHICS.chars_to_draw, char_to_draw)
		}
		x_advance = 0
		y_advance += font.new_line_px * size_scale 
		y_advance += line_height
		start_index = index
		ln += 1
	}

	return GRAPHICS.chars_to_draw
}

draw_char :: proc(
	#any_int font_id: u32,
	pos: Vec2,
	scale: f32 = 1.,
	char: int,
	rotation: f32 = 0,
	color: Color = {1., 1., 1., 1.},
) {
	font := GRAPHICS.fonts[font_id]
	texture_slot := _bind_texture_to_a_slot(font.tex_id)

	char := char
	if char - 32 >= len(font.chars) {
		char = 32
	}

	char_info := font.chars[char - 32]

	start: u32 = auto_cast len(GRAPHICS.vertices)
	append(
		&GRAPHICS.vertices_index,
		start + 0,
		start + 1,
		start + 2,
		start + 2,
		start + 3,
		start + 0,
	)

	width := char_info.x1 - char_info.x0
	height := char_info.y1 - char_info.y0

	x: f32 = 0
	y: f32 = 0
	w: f32 = width * scale
	h: f32 = height * scale


	// uvs
	uv_x := char_info.x0 / font.i_width
	uv_y := char_info.y1 / font.i_height
	uv_w := char_info.x1 / font.i_width
	uv_h := char_info.y0 / font.i_height


	angle_dir := dir_from_angle(rotation + glm.PI / 2)
	new_pos := pos
	new_pos += angle_dir * char_info.yoff * scale
	// new_pos.x += char_info.xoff * scale


	append(
		&GRAPHICS.vertices,
		Vertex{{x, h, 0}, color, {uv_x, uv_y}, texture_slot, new_pos, rotation, 1},
		Vertex{{x, y, 0}, color, {uv_x, uv_h}, texture_slot, new_pos, rotation, 1},
		Vertex{{w, y, 0}, color, {uv_w, uv_h}, texture_slot, new_pos, rotation, 1},
		Vertex{{w, h, 0}, color, {uv_w, uv_y}, texture_slot, new_pos, rotation, 1},
	)
}


Camera :: struct {
	pos:  Vec2,
	zoom: f32,
	rot:  f32,
	rect: Rect,
}
default_camera :: proc() -> ^Camera {
	return &GRAPHICS.default_camera
}

create_camera :: proc(rect: Rect, pos: Vec2 = {0., 0.}) -> Camera {
	return Camera{pos = pos, zoom = 1., rot = 0., rect = rect}
}

TexFilter :: enum {
	Nearest,
	Linear,
}


when ODIN_OS == .Windows {
	FrameBuffer :: struct {
		framebuffer: u32,
		texture:     Texture,
		width: u32,
		height: u32,
	}
}
when ODIN_OS == .JS {
	FrameBuffer :: struct {
		framebuffer: gl.Framebuffer,
		texture:     Texture,
		width: u32,
		height: u32,
	}
}

create_framebuffer :: proc(
	width, height: i32,
	filter: TexFilter = TexFilter.Nearest,
) -> (
	FrameBuffer,
	Camera,
) {
	gl_filter := gl.NEAREST
	if filter == TexFilter.Linear {
		gl_filter = gl.LINEAR
	}

	when ODIN_OS == .Windows {
		framebuffer: u32 = 0
		gl.GenFramebuffers(1, &framebuffer)
		gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)


		texture: u32 = 0
		gl.GenTextures(1, &texture)
		gl.BindTexture(gl.TEXTURE_2D, texture)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, auto_cast gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, auto_cast gl.CLAMP_TO_EDGE)

		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0)

		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	}

	when ODIN_OS == .JS {
		framebuffer := gl.CreateFramebuffer()
		gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)

		texture := gl.CreateTexture()
		gl.BindTexture(gl.TEXTURE_2D, texture)
		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			width,
			height,
			0,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			0,
			nil,
		)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, auto_cast gl_filter)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, auto_cast gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, auto_cast gl.CLAMP_TO_EDGE)

		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0)

		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	}


	len := len(GRAPHICS.textures)
	tex := Texture{auto_cast len, texture, width, height, {0, 0, 1, 1}}
	append(&GRAPHICS.textures, tex)

	return FrameBuffer{framebuffer, tex, u32(width), u32(height)}, create_camera({0, 0, auto_cast width, auto_cast height})
}

use_framebuffer :: proc(fb: FrameBuffer, camera: Camera) {
	_unbind_texture_from_a_slot(fb.texture.id)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fb.framebuffer)
	gl.Viewport(0, 0, fb.texture.width, fb.texture.height)
	use_camera(camera)
}

use_default_framebuffer :: proc() {
	_draw()

	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	w, h := window_width(), window_height()
	gl.Viewport(0, 0, auto_cast w, auto_cast h)
	use_camera(GRAPHICS.default_camera)
}


use_camera :: proc(camera: Camera) {
	projection := glm.mat4Ortho3d(0, camera.rect.w, camera.rect.h, 0, -1, 1)

	view := glm.identity(glm.mat4)
	view *= glm.mat4Translate({-camera.pos[0], -camera.pos[1], 0})
	view *= glm.mat4Rotate({0, 0, 1}, camera.rot)
	view *= glm.mat4Scale({camera.zoom, camera.zoom, 1})

	when ODIN_OS == .Windows {
		gl.UniformMatrix4fv(GRAPHICS.projection_location, 1, false, auto_cast &projection[0])
		gl.UniformMatrix4fv(GRAPHICS.view_matrix_location, 1, false, auto_cast &view[0])
	}
	when ODIN_OS == .JS {
		gl.UniformMatrix4fv(GRAPHICS.projection_location, projection)
		gl.UniformMatrix4fv(GRAPHICS.view_matrix_location, view)
	}
}

color_from_rgba :: proc(r, g, b, a: u8) -> Color {
	result := Color{}
	result.r = f32(r) / 255
	result.g = f32(g) / 255
	result.b = f32(b) / 255
	result.a = f32(a) / 255
	return result
}

_bind_texture_to_a_slot :: proc(tex: u32) -> i32 {
	texture_slot: i32 = -1

	to_bind := GRAPHICS.textures[tex]
	for i in 0 ..= len(GRAPHICS.textures_current_bindings) - 1 {
		binding := GRAPHICS.textures_current_bindings[i]
		if binding == -1 {
			texture_slot = auto_cast i
			break
		}

		if binding == i32(to_bind.id) {
			return auto_cast i
		}
	}

	if texture_slot == -1 {
		_draw()
		fmt.println("WARNING: No texture slots left, flushing all textures")
		GRAPHICS.textures_current_bindings = {
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
			-1,
		}
		texture_slot = 0
	}

	gl.ActiveTexture(gl.TEXTURE0 + auto_cast texture_slot)
	gl.BindTexture(gl.TEXTURE_2D, GRAPHICS.textures[tex].gl_id)
	GRAPHICS.textures_current_bindings[texture_slot] = i32(to_bind.id)

	return texture_slot
}

_unbind_texture_from_a_slot :: proc(tex: u32) {
	for i in 0 ..= len(GRAPHICS.textures_current_bindings) - 1 {
		binding := GRAPHICS.textures_current_bindings[i]
		if u32(binding) == tex {
			GRAPHICS.textures_current_bindings[i] = -1
			gl.ActiveTexture(gl.TEXTURE0 + auto_cast i)
			gl.BindTexture(gl.TEXTURE_2D, 0)
			return
		}
	}
}

draw_quad :: proc(
	#any_int tex: u32 = 0,
	pos: Vec2 = {0, 0},
	size: Vec2 = {1, 1},
	rot: f32 = 0,
	color: Color = Color{1, 1, 1, 1},
	origin : Vec2 = {0.5, 0.5},
	flip_y: bool = false,
) {
	texture_slot := _bind_texture_to_a_slot(tex)
	uvs := GRAPHICS.textures[tex].uv

	start: u32 = u32(len(GRAPHICS.vertices))
	append(
		&GRAPHICS.vertices_index,
		start + 0,
		start + 1,
		start + 2,
		start + 2,
		start + 3,
		start + 0,
	)

	x := -origin.x
	y := -origin.y
	w := 1 - origin.x
	h := 1 - origin.y


	uv_x, uv_y, uv_w, uv_h: f32 = uvs.x, uvs.h, uvs.w, uvs.y
	if flip_y {
		uv_x = uvs.x 
		uv_y = uvs.y
		uv_w = uvs.w
		uv_h = uvs.h
	}

	append(
		&GRAPHICS.vertices,
		Vertex{{x, h, 0}, color, {uv_x, uv_y}, texture_slot, pos, rot, size},
		Vertex{{x, y, 0}, color, {uv_x, uv_h}, texture_slot, pos, rot, size},
		Vertex{{w, y, 0}, color, {uv_w, uv_h}, texture_slot, pos, rot, size},
		Vertex{{w, h, 0}, color, {uv_w, uv_y}, texture_slot, pos, rot, size},
	)
}

draw_line :: proc(start: Vec2, end: Vec2, width: f32, color: Color){
	texture_slot := _bind_texture_to_a_slot(0)
	uvs := GRAPHICS.textures[0].uv

	start_index: u32 = u32(len(GRAPHICS.vertices))
	append(
		&GRAPHICS.vertices_index,
		start_index + 0,
		start_index + 1,
		start_index + 2,
		start_index + 2,
		start_index + 3,
		start_index + 0,
	)


	dir := glm.normalize(end - start)
	perp := glm.normalize(dir_from_angle(angle_from_dir(dir) + glm.PI / 2))
	perp *= width / 2


	uv_x, uv_y, uv_w, uv_h: f32 = uvs.x, uvs.h, uvs.w, uvs.y
	append(
		&GRAPHICS.vertices,
		Vertex{{start.x + perp.x, start.y + perp.y, 0}, color, {uv_x, uv_y}, texture_slot, {0,0}, 0, 1},
		Vertex{{start.x - perp.x, start.y - perp.y, 0}, color, {uv_x, uv_h}, texture_slot, {0,0}, 0, 1},
		Vertex{{end.x - perp.x, end.y - perp.y, 0}, color, {uv_w, uv_h}, texture_slot, {0,0}, 0, 1},
		Vertex{{end.x + perp.x, end.y + perp.y, 0}, color, {uv_w, uv_y}, texture_slot, {0,0}, 0, 1},
	)
}

LineSegment :: struct {
	point: Vec2,
	color: Color,
	width: f32,
}
line_segments: [dynamic]LineSegment
line_segment_start :: proc(){
	clear(&line_segments)
}
line_segment_add :: proc(point:Vec2, width: f32, color: Color){
	append(&line_segments, LineSegment{point, color, width})
}
line_segment_end :: proc(){
	texture_slot := _bind_texture_to_a_slot(0)
	uvs := GRAPHICS.textures[0].uv
	
	start_index: u32 = u32(len(GRAPHICS.vertices))
	for i in 0 ..< len(line_segments)-1{
		index := start_index + u32(i) * 2
		append(
			&GRAPHICS.vertices_index,
			index + 1,
			index + 0,
			index + 2,
			index + 2,
			index + 3,
			index + 1,
		)
	}
	
	uv_x, uv_y, uv_w, uv_h: f32 = uvs.x, uvs.h, uvs.w, uvs.y

	// first segment
	segment := line_segments[0]
	next_segment := line_segments[0 + 1]
	segment_angle := glm.atan2(next_segment.point.y - segment.point.y, next_segment.point.x - segment.point.x)
	perp := dir_from_angle(segment_angle + glm.PI / 2)
	perp *= segment.width / 2
	append(
		&GRAPHICS.vertices,
		Vertex{{segment.point.x + perp.x, segment.point.y + perp.y, 0}, segment.color, {uv_x, uv_y}, texture_slot, {0,0}, 0, 1},
		Vertex{{segment.point.x - perp.x, segment.point.y - perp.y, 0}, segment.color, {uv_x, uv_h}, texture_slot, {0,0}, 0, 1},
	)


	// in between segments	
	for i in 1 ..< len(line_segments) - 1 {
		last_segment := line_segments[i - 1]
		next_segment := line_segments[i + 1]
		segment := line_segments[i]

		last_segment_angle := glm.atan2(segment.point.y - last_segment.point.y, segment.point.x - last_segment.point.x)
		next_segment_angle := glm.atan2(next_segment.point.y - segment.point.y, next_segment.point.x - segment.point.x)

		miter_angle := (next_segment_angle + last_segment_angle) / 2
		perp := dir_from_angle(miter_angle + glm.PI / 2)
		
		miter_length := segment.width / glm.cos((next_segment_angle - last_segment_angle) / 2)
		perp *= miter_length / 2


		append(
			&GRAPHICS.vertices,
			Vertex{{segment.point.x + perp.x, segment.point.y + perp.y, 0}, segment.color, {uv_x, uv_y}, texture_slot, {0,0}, 0, 1},
			Vertex{{segment.point.x - perp.x, segment.point.y - perp.y, 0}, segment.color, {uv_x, uv_h}, texture_slot, {0,0}, 0, 1},
		)
	}

	// last segment
	segment = line_segments[len(line_segments) - 1]
	last_segment := line_segments[len(line_segments) - 2]
	segment_angle = glm.atan2(segment.point.y - last_segment.point.y, segment.point.x - last_segment.point.x)
	perp = dir_from_angle(segment_angle + glm.PI / 2)
	perp *= segment.width / 2

	append(
		&GRAPHICS.vertices,
		Vertex{{segment.point.x + perp.x, segment.point.y + perp.y, 0}, segment.color, {uv_x, uv_y}, texture_slot, {0,0}, 0, 1},
		Vertex{{segment.point.x - perp.x, segment.point.y - perp.y, 0}, segment.color, {uv_x, uv_h}, texture_slot, {0,0}, 0, 1},
	)
}

draw_gradient :: proc(
	pos: Vec2 = {0, 0},
	size: Vec2 = {1, 1},
	color1 : Color = Color{0, 0, 0, 1},
	color2 : Color = Color{0, 0, 0, 1},
	color3 : Color = Color{1, 1, 1, 1},
	color4 : Color = Color{1, 1, 1, 1},
	rot: f32 = 0,
	origin : Vec2 = {0.5, 0.5},
) {
	texture_slot := _bind_texture_to_a_slot(0)
	uvs := GRAPHICS.textures[0].uv

	start: u32 = auto_cast len(GRAPHICS.vertices)
	append(
		&GRAPHICS.vertices_index,
		start + 0,
		start + 1,
		start + 2,
		start + 2,
		start + 3,
		start + 0,
	)

	x := -origin.x
	y := -origin.y
	w := 1 - origin.x
	h := 1 - origin.y


	uv_x, uv_y, uv_w, uv_h: f32 = uvs.x, uvs.h, uvs.w, uvs.y

	append(
		&GRAPHICS.vertices,
		Vertex{{x, h, 0}, color1, {uv_x, uv_y}, texture_slot, pos, rot, size},
		Vertex{{x, y, 0}, color2, {uv_x, uv_h}, texture_slot, pos, rot, size},
		Vertex{{w, y, 0}, color3, {uv_w, uv_h}, texture_slot, pos, rot, size},
		Vertex{{w, h, 0}, color4, {uv_w, uv_y}, texture_slot, pos, rot, size},
	)
}

CIRCLE_SEGMENTS :: 32
CRICLE_SEGMENTS_COS_SIN: [CIRCLE_SEGMENTS+1]Vec2
draw_circle :: proc(
	#any_int tex: u32 = 0,
	pos: Vec2 = {0, 0},
	radius: f32 = 10.,
	color: Color = Color{1, 1, 1, 1},
) {
	texture_slot := _bind_texture_to_a_slot(tex)

	start: u32 = auto_cast len(GRAPHICS.vertices)
	for i in 0 ..< CIRCLE_SEGMENTS {
		append(&GRAPHICS.vertices_index, start)
		append(&GRAPHICS.vertices_index, start + auto_cast i)
		append(&GRAPHICS.vertices_index, start + auto_cast i+ 1)
	}

	for i in 0 ..= CIRCLE_SEGMENTS {
		x_cos_y_sin := CRICLE_SEGMENTS_COS_SIN[i]
		x: f32 = x_cos_y_sin.x * radius
		y: f32 = x_cos_y_sin.y * radius
		uv_x: f32 = x_cos_y_sin.x * 0.5 + 0.5
		uv_y: f32 = x_cos_y_sin.y * 0.5 + 0.5
		append(&GRAPHICS.vertices, Vertex{{x, y, 0}, color, {uv_x, uv_y}, texture_slot, pos, 0, {1, 1}})
	}
}

draw_donut :: proc(
	#any_int tex: u32 = 0,
	pos: Vec2 = {0, 0},
	radius: f32 = 10.,
	thickness: f32 = 1.,
	color: Color = Color{1, 1, 1, 1},
){
	texture_slot := _bind_texture_to_a_slot(tex)

	start: u32 = auto_cast len(GRAPHICS.vertices)
	for i in 0 ..<(CIRCLE_SEGMENTS * 2) - 1 {
		append(&GRAPHICS.vertices_index, start + auto_cast i)
		append(&GRAPHICS.vertices_index, start + auto_cast i+ 1)
		append(&GRAPHICS.vertices_index, start + auto_cast i+ 2)

		append(&GRAPHICS.vertices_index, start + auto_cast i+ 2)
		append(&GRAPHICS.vertices_index, start + auto_cast i+ 3)
		append(&GRAPHICS.vertices_index, start + auto_cast i)
	}
	i := (CIRCLE_SEGMENTS * 2) - 1
	append(&GRAPHICS.vertices_index, start + auto_cast i)
	append(&GRAPHICS.vertices_index, start + auto_cast i+ 1)
	append(&GRAPHICS.vertices_index, start + auto_cast i+ 2)


	for i in 0 ..=CIRCLE_SEGMENTS {
		x_cos_y_sin := CRICLE_SEGMENTS_COS_SIN[i]
		x: f32 = x_cos_y_sin.x * radius
		y: f32 = x_cos_y_sin.y * radius
		uv_x: f32 = x_cos_y_sin.x * 0.5 + 0.5
		uv_y: f32 = x_cos_y_sin.y * 0.5 + 0.5
		append(&GRAPHICS.vertices, Vertex{{x, y, 0}, color, {uv_x, uv_y}, texture_slot, pos, 0, {1, 1}})

		// inner ring
		x = x_cos_y_sin.x * (radius - thickness)
		y = x_cos_y_sin.y * (radius - thickness)
		append(&GRAPHICS.vertices, Vertex{{x, y, 0}, color, {uv_x, uv_y}, texture_slot, pos, 0, {1, 1}})
	}
}

clear_color :: proc(color: Color) {
	gl.ClearColor(color[0], color[1], color[2], color[3])
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

_draw :: proc() {
	if len(GRAPHICS.vertices) == 0 {
		return
	}

	gl.BindVertexArray(GRAPHICS.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, GRAPHICS.vertex_gl_buffer)
	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		len(GRAPHICS.vertices) * size_of(Vertex),
		&GRAPHICS.vertices[0],
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, GRAPHICS.index_gl_buffer)
	gl.BufferSubData(
		gl.ELEMENT_ARRAY_BUFFER,
		0,
		len(GRAPHICS.vertices_index) * size_of(u32),
		&GRAPHICS.vertices_index[0],
	)

	gl.DrawElements(gl.TRIANGLES, auto_cast len(GRAPHICS.vertices_index), gl.UNSIGNED_INT, nil)

	clear(&GRAPHICS.vertices)
	clear(&GRAPHICS.vertices_index)
}

_post_update :: proc() {
	_draw()

	_check_window_size()
	use_camera(GRAPHICS.default_camera)
}
