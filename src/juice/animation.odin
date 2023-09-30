package juice

Animation_Player :: struct{
    current_anim: i32,
    anim_start: i32,
    anim_end: i32,
    anim_timer: Timer,
    repeat: bool,
}

animation_player_create :: proc(#any_int anim_start: i32, #any_int anim_end: i32, anim_change_speed: f32 = 0.1, repeat: bool = false) -> Animation_Player{
    return Animation_Player{
        anim_start = anim_start,
        anim_end = anim_end,
        anim_timer = timer(anim_change_speed),
        repeat = repeat,
        current_anim = anim_start,
    }
}

animation_start :: proc(anim: ^Animation_Player, anim_change_speed: f32 = 0., anim_start:i32 = -1, anim_end: i32 = -1){
    if anim_change_speed != 0.{
        anim.anim_timer.time = anim_change_speed
    }
    if anim_start >= 0{
        anim.anim_start = anim_start
    }
    if anim_end >= 0{
        anim.anim_end = anim_end 
    }
    anim.current_anim = anim.anim_start
    anim.anim_timer.done = false
    anim.anim_timer.cur = 0.
}

animation_update :: proc(anim: ^Animation_Player, dt: f32, anim_change_speed: f32 = -1, anim_start:i32 = -1, anim_send: i32 = -1) -> bool{
    if anim_change_speed >= 0.{
        anim.anim_timer.time = anim_change_speed
    }
    if anim_start >= 0{
        anim.anim_start = anim_start
    }
    if anim_send >= 0{
        anim.anim_end = anim_send
    }

    if timer_after(&anim.anim_timer, dt){
        anim.current_anim += 1
        if anim.current_anim > anim.anim_end{
            if anim.repeat{
                anim.current_anim = anim.anim_start
                anim.anim_timer.done = false
                anim.anim_timer.cur = 0.
            }else{
                anim.current_anim = anim.anim_start
                return true
            }
        }
        else{
            anim.anim_timer.done = false
            anim.anim_timer.cur = 0.
        }
    }
    return false
}