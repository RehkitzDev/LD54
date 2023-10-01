package game

import "juice"
import "juice/entities"
import "components"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:slice"


Enemy :: struct{
	pos: juice.Tween(juice.Vec2),
	size: juice.Tween(f32),
	color: juice.Tween(juice.Color),
	cur_hp: f32,
	hp: f32,
	velocity: juice.Vec2,
	golden :bool,
	dead: bool,
}
Delayed_Enemy :: struct{
	delay: juice.Timer,
	e: Enemy,
}
Enemies: [dynamic]Enemy
Delayed_Enemies: [dynamic]Delayed_Enemy
Spawner :: struct{
	pos: juice.Vec2,
	amount: u32,
	visible :bool,
	blink_timer: juice.Timer,
	dead: juice.Timer,
}
Spawners :[dynamic]Spawner
Player :: struct{
	pos: juice.Tween(juice.Vec2),
	size: juice.Tween(f32),
	color: juice.Tween(juice.Color),
	bullet_spawner: juice.Timer,
	bullet_dir: juice.Vec2,
	muzzle_flash: juice.Tween(juice.Color),
	shoot_cd: f32,
	dmg: f32,
}
player: Player
lost :bool
kills :u64
mouse_dir :juice.Vec2
Bullet :: struct{
	pos: juice.Vec2,
	size: juice.Vec2,
	dir: juice.Vec2,
	dead :bool,
}
Bullets: [dynamic]Bullet
Effect :: struct{
	pos: juice.Tween(juice.Vec2),
	size: juice.Tween(juice.Vec2),
	color: juice.Tween(juice.Color),
	update : proc(e: ^Effect, step: f32),
	draw : proc(e: ^Effect),
	dead_timer: juice.Timer,
	dead: bool,
}
Effects: [dynamic]Effect


Walls: [4]juice.Rect
enemy_spawner := juice.timer(5)
spawn_amount_min :f32= 1
spawn_amount_max :f32= 2



init_game :: proc() {
	using juice

	lost = false
	kills = 0
	clear(&Enemies)
	clear(&Delayed_Enemies)
	clear(&Spawners)
	clear(&Bullets)
	clear(&Effects)

	// player init
	player = Player{
		pos = tween_create(juice.Vec2{Game_Size.x / 2., Game_Size.y / 2.}),
		size = tween_create(f32(10)),
		color = tween_create(Colors.white),
		shoot_cd = 0.3,
		dmg = 5,
	}

	width :f32= 2
	Walls[0] = collision_rect_from_pos_size(Vec2{0,0}, Vec2{width, Game_Size.y}, Origin_Top_Left)
	Walls[1] = collision_rect_from_pos_size(Vec2{Game_Size.x,0}, Vec2{width, Game_Size.y}, Origin_Top_Right)
	Walls[2] = collision_rect_from_pos_size(Vec2{0,0}, Vec2{Game_Size.x, width}, Origin_Top_Left)
	Walls[3] = collision_rect_from_pos_size(Vec2{0,Game_Size.y},Vec2{Game_Size.x, width}, Origin_Bottom_Left)

	Game_Camera.zoom = 1
	enemy_spawner = juice.timer(5)
	enemy_spawner.cur = enemy_spawner.time
	spawn_amount_min = 1
	spawn_amount_max = 2
}

collision :: proc(){
	using juice
	clear_collision_objects()
	for &w, i in Walls {
		add_collision_object(u32(i), 1, 0, w)
	}
	for &e, i in Enemies {
		add_collision_object(u32(i), 2, 0, collision_rect_from_pos_size(e.pos.value, e.size.value * 2, Origin_Center))
	}
	for &b, i in Bullets {
		add_collision_object(u32(i), 3, 0, collision_rect_from_pos_size(b.pos, Vec2{10,2}, Origin_Center))
	}

	// add player
	add_collision_object(0, 5, 0, collision_rect_from_pos_size(player.pos.value, player.size.value * 2, Origin_Center))

	collision := get_collisions();
	// collision resolution
	for &c in collision {
		// enemy enemy
		if c.type_1 == 2 && c.type_2 == 2{

			e1_pos := Enemies[c.id1].pos.value
			e2_pos := Enemies[c.id2].pos.value
			distance := glm.distance(e1_pos, e2_pos)
			overlap := (Enemies[c.id1].size.value + Enemies[c.id2].size.value) - distance
			overlap /= 2
			dir := glm.normalize(e1_pos - e2_pos)
			Enemies[c.id1].pos.value += dir * (overlap)
			Enemies[c.id2].pos.value -= dir * (overlap)
		}

		// bullet enemy
		if c.type_1 == 3 && c.type_2 == 2 {
			Bullets[c.id1].dead = true

			// Enemies[c.id2].dead = true
			Enemies[c.id2].velocity += glm.normalize(Bullets[c.id1].dir) * 1
			// Enemies[c.id2].size.value -= 2

			Enemies[c.id2].cur_hp -= player.dmg
			if Enemies[c.id2].cur_hp <= 0 {
				Enemies[c.id2].dead = true
				kills += 1
				juice.play_sound(Sounds.dead, 0.5, rand(0.9, 1.))

				// death effect
				size := Enemies[c.id2].size.value
				e := Effect{
					pos = tween_create(Enemies[c.id2].pos.value),
					size = tween_create(juice.Vec2{size, size}),
					color = tween_create(Enemies[c.id2].color.original),
					dead_timer = timer(0.2),
					update = proc(e: ^Effect, step: f32) {
						if timer_after(&e.dead_timer, step) {
							e.dead = true
						}
					},
					draw = proc(e: ^Effect) {
						juice.draw_donut(0, e.pos.value, e.size.value.x, 1, color = e.color.value)
					},
				}
				tween_to(&e.size, e.dead_timer.time, juice.Vec2{size, size}, juice.Vec2{size, size} * 3, Ease.Cubic_Out)
				tween_to(&e.color, e.dead_timer.time, Colors.white, juice.Color{1,1,1,0}, Ease.Cubic_Out)
				append(&Effects, e)

				if Enemies[c.id2].golden{
					rnd := rand_int(0, 2)
					if rnd == 0{
						player.shoot_cd -= 0.02

						e := Effect{
							pos = tween_create(Enemies[c.id2].pos.value),
							color = tween_create(Colors.gold),
							dead_timer = timer(4),
							update = proc(e: ^Effect, step: f32) {
								if timer_after(&e.dead_timer, step) {
									e.dead = true
								}
							},
							draw = proc(e: ^Effect) {
								juice.draw_text(Fonts.little_guy, e.pos.value, 15, "+ ATKSPD", 0, color = e.color.value, origin = Origin_Center)
							},
						}
						tween_to(&e.pos, e.dead_timer.time, e.pos.original, e.pos.original + {0, -50}, Ease.Cubic_Out)
						tween_to(&e.color, e.dead_timer.time, Colors.gold, juice.Color{Colors.gold.r, Colors.gold.g, Colors.gold.b, 0}, Ease.Cubic_Out)
						append(&Effects, e)
					}
					if rnd == 1{
						player.dmg += 0.25

						e := Effect{
							pos = tween_create(Enemies[c.id2].pos.value),
							color = tween_create(Colors.gold),
							dead_timer = timer(4),
							update = proc(e: ^Effect, step: f32) {
								if timer_after(&e.dead_timer, step) {
									e.dead = true
								}
							},
							draw = proc(e: ^Effect) {
								juice.draw_text(Fonts.little_guy, e.pos.value, 15, "+ DMG", 0, color = e.color.value, origin = Origin_Center)
							},
						}
						tween_to(&e.pos, e.dead_timer.time, e.pos.original, e.pos.original + {0, -50}, Ease.Cubic_Out)
						tween_to(&e.color, e.dead_timer.time, Colors.gold, juice.Color{Colors.gold.r, Colors.gold.g, Colors.gold.b, 0}, Ease.Cubic_Out)
						append(&Effects, e)
					}
				}
			}
			else{
				hp_percent := Enemies[c.id2].cur_hp / Enemies[c.id2].hp
				juice.play_sound(Sounds.dead, 0.5, 2.5 - hp_percent)
			}

			// hit effect
			size := Bullets[c.id1].size
			pos := Bullets[c.id1].pos
			e := Effect{
				pos = tween_create(pos),
				size = tween_create(size * 0.5),
				color = tween_create(Colors.white),
				dead_timer = timer(0.2),
				update = proc(e: ^Effect, step: f32) {
					if timer_after(&e.dead_timer, step) {
						e.dead = true
					}
				},
				draw = proc(e: ^Effect) {
					juice.draw_circle(0, e.pos.value, e.size.value.x, color = e.color.value)
				},
			}
			tween_to(&e.color, e.dead_timer.time, Colors.white, juice.Color{1,1,1,0}, Ease.Cubic_Out)
			append(&Effects, e)
		}

		// player enemy
		if c.type_1 == 5 && c.type_2 == 2 && !lost {
			lost = true
		}

		// bullet wall
		if c.type_1 == 3 && c.type_2 == 1 {
			Bullets[c.id1].dead = true
			e := Effect{
				pos = tween_create(Bullets[c.id1].pos),
				size = tween_create(Bullets[c.id1].size),
				color = tween_create(Colors.white),
				dead_timer = timer(1),
				update = proc(e: ^Effect, step: f32) {
					if timer_after(&e.dead_timer, step) {
						e.dead = true
					}
				},
				draw = proc(e: ^Effect) {
					juice.draw_circle(0, e.pos.value, e.size.value.x, color = e.color.value)
				},
			}
			tween_to(&e.color, e.dead_timer.time, Colors.white, juice.Color{1,1,1,0}, Ease.Quartic_Out)
			append(&Effects, e)

			juice.play_sound(Sounds.wall, 0.1, rand(1.6, 1.8))
		}

		// wall enemy
		if c.type_1 == 1 && c.type_2 == 2 {
			wall_rect := Walls[c.id1]
			enemy_pos := Enemies[c.id2].pos.value
			enemy_size := Enemies[c.id2].size.value

			if wall_rect.w > wall_rect.h {
				// horizontal wall
				if enemy_pos.y < wall_rect.y {
					// top
					Enemies[c.id2].pos.value.y = wall_rect.y - enemy_size - 1
				} else {
					// bottom
					Enemies[c.id2].pos.value.y = wall_rect.y + wall_rect.h + enemy_size + 1
				}
			} else {
				// vertical wall
				if enemy_pos.x < wall_rect.x {
					// left
					Enemies[c.id2].pos.value.x = wall_rect.x - enemy_size - 1
				} else {
					// right
					Enemies[c.id2].pos.value.x = wall_rect.x + wall_rect.w + enemy_size + 1
				}
			}
		}
	}
}

update_game :: proc(step: f32) {
    using juice
    // player update
	
	gamepad_x := gamepad_axis(.Left_Stick_X)
	gamepad_y := gamepad_axis(.Left_Stick_Y)

	if (gamepad_x > 0.5 || gamepad_x < -0.5) || (gamepad_y > 0.5 || gamepad_y < -0.5){
		mouse_dir = glm.normalize(Vec2{gamepad_x, gamepad_y})
	}
	if mouse_moved(){
		pos := game_mouse_pos()
		mouse_dir = glm.normalize(pos - player.pos.value)
	}

	player.bullet_dir = mouse_dir

	tween_update(&player.muzzle_flash, step)
	if !lost && (mouse_button_pressed(.Left) || gamepad_pressed(.A)){
		if timer_every(&player.bullet_spawner, step, player.shoot_cd) {
			append(&Bullets, Bullet{
				pos = player.pos.value + player.bullet_dir * (player.size.value + 4),
				dir = player.bullet_dir,
				size = Vec2{10,2},
			})
			tween_to(&player.muzzle_flash, 1, Colors.white, Color{0,0,0,0}, Ease.Quartic_Out)
		}
	}else{
		player.bullet_spawner.time = 999
	}

	// update bullets
	for &b in Bullets {
		b.pos += b.dir * 350 * step
	}


	collision()

	// spawner
	{
		if !lost && timer_every(&enemy_spawner, step) {
			amount := rand_int(int(spawn_amount_min), int(spawn_amount_max))
			// spawn_pos := Vec2{rand(10, Game_Size.x - 10), rand(10, Game_Size.y - 10)}
			spawn_pos := Vec2{0,0}
			dir := rand_int(0, 4)
			offset :f32= 20
			// top
			if dir == 0 {
				spawn_pos.x = rand(offset, Game_Size.x - offset)
				spawn_pos.y = rand(offset, 80)
			}
			// right
			if dir == 1 {
				spawn_pos.x = rand(Game_Size.x - 100, Game_Size.x - offset)
				spawn_pos.y = rand(offset, Game_Size.y - offset)
			}
			// bottom
			if dir == 2 {
				spawn_pos.x = rand(offset, Game_Size.x - offset)
				spawn_pos.y = rand(Game_Size.y - 80, Game_Size.y - offset)
			}
			// left
			if dir == 3 {
				spawn_pos.x = rand(offset, 100)
				spawn_pos.y = rand(offset, Game_Size.y - offset)
			}


			append(&Spawners, Spawner{
				pos = spawn_pos,
				amount = u32(amount),
				visible = true,
				blink_timer = timer(0.3),
				dead = timer(4),
			})
			for i in 0 ..< amount {
				// 15% chance golden
				chance := rand(0,100)
				is_golden := false
				if chance <= 15{
					is_golden = true
				}

				size := rand(10, 30)
				e := Enemy{
					pos = tween_create(spawn_pos + Vec2{rand(-20, 20), rand(-20, 20)}),
					size = tween_create(size),
					hp = size,
					cur_hp = size,
					color = tween_create(Colors.white),
					velocity = glm.normalize(Vec2{rand(-1, 1), rand(-1, 1)}),
					golden = is_golden,
				};
				tween_to(&e.size, 0.2, 4, e.size.original, Ease.Quartic_Out)
				if is_golden {
					e.color = tween_create(color_from_rgba(255, 215, 0, 255))
				}

				append(&Delayed_Enemies, Delayed_Enemy{
					delay = timer(f32(i) * 0.3 + 4),
					e = e,
				})
			}

			if enemy_spawner.time > 0.17 {
				enemy_spawner.time -= 0.07
			}
			spawn_amount_min += 0.3
			spawn_amount_max += 0.6
		}
	}

	// update enemies
	for &e in Enemies{
		tween_update(&e.size, step)
		tween_update(&e.color, step)

		e.pos.value += e.velocity
		e.velocity *= 0.95


		hp_percent := e.cur_hp / e.hp
		e.color.value = lerp(Colors.red, e.color.original, hp_percent)

		// heal a bit
		e.cur_hp += 0.05
		if e.cur_hp > e.hp {
			e.cur_hp = e.hp
		}
	}

	// update effects
	for &e in Effects {
		tween_update(&e.pos, step)
		tween_update(&e.size, step)
		tween_update(&e.color, step)
		e.update(&e, step)
	}

	// spawner blink
	for &s in Spawners {
		if timer_every(&s.blink_timer, step) {
			s.visible = !s.visible
			s.blink_timer.time *= 0.94
		}
	}

	// delete dead enemies
	for i in 0 ..< len(Enemies) {
		if Enemies[i].dead {
			ordered_remove(&Enemies, i)
		}
	}

	// add delayed enemies
	for &d in Delayed_Enemies {
		if timer_after(&d.delay, step) {
			append(&Enemies, d.e)
		}
	}
	// delete delayed enemies
	for i in 0 ..< len(Delayed_Enemies) {
		if Delayed_Enemies[i].delay.done{
			ordered_remove(&Delayed_Enemies, i)
		}
	}
	// delete dead spawners
	for i in 0 ..< len(Spawners) {
		if timer_after(&Spawners[i].dead, step){
			ordered_remove(&Spawners, i)
		}
	}
	// delete dead effects
	for i in 0 ..< len(Effects) {
		if Effects[i].dead {
			unordered_remove(&Effects, i)
		}
	}

	// delete dead bullets
	for i in 0 ..< len(Bullets) {
		if Bullets[i].dead {
			unordered_remove(&Bullets, i)
		}
	}

	if lost && (key_pressed(.Enter) || key_pressed(.Space) || gamepad_pressed_once(.A) || mouse_button_pressed_once(.Left)) {
		init_game()
	}


}
draw_game :: proc() {
	using juice

	// draw player
	draw_circle(0, player.pos.value, player.size.value - 4, color = player.color.value)
	draw_donut(0, player.pos.value, player.size.value, 2, color = player.color.value)

	draw_quad(0, player.pos.value + player.bullet_dir * (player.size.value + 4), Vec2{2,2}, color = Colors.white, origin = Origin_Center)
	draw_circle(0, player.pos.value + player.bullet_dir * (player.size.value + 4), 3, color = player.muzzle_flash.value)

	// draw enemies
	for &e in Enemies {
		draw_donut(0, e.pos.value, e.size.value, 1, color = e.color.value)
	}

	// draw walls
	for &w in Walls {
		draw_quad(0, juice.Vec2{w.x, w.y}, juice.Vec2{w.w, w.h}, color = Colors.white, origin = Origin_Top_Left)
	}

	// draw bullets
	for &b in Bullets {
		draw_quad(0, b.pos, b.size, angle_from_dir(b.dir), color = Colors.white, origin = Origin_Center)
	}

	// draw effects
	for &e in Effects {
		e.draw(&e)
	}

	// draw spawners
	for &s in Spawners {
		if s.visible {
			// draw_circle(0, s.pos, 10, color = Colors.red)
			draw_text(Fonts.little_guy, s.pos, 40, "!", 0, color = Colors.red, origin = Origin_Center)
			draw_donut(0, s.pos, 40, 2, color = Colors.red)
		}
	}

	if lost {
		draw_text(Fonts.little_guy, Game_Size / 2 - {0, 20}, 100, "YOU LOST", 0, color = Colors.red, origin = Origin_Center)
		draw_text(Fonts.little_guy, Game_Size / 2 + Vec2{0, 70}, 40, fmt.tprint("KILLS " , kills), 0, color = Colors.red, origin = Origin_Center)
		draw_text(Fonts.little_guy, Game_Size / 2 + Vec2{0, 120}, 20, "PRESS ENTER/A/LEFTCLICK TO RESTART", 0, color = Colors.red, origin = Origin_Center)
	}
}
