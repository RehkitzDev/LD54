package juice
import glm "core:math/linalg/glsl"
import "core:slice"
import "core:fmt"

Collision :: union {
	Circle,
	Rect,
}

Circle :: struct {
	pos:    Vec2,
	radius: f32,
}


collision_circle_circle :: proc(a: Circle, b: Circle) -> bool {
	return glm.length(a.pos - b.pos) < a.radius + b.radius
}
collision_rect_rect :: proc(a: Rect, b: Rect) -> bool {
	return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
}
collision_circle_rect :: proc(a: Circle, b: Rect) -> bool {
	closest_x := glm.clamp(a.pos.x, b.x, b.x + b.w)
	closest_y := glm.clamp(a.pos.y, b.y, b.y + b.h)

	return glm.length(Vec2{closest_x, closest_y} - a.pos) < a.radius
}
collision_rect_circle :: proc(a: Rect, b: Circle) -> bool {
	closest_x := glm.clamp(b.pos.x, a.x, a.x + a.w)
	closest_y := glm.clamp(b.pos.y, a.y, a.y + a.h)

	return glm.length(Vec2{closest_x, closest_y} - b.pos) < b.radius
}

collision_point_rect :: proc(a: Vec2, b: Rect) -> bool {
	return a.x >= b.x && a.x <= b.x + b.w && a.y >= b.y && a.y <= b.y + b.h
}

is_colliding :: proc(a: Collision, b: Collision) -> bool {
	switch t1 in a {
	case Circle:
		switch t2 in b {
		case Circle:
			return collision_circle_circle(t1, t2)
		case Rect:
			return collision_circle_rect(t1, t2)
		}
	case Rect:
		switch t2 in b {
		case Circle:
			return collision_rect_circle(t1, t2)
		case Rect:
			return collision_rect_rect(t1, t2)
		}
	}
	return false
}

colliding_dir :: proc(a: Collision, b: Collision) -> (normal: Vec2, penetration: f32) {
	switch t1 in a {
	case Circle:
		switch t2 in b {
		case Circle:
			normal := glm.normalize(t2.pos - t1.pos)
			penetration := t1.radius + t2.radius - glm.length(t2.pos - t1.pos)
			return normal, penetration
		case Rect:
			// use clamp for normal
			closest_x := glm.clamp(t1.pos.x, t2.x, t2.x + t2.w)
			closest_y := glm.clamp(t1.pos.y, t2.y, t2.y + t2.h)
			normal := glm.normalize(Vec2{closest_x, closest_y} - t1.pos)
			penetration := t1.radius - glm.length(Vec2{closest_x, closest_y} - t1.pos)
			return normal, penetration
		}
	case Rect:
		switch t2 in b {
		case Circle:
			// use clamp for normal
			closest_x := glm.clamp(t2.pos.x, t1.x, t1.x + t1.w)
			closest_y := glm.clamp(t2.pos.y, t1.y, t1.y + t1.h)
			normal := glm.normalize(Vec2{closest_x, closest_y} - t2.pos)
			penetration := t2.radius - glm.length(Vec2{closest_x, closest_y} - t2.pos)
			return normal, penetration
		case Rect:
			normal := glm.normalize(Vec2{t2.x, t2.y} - Vec2{t1.x, t1.y})
			overlap_x := t1.x + t1.w - t2.x
			overlap_y := t1.y + t1.h - t2.y
			penetration := glm.min(overlap_x, overlap_y)
			return normal, penetration
		}
	}
	return Vec2{0, 0}, 0.0
}

collision_rect_from_pos_size :: proc(pos: Vec2, size: Vec2, origin: Vec2) -> Rect {
	return Rect{x = pos.x - size.x * origin.x, y = pos.y - size.y * origin.y, w = size.x, h = size.y}
}

_CollisionObject :: struct {
	id:         u32,
	type:       u32,
	black_list: u32,
	collision:  Collision,
}

_Collision_Pair :: struct {
	id1:        u32,
	id2:        u32,
	type_1:     u32,
	type_2:     u32,
	collision1: Collision,
	collision2: Collision,
}
collision_objects: [dynamic]_CollisionObject
collision_pairs: [dynamic]_Collision_Pair
add_collision_object :: proc(id: u32, type: u32, black_list: u32, collision: Collision) {
	append(&collision_objects, _CollisionObject{id, type, black_list, collision})
}
clear_collision_objects :: proc() {
	clear(&collision_objects)
	clear(&collision_pairs)
}
get_collisions :: proc() -> ^[dynamic]_Collision_Pair {
	// sweep and prune

	// order by x
	slice.sort_by(collision_objects[:], proc(a, b: _CollisionObject) -> bool {
		x1: f32 = 0
		x2: f32 = 0

		switch t in a.collision {
		case Circle:
			x1 = t.pos.x - t.radius
		case Rect:
			x1 = t.x
		}

		switch t in b.collision {
		case Circle:
			x2 = t.pos.x - t.radius
		case Rect:
			x2 = t.x
		}

		return x1 < x2
	})

	// find pairs
	for i in 0 ..< len(collision_objects) {
		for j in i + 1 ..< len(collision_objects) {

			if collision_objects[i].black_list & collision_objects[j].type != 0 {
				continue
			}
			if collision_objects[j].black_list & collision_objects[i].type != 0 {
				continue
			}

			colliding := true
			switch t in collision_objects[i].collision {
			case Circle:
				switch t2 in collision_objects[j].collision {
				case Circle:
					if t.pos.x + t.radius < t2.pos.x - t2.radius {
						colliding = false
						break
					}
				case Rect:
					if t.pos.x + t.radius < t2.x {
						colliding = false
						break
					}
				}
			case Rect:
				switch t2 in collision_objects[j].collision {
				case Circle:
					if t.x + t.w < t2.pos.x - t2.radius {
						colliding = false
						break
					}
				case Rect:
					if t.x + t.w < t2.x {
						colliding = false
						break
					}
				}
			}

			if !colliding {
				break
			}

			if is_colliding(collision_objects[i].collision, collision_objects[j].collision) {
				// dir, pen := colliding_dir(collision_objects[i].collision, collision_objects[j].collision)

				append(
					&collision_pairs,
					_Collision_Pair{
						collision_objects[i].id,
						collision_objects[j].id,
						collision_objects[i].type,
						collision_objects[j].type,
						collision_objects[i].collision,
						collision_objects[j].collision,
					},
				)

                if collision_objects[i].type == collision_objects[j].type {
                    continue
                }

				append(
					&collision_pairs,
					_Collision_Pair{
						collision_objects[j].id,
						collision_objects[i].id,
						collision_objects[j].type,
						collision_objects[i].type,
						collision_objects[j].collision,
						collision_objects[i].collision,
					},
				)
			}


		}
	}

	return &collision_pairs
}
