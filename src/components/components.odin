package components

import "../juice"
import "core:fmt"

UI_Interactable :: enum{
    Nothing,
    On_Enter,
    On_Exit,
    Hover,
    Click,
}

update_ui_interactable :: proc(ui: ^UI_Interactable, collision_rect: juice.Rect, mouse_pos: juice.Vec2, clicked: bool) {
    if juice.collision_point_rect(mouse_pos, collision_rect) {
        switch ui^ {
            case UI_Interactable.Nothing: {
                ui^ = UI_Interactable.On_Enter
            }
            case UI_Interactable.On_Exit: {
                ui^ = UI_Interactable.On_Enter
            }
            case UI_Interactable.On_Enter: {
                ui^ = UI_Interactable.Hover
            }
            case UI_Interactable.Hover: {
                ui^ = UI_Interactable.Hover
            }
            case UI_Interactable.Click: {
                ui^ = UI_Interactable.Hover
            }
        }

        if clicked {
            switch ui^ {
                case UI_Interactable.Nothing: {
                    ui^ = UI_Interactable.On_Enter
                }
                case UI_Interactable.On_Exit: {
                    ui^ = UI_Interactable.On_Enter
                }
                case UI_Interactable.On_Enter: {
                    ui^ = UI_Interactable.Click
                }
                case UI_Interactable.Hover: {
                    ui^ = UI_Interactable.Click
                }
                case UI_Interactable.Click: {
                    ui^ = UI_Interactable.Click
                }
            }
        }

    }else{
        switch ui^ {
            case UI_Interactable.Nothing: {
                ui^ = UI_Interactable.Nothing
            }
            case UI_Interactable.On_Exit: {
                ui^ = UI_Interactable.Nothing
            }
            case UI_Interactable.On_Enter: {
                ui^ = UI_Interactable.On_Exit
            }
            case UI_Interactable.Hover: {
                ui^ = UI_Interactable.On_Exit
            }
            case UI_Interactable.Click: {
                ui^ = UI_Interactable.On_Exit
            }
        }
    }
}