package game

import "juice"
import "juice/entities"
import "components"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:slice"

Entity :: struct {
	pos:    juice.Tween(juice.Vec2),
	size:   juice.Tween(juice.Vec2),
	color:  juice.Tween(juice.Color),
	init:   proc(self: ^Entity),
	update: proc(self: ^Entity, step: f32),
	draw:   proc(self: ^Entity),
	t:      union {
        Player,
		Block,
	},
	dead:   bool,
}
Entities: [dynamic]Entity

Player :: struct {
}
Block :: struct {
    movement_timer: juice.Timer,
    dir : juice.Vec2,
	level: int,
    got_merged_this_tick: bool,
}

entity_add :: proc(entity: Entity) {
	append(&Entities, entity)
	e := &Entities[len(Entities) - 1]
	if e.init != nil {
		e.init(e)
	}
}
entity_update :: proc(step: f32) {
	using juice

	// for &e in Entities {
	// 	tween_update(&e.pos, step)
	// 	tween_update(&e.size, step)
	// 	tween_update(&e.color, step)

	// 	e.update(&e, step)
	// }

	// for i in 0 ..< len(Entities) {
	// 	if Entities[i].dead {
	// 		ordered_remove(&Entities, i)
	// 	}
	// }
}
entity_draw :: proc() {
	using juice

	for &e in Entities {
		if e.draw != nil {
			e.draw(&e)
		}
	}
}


init_game :: proc() {
	using juice
	// player
	entity_add(Entity {
		pos = tween_create(juice.Vec2{Game_Size.x / 2, Game_Size.y / 2}),
		color = tween_create(Colors.yellow),
		init = proc(self: ^Entity) {
		},
		update = proc(self: ^Entity, step: f32) {
		},
		draw = proc(self: ^Entity) {
			using juice
			draw_circle(0, self.pos.value, 10, self.color.value)
		},
	})

	// spawn enemies around screen
	start_size: f32 = 10
	for i :f32= 0; i < Game_Size.x; i += start_size{
		for j :f32= 0; j < Game_Size.y; j += start_size{

			if !(i == 0 || i == Game_Size.x - start_size || j == 0 || j == Game_Size.y - start_size) {
				continue
			}

			entity_add(Entity {
				pos = tween_create(juice.Vec2{i + start_size / 2, j + start_size / 2}),
				size = tween_create(juice.Vec2{start_size, start_size}),
				color = tween_create(Colors.orange),
				t = Block{
                    level = 1,
                    movement_timer = juice.timer(2),
                },
				init = proc(self: ^Entity) {
				},
				update = proc(self: ^Entity, step: f32) {
                    using juice

                    if self.dead {
                        return
                    }

                    block := &self.t.(Block)
                    if  timer_every(&block.movement_timer, step){
                        if block.got_merged_this_tick{
                            block.got_merged_this_tick = false
                            return
                        }

                        player_pos := Entities[0].pos.value
                        distance_x := glm.distance(player_pos.x, self.pos.value.x)
                        distance_y := glm.distance(player_pos.y, self.pos.value.y)
                        dir := dir_start_end(self.pos.value, player_pos)

                        move_dir := juice.Vec2{0, 0}

                        if distance_x > distance_y{
                            if dir.x > 0{
                                move_dir.x = 1
                            } else {
                                move_dir.x = -1
                            }
                        } else {
                            if dir.y > 0{
                                move_dir.y = 1
                            } else {
                                move_dir.y = -1
                            }
                        }

                        self.pos.value += move_dir * self.size.original
                    }
				},
				draw = proc(self: ^Entity) {
					using juice
                    block := &self.t.(Block)
					draw_quad(0, self.pos.value, self.size.value * 0.8, 0, self.color.value)
                    // draw_text(Fonts.little_guy, self.pos.value, 8, fmt.tprint(block.level),0, origin = Origin_Center)
				},
			})
		}
	}
}

update_game :: proc(step: f32) {
    using juice
    // player update
    player := &Entities[0]
    player.update(player, step)

    // block update
    clear_collision_objects()
    for &e, i in Entities {
        block, ok := &e.t.(Block)
        if !ok {
            continue
        }
        add_collision_object(u32(i), 1, 0, collision_rect_from_pos_size(e.pos.value, e.size.value, Origin_Center))
    }

    collision := get_collisions();
    // merge colliding
    for &c in collision {
        a := &Entities[c.id1]
        b := &Entities[c.id2]
        if a.dead || b.dead {
            continue
        }
        a_block := &a.t.(Block)
        b_block := &b.t.(Block)

        a.size.original += b.size.original * 0.2
        a.size.value = a.size.original
        a_block.got_merged_this_tick = true
        b.dead = true
    }


    for &e in Entities {
        block, ok := &e.t.(Block)
        if !ok {
            continue
        }
        e.update(&e, step)
    }


    // remove entities
	for i in 0 ..< len(Entities) {
		if Entities[i].dead {
			ordered_remove(&Entities, i)
		}
	}
}
draw_game :: proc() {
	entity_draw()
}
