package game

import "juice"

game_mouse_pos :: proc() -> juice.Vec2{
    using juice
    m_pos := mouse_pos()
    rect := letter_box_rect(Game_Size.x, Game_Size.y, Origin_Center)
    m_pos -= {rect.x, rect.y}
    m_pos /= {rect.w, rect.h}
    m_pos *= Game_Size
    return m_pos
}