package entities

import "core:fmt"

Entity_Base :: struct($T: typeid){
    dead: bool,
    free: bool,
    init: proc(self: ^T),
    update: proc(self: ^T, dt: f32),
    draw: proc(self: ^T),
}

Delayed_Entity :: struct($T: typeid){
    entity: T,
    cur_time: f32,
    time: f32,
}

Entity_Collection :: struct($T: typeid){
    entities : [dynamic]T,
    delayed_entities : [dynamic]Delayed_Entity(T),
    dead_entity_indices : [dynamic]u32,
    free_entity_indices : [dynamic]u32,
}

add :: proc(entities: ^Entity_Collection($T), entity: T){
    index, ok := pop_front_safe(&entities.free_entity_indices)
    new_index : u32 = 0
    if !ok{
        append(&entities.entities, entity)
        new_index = u32(len(entities.entities) - 1)
    }
    else{
        entities.entities[index] = entity
        new_index = index
    }

    new_entity := &entities.entities[new_index]
    if new_entity.init != nil{
        new_entity.init(new_entity)
    } 
}

add_delayed :: proc(entities: ^Entity_Collection($T), delay: f32, entity: T){
    append(&entities.delayed_entities, Delayed_Entity(T){
        entity = entity,
        cur_time = 0.0,
        time = delay,
    })
}

update_delayed :: proc(entities: ^Entity_Collection($T), dt: f32){
    for &e, i in entities.delayed_entities{
        e.cur_time += dt
        if e.cur_time >= e.time{
            add(entities, e.entity)
            unordered_remove(&entities.delayed_entities, i)
        }
    }
}

cleanup_dead :: proc(entities: ^Entity_Collection($T)){
    for i in entities.dead_entity_indices{
        entities.entities[i].free = true
        append(&entities.free_entity_indices, i)
    }
    clear(&entities.dead_entity_indices)
    for &e, i in entities.entities{
        if e.dead && !e.free{
            append(&entities.dead_entity_indices, u32(i))
        }
    }
}