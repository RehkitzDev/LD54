package game

import "core:fmt"
import "core:mem"
import "juice"



Textures : Textures_Struct
Textures_Struct :: struct{
}
load_textures :: proc(){
	using juice
}
Sounds : Sounds_Struct 
Sounds_Struct :: struct{
	dead: u32,
	dead2: u32,
	hit: u32,
	hit2: u32,
	laser: u32,
	wall: u32,
}
load_sounds :: proc(){
	using juice
	Sounds.dead = juice.load_sound(#load("../assets/dead.wav"))
	Sounds.dead2 = juice.load_sound(#load("../assets/dead2.wav"))
	Sounds.hit = juice.load_sound(#load("../assets/hit.wav"))
	Sounds.hit2 = juice.load_sound(#load("../assets/hit2.wav"))
	Sounds.laser = juice.load_sound(#load("../assets/laser.wav"))
	Sounds.wall = juice.load_sound(#load("../assets/wall.wav"))
}
Fonts : Fonts_Struct
Fonts_Struct :: struct{
	little_guy: u32,
}
load_fonts :: proc(){
	using juice
	Fonts.little_guy = juice.load_bmfont(#load("../assets/little_guy.fnt", string), #load("../assets/little_guy.png"))
}
Colors_Struct :: struct{
	black: juice.Color,
	white: juice.Color,
	red: juice.Color,
	gold : juice.Color,
}
Colors : Colors_Struct = {
	black = juice.Color{0, 0, 0, 1},
	white = juice.Color{1, 1, 1, 1},
	red = juice.Color{1, 0, 0, 1},
	gold = juice.Color{1, 0.8, 0, 1},
}

Game_Size : juice.Vec2 = {640, 360}
Game_Camera: juice.Camera
Game_Scene: int = 0 

main :: proc() {
	context = juice.default_context()
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
		
		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
		}
	}

	using juice
	create_window("Kill Circles", {1280, 720})
	fb, camera := create_framebuffer(i32(Game_Size.x), i32(Game_Size.y), TexFilter.Nearest)
	Game_Camera = camera

	load_textures()
	load_fonts()
	load_sounds()

	init_game()


	frame_rate :f32= 1./120.
	frame_time :f32= 0.0
	updated: bool = false
    for !should_close() {
		free_all(context.temp_allocator)

		frame_time += dt()
		updated = false
		for frame_time >= frame_rate {
			if frame_time > 0.1 {
				frame_time = 0
			}

			frame_time -= frame_rate
			// update(frame_rate)

			switch Game_Scene{
				case 0: update_menu(frame_rate)
				case 1: update_game(frame_rate)
			}

			reset_pressed_once()
			updated = true
		}


		if updated {
			clear_color({0, 0, 0, 1})

			use_framebuffer(fb, Game_Camera)
			clear_color(Colors.black)

			// draw
			switch Game_Scene{
				case 0: draw_menu()
				case 1: draw_game()
			}

			use_default_framebuffer()
			rect := letter_box_rect(Game_Size.x, Game_Size.y, Origin_Center)
			draw_quad(fb.texture.id, {rect.x ,rect.y}, {rect.w, rect.h}, origin = Origin_Top_Left, flip_y = true)
		}
		
        next_frame()
    }
}