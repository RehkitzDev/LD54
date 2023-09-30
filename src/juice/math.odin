package juice

import glm "core:math/linalg/glsl"
import fmt "core:fmt"
import ease "core:math/ease"
import math "core:math"
import random "core:math/rand"
import "core:intrinsics"

Ease :: ease.Ease

Rect :: struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
}
Vec2 :: glm.vec2
Vec3 :: glm.vec3
Vec4 :: glm.vec4

// odin has ease built in

wave :: proc (lo: f32, hi: f32, t: f32) -> f32{
    return lo + (glm.sin(t) + 1.0) * (hi - lo) / 2.0
}


Timer :: struct{
    time: f32,
    done: bool,
    cur: f32,
}

timer :: proc(time: f32) -> Timer{
    return Timer{time, false, 0.0}
}

timer_after :: proc(t: ^Timer, dt: f32, delay: f32 = -1.) -> bool{
    if t.done{
        return false
    }
    delay := delay
    if delay == -1.{
        delay = t.time
    }

    t.cur += dt
    if t.cur >= delay{
        t.done = true
        t.cur = 0.0
        return true
    }
    return false
}

timer_every :: proc(t: ^Timer, dt: f32, delay: f32 = -1.) -> bool{
    if t.done{
        return false
    }

    delay := delay
    if delay == -1.{
        delay = t.time
    }

    t.cur += dt
    if t.cur >= delay{
        t.cur -= delay
        return true
    }
    return false
}

timer_during :: proc(t: ^Timer, dt: f32, duration: f32 = -1.) -> bool{
    if t.done{
        return false
    }
    duration := duration 
    if duration == -1.{
        duration = t.time
    }

    t.cur += dt
    if t.cur >= duration{
        t.done = true
        t.cur = 0.0
        return true
    }
    return true 
}

rand_seed :: proc(seed: u64){
    random.set_global_seed(seed)
}
rand :: proc(from: f32, to: f32) -> f32{
    return random.float32_range(from, to)
}
rand_int :: proc(from: int, to: int) -> int{
    return random.int_max(to - from) + from
}

rand_unique_samples :: proc(#any_int amount: int) -> []i32{
    amount := amount
    samples := make([]i32, amount)
    for i in 0..<amount{
        samples[i] = i32(i)
    }
    for i in 0..<amount{
        j := rand_int(i, amount)
        samples[i], samples[j] = samples[j], samples[i]
    }
    return samples
}

rand_shuffle :: proc(arr: $T/[]$E){
    for i in 0..<len(arr){
        j := rand_int(i, len(arr))
        arr[i], arr[j] = arr[j], arr[i]
    }
}

letter_box_resolution :: proc(width: f32, height: f32, target_width: f32, target_height: f32) -> (f32, f32){
    scale := math.min(width / target_width, height / target_height)
    return target_width * scale, target_height * scale
}

letter_box_rect :: proc(width: f32, height: f32, origin: Vec2) -> Rect{
    w, h := letter_box_resolution(window_width(), window_height(), width, height)
    return Rect{
        (window_width() - w) * origin.x,
        (window_height() - h) * origin.y,
        w,
        h,
    }
}

dir_from_angle :: proc(angle: f32) -> Vec2{
    return glm.normalize(Vec2{math.cos(angle), math.sin(angle)})
}

angle_from_dir :: proc(dir: Vec2) -> f32{
    return math.atan2(dir.y, dir.x)
}

dir_start_end :: proc(start: Vec2, end: Vec2) -> Vec2{
    return glm.normalize(end - start)
}


midpoint_displacement :: proc(arr: []Vec2, index_left: int, index_right: int, displacement: f32){
    if index_right - index_left <= 1{
        return
    }
    mid := (index_left + index_right) / 2
    arr[mid] = (arr[index_left] + arr[index_right]) / 2.0 + Vec2{rand(-displacement, displacement), rand(-displacement, displacement)}
    midpoint_displacement(arr, index_left, mid, displacement / 2.0)
    midpoint_displacement(arr, mid, index_right, displacement / 2.0)
}

Tween :: struct($T: typeid){
    value: T,
    start: T,
    end: T,
    original: T,
    duration: f32,
    cur_time: f32,
    ease: Ease,
    step: i8,
    done: bool,
}

tween_create :: proc (value: $T, raise_update: bool = false) -> Tween(T){
    cur :f32= 0
    dur :f32= 0.0
    if raise_update{
        cur = 1
        dur = 0.1 
    }
    return Tween(T){
        value,
        value,
        value,
        value,
        dur, 
        cur,
        Ease.Linear,
        0,
        false,
    }
}

tween_to :: proc(tween: ^Tween($T), duration: f32, start: T, end: T, ease: Ease = Ease.Linear){
    tween.value = start
    tween.start = start
    tween.end = end
    tween.duration = duration
    tween.cur_time = 0.0
    tween.ease = ease
    tween.done = false
}

tween_update :: proc(t: ^Tween($T), time: f32) -> bool{
    if t.done || t.duration == 0.0{
        return false
    }
    t.cur_time += time
    if t.cur_time >= t.duration{
        t.done = true
        t.cur_time -= t.duration
        t.value = t.end
        return true
    }
    t.value = lerp(t.start, t.end, ease.ease(t.ease, t.cur_time / t.duration))
    return false
}

lerp_color :: proc(a: Color, b: Color, t: f32) -> Color{
    return Color{
        glm.lerp(a.r, b.r, t),
        glm.lerp(a.g, b.g, t),
        glm.lerp(a.b, b.b, t),
        glm.lerp(a.a, b.a, t),
    }
}

lerp :: proc{
	glm.lerp_f32,
	glm.lerp_f64,
	glm.lerp_vec2,
	glm.lerp_vec3,
	glm.lerp_vec4,
	glm.lerp_dvec2,
	glm.lerp_dvec3,
	glm.lerp_dvec4,
    lerp_color,
}