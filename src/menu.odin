package game

import "juice"
import "juice/entities"
import "components"
import "core:fmt"
import glm "core:math/linalg/glsl"

Menu_Button :: struct {
	pos:       juice.Tween(juice.Vec2),
	size:      juice.Tween(juice.Vec2),
	color:     juice.Tween(juice.Color),
	text:      string,
	text_size: juice.Tween(f32),
	ui:        components.UI_Interactable,
}

menu_buttons: [1]Menu_Button = {
	Menu_Button{
		text = "PLAY",
		pos = juice.tween_create(juice.Vec2{Game_Size.x / 2, Game_Size.y / 2}),
		size = juice.tween_create(juice.Vec2{140, 80}),
		color = juice.tween_create(Colors.white),
		text_size = juice.tween_create(f32(40)),
	},
}
menu_key_board_selection: i32 = 0
menu_fake_mouse_pos: juice.Vec2 = menu_buttons[0].pos.original

update_menu :: proc(step: f32) {
	using juice

	if mouse_moved() {
		menu_fake_mouse_pos = game_mouse_pos()
	}


	for &b in menu_buttons {
		tween_update(&b.pos, step)
		tween_update(&b.size, step)
		tween_update(&b.color, step)
		tween_update(&b.text_size, step)

		rect := collision_rect_from_pos_size(b.pos.original, b.size.value, Origin_Center)
		components.update_ui_interactable(
			&b.ui,
			rect,
			menu_fake_mouse_pos,
			mouse_button_pressed_once(.Left) ||
			key_pressed_once(Key.Enter) ||
			key_pressed_once(Key.Space) ||
			gamepad_pressed_once(.A),
		)

		if key_pressed_once(Key.Enter) || key_pressed_once(Key.Space) {
            b.ui = components.UI_Interactable.Click
		}


		if b.ui == components.UI_Interactable.On_Enter {
			// tween_to(&b.color, 0.2, b.color.value, Colors.yellow, Ease.Quadratic_Out)
			// tween_to(&b.pos, 0.2, b.pos.value, b.pos.original + juice.Vec2{50, 0}, Ease.Quadratic_Out)
			tween_to(&b.text_size, 0.2, b.text_size.value, b.text_size.original * 1.1, Ease.Quadratic_Out)
		}
		if b.ui == components.UI_Interactable.On_Exit {
			// tween_to(&b.color, 0.2, b.color.value, Colors.gray, Ease.Quadratic_Out)
			// tween_to(&b.pos, 0.2, b.pos.value, b.pos.original, Ease.Quadratic_Out)
			tween_to(&b.text_size, 0.2, b.text_size.value, b.text_size.original, Ease.Quadratic_Out)
		}

		if b.ui == components.UI_Interactable.Click  || gamepad_pressed(.A){
            Game_Scene = 1
		}
	}
}

draw_menu :: proc() {
	using juice

	draw_text(
		Fonts.little_guy,
		{Game_Size.x / 2, 40},
		30,
		"KILL CIRCLES",
		color = Colors.white,
		origin = Origin_Center,
		max_width = Game_Size.x / 2,
	)

	// how to play
	// draw_text(
	// 	Fonts.little_guy,
	// 	{Game_Size.x / 2, Game_Size.y / 2 - 100},
	// 	12,
	// 	"how to play:\n" +
	// 	"kill the circles by clicking on them\n" +
	// 	"you can also use the keyboard\n" +
	// 	"to select them\n\n" +
	// 	"press enter or space to start",
	// 	color = Colors.white,
	// 	origin = Origin_Center,
	// 	max_width = Game_Size.x / 2,
	// )


	draw_text(
		Fonts.little_guy,
		{Game_Size.x / 2, Game_Size.y - 20},
		12,
		"LD54 entry\na game by rehkitzdev",
		color = Colors.white,
		origin = Origin_Center,
	)

	for &b in menu_buttons {
		draw_text(
			Fonts.little_guy,
			b.pos.value,
			b.text_size.value,
			b.text,
			color = b.color.value,
			origin = Origin_Center,
		)
		if b.ui == components.UI_Interactable.Hover {
			// to_color := Colors.yellow
			// to_color.a = 0
			// from_color := Colors.yellow
			// from_color.a = 0.07
			// draw_gradient(b.pos.original + {-50, 5}, {200, 110}, from_color, from_color, to_color, to_color, origin = Origin_Center_Left)
		}

		// rect := collision_rect_from_pos_size(b.pos.original, b.size.value, Origin_Center)
		// draw_quad(0, {rect.x, rect.y}, {rect.w, rect.h}, 0, {1, 0, 0, 0.5}, Origin_Top_Left)
	}

}
