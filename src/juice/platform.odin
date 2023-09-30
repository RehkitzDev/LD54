package juice

import "core:fmt"
import "core:runtime"
import "core:mem"
import "core:time"

when ODIN_OS == .Windows {
	import "core:sys/windows"
	import "input"

	Platform :: struct {
		hwnd:               windows.HWND,
		hdc:                windows.HDC,
		should_close:       bool,
		width:              f32,
		height:             f32,
		is_fullscreen:      bool,
		keys:               [256]bool,
		keys_pressed_once:  [256]bool,
		mouse_pos:          [2]f32,
		last_mouse_pos:     [2]f32,
		mouse_buttons:      [10]bool,
		mouse_buttons_once: [10]bool,
		mouse_wheel:        f32,
		gamepad : Gamepad,

		start_tick: time.Tick,
		last_tick: time.Tick,
		delta: f32,
		time_since_start: f32,
	}

	_wnd_proc :: proc(
		hwnd: windows.HWND,
		msg: windows.UINT,
		wparam: windows.WPARAM,
		lparam: windows.LPARAM,
	) -> windows.LRESULT {


		switch msg {
		case windows.WM_CLOSE:
			windows.PostQuitMessage(0)
			PLATFORM.should_close = true
		case windows.WM_DESTROY:
			windows.PostQuitMessage(0)
			PLATFORM.should_close = true
		case windows.WM_KEYDOWN:
			if !PLATFORM.keys[wparam] {
				PLATFORM.keys_pressed_once[wparam] = true
			}
			PLATFORM.keys[wparam] = true
		case windows.WM_KEYUP:
			PLATFORM.keys[wparam] = false
			PLATFORM.keys_pressed_once[wparam] = false
		case windows.WM_SIZE:
			PLATFORM.width = f32(windows.LOWORD(auto_cast lparam))
			PLATFORM.height = f32(windows.HIWORD(auto_cast lparam))
		case windows.WM_MOUSEMOVE:
			PLATFORM.mouse_pos[0] = f32(windows.LOWORD(auto_cast lparam))
			PLATFORM.mouse_pos[1] = f32(windows.HIWORD(auto_cast lparam))
		case windows.WM_LBUTTONDOWN:
			if !PLATFORM.mouse_buttons[0] {
				PLATFORM.mouse_buttons_once[0] = true
			}
			PLATFORM.mouse_buttons[0] = true
		case windows.WM_LBUTTONUP:
			PLATFORM.mouse_buttons_once[0] = false
			PLATFORM.mouse_buttons[0] = false
		case windows.WM_RBUTTONDOWN:
			if !PLATFORM.mouse_buttons[1] {
				PLATFORM.mouse_buttons_once[1] = true
			}
			PLATFORM.mouse_buttons[1] = true
		case windows.WM_RBUTTONUP:
			PLATFORM.mouse_buttons_once[1] = false
			PLATFORM.mouse_buttons[1] = false
		case windows.WM_MBUTTONDOWN:
			if !PLATFORM.mouse_buttons[2] {
				PLATFORM.mouse_buttons_once[2] = true
			}
			PLATFORM.mouse_buttons[2] = true
		case windows.WM_MBUTTONUP:
			PLATFORM.mouse_buttons_once[2] = false
			PLATFORM.mouse_buttons[2] = false
		case windows.WM_XBUTTONDOWN:
			if windows.HIWORD(auto_cast wparam) == windows.XBUTTON1 {
				if !PLATFORM.mouse_buttons[3] {
					PLATFORM.mouse_buttons_once[3] = true
				}
				PLATFORM.mouse_buttons[3] = true
			} else if windows.HIWORD(auto_cast wparam) == windows.XBUTTON2 {
				if !PLATFORM.mouse_buttons[4] {
					PLATFORM.mouse_buttons_once[4] = true
				}
				PLATFORM.mouse_buttons[4] = true
			}
		case windows.WM_XBUTTONUP:
			if windows.HIWORD(auto_cast wparam) == windows.XBUTTON1 {
				PLATFORM.mouse_buttons_once[3] = false
				PLATFORM.mouse_buttons[3] = false
			} else if windows.HIWORD(auto_cast wparam) == windows.XBUTTON2 {
				PLATFORM.mouse_buttons_once[4] = false
				PLATFORM.mouse_buttons[4] = false
			}
		case windows.WM_MOUSEWHEEL:
			PLATFORM.mouse_wheel = f32(windows.HIWORD(auto_cast wparam)) / 120.0
		case windows.WM_SETCURSOR:
			if windows.LOWORD(auto_cast lparam) == windows.HTCLIENT {
				windows.SetCursor(windows.LoadCursorA(nil, windows.IDC_ARROW))
				return 1
			}
		}

		return windows.DefWindowProcW(hwnd, msg, wparam, lparam)
	}
}
when ODIN_OS == .JS {
	import "vendor:wasm/js"

	CANVAS_ID :: "canvas"

	foreign import js_env "env"

	@(default_calling_convention="contextless")
	foreign js_env {
		frame :: proc() -> bool ---
	}

	foreign import odin_time "odin_env"
	@(default_calling_convention="contextless")
	foreign odin_time {
		time_now :: proc() -> i64 ---
		tick_now :: proc() -> i64 ---
	}

	foreign import gamepad "gamepad"
	@(default_calling_convention="contextless")
	foreign gamepad {
		get_state :: proc(ptr: rawptr) -> bool ---
	}


	// wasm allocator
	Heap_Memory := [1048576  * 128]u8 {} // 128mb
	Heap_Arena: mem.Arena
	Heap_Allocator: mem.Allocator

	Temp_Memory := [1048576 * 16]u8 {} // 16mb
	Temp_Arena: mem.Arena
	Temp_Allocator: mem.Allocator

	Platform :: struct {
		should_close:       bool,
		width:              f32,
		height:             f32,
		keys:               [256]bool,
		keys_pressed_once:  [256]bool,
		mouse_pos:          [2]f32,
		last_mouse_pos:     [2]f32,
		mouse_buttons:      [10]bool,
		mouse_buttons_once: [10]bool,
		mouse_wheel:        f32,
		gamepad: Gamepad,

		start_tick: time.Tick,
		last_tick: time.Tick,
		delta: f32,
		time_since_start: f32,
	}
}

Key :: enum {
	A         = 65,
	B         = 66,
	C         = 67,
	D         = 68,
	E         = 69,
	F         = 70,
	G         = 71,
	H         = 72,
	I         = 73,
	J         = 74,
	K         = 75,
	L         = 76,
	M         = 77,
	N         = 78,
	O         = 79,
	P         = 80,
	Q         = 81,
	R         = 82,
	S         = 83,
	T         = 84,
	U         = 85,
	V         = 86,
	W         = 87,
	X         = 88,
	Y         = 89,
	Z         = 90,
	Left      = 37,
	Up        = 38,
	Right     = 39,
	Down      = 40,
	Space     = 32,
	Escape    = 27,
	Enter     = 13,
	Shift     = 16,
	Control   = 17,
	Alt       = 18,
	Tab       = 9,
	Backspace = 8,
	Insert    = 45,
	Delete    = 46,
	Home      = 36,
	End       = 35,
	Number_0  = 48,
	Number_1  = 49,
	Number_2  = 50,
	Number_3  = 51,
	Number_4  = 52,
	Number_5  = 53,
	Number_6  = 54,
	Number_7  = 55,
	Number_8  = 56,
	Number_9  = 57,
}

Mouse_Button :: enum {
	Left   = 0,
	Right  = 1,
	Middle = 2,
	X1     = 3,
	X2     = 4,
}

Gamepad :: struct #packed{
	connected: bool,
	buttons: [16]bool,
	buttons_pressed_once: [16]bool,
	axes: [6]f32,
	axes_once: [6]bool,
}

Gamepad_Button :: enum{
	A = 0,
	B = 1,
	X = 2,
	Y = 3,
	Left_Bumper = 4,
	Right_Bumper = 5,
	Left_Trigger = 6,
	Right_Trigger = 7,
	Select = 8,
	Start = 9,
	Left_Stick = 10,
	Right_Stick = 11,
	Up = 12,
	Down = 13,
	Left = 14,
	Right = 15,
}

Gamepad_Axis :: enum{
	Left_Stick_X = 0,
	Left_Stick_Y = 1,
	Right_Stick_X = 2,
	Right_Stick_Y = 3,
	Left_Trigger = 4,
	Right_Trigger = 5,
}

PLATFORM := Platform{}

default_context :: proc() -> runtime.Context{
	when ODIN_OS == .JS {
		c := runtime.default_context() 
	
		mem.arena_init(&Heap_Arena, Heap_Memory[:])
		Heap_Allocator = mem.arena_allocator(&Heap_Arena)
		c.allocator = Heap_Allocator
	
		mem.arena_init(&Temp_Arena, Temp_Memory[:])
		Temp_Allocator = mem.arena_allocator(&Temp_Arena)
		c.temp_allocator = Temp_Allocator

		// runtime.init_global_temporary_allocator(1048576)
		// runtime.global_default_temp_allocator_data = Temp_Allocator
	
		return c
	}
	else{
		return runtime.default_context()
	}
}

when ODIN_OS == .Windows{
	window_style := windows.WS_OVERLAPPEDWINDOW | windows.WS_VISIBLE
	fullscreen_style := windows.WS_POPUP | windows.WS_VISIBLE
}
create_window :: proc(window_name: string = "juice", size: [2]u32 = {1280, 720}) {
	PLATFORM.start_tick = time.tick_now()
	PLATFORM.last_tick = PLATFORM.start_tick
	
	when ODIN_OS == .Windows {
		class_name := windows.utf8_to_wstring("juice_window_class")
		hinstance := windows.GetModuleHandleW(nil)
		wnd_class := windows.WNDCLASSEXW {
			cbSize        = size_of(windows.WNDCLASSEXW),
			style         = windows.CS_OWNDC | windows.CS_HREDRAW | windows.CS_VREDRAW,
			lpfnWndProc   = auto_cast _wnd_proc,
			hInstance     = auto_cast hinstance,
			lpszClassName = class_name,
		}
		if windows.RegisterClassExW(&wnd_class) == 0 {
			fmt.printf("RegisterClassExW failed\n")
			return
		}
		hwnd := windows.CreateWindowExW(
			0,
			class_name,
			windows.utf8_to_wstring(window_name),
			window_style,
			windows.CW_USEDEFAULT,
			windows.CW_USEDEFAULT,
			i32(size.x),
			i32(size.y),
			nil,
			nil,
			auto_cast hinstance,
			nil,
		)
		if hwnd == nil {
			fmt.printf("CreateWindowExW failed\n")
			return
		}

		hdc := windows.GetDC(hwnd)
		if hdc == nil {
			fmt.printf("GetDC failed\n")
			return
		}

		pfd := windows.PIXELFORMATDESCRIPTOR {
			nSize        = size_of(windows.PIXELFORMATDESCRIPTOR),
			nVersion     = 1,
			dwFlags      = windows.PFD_DRAW_TO_WINDOW | windows.PFD_SUPPORT_OPENGL | windows.PFD_DOUBLEBUFFER,
			iPixelType   = windows.PFD_TYPE_RGBA,
			cColorBits   = 32,
			cAlphaBits   = 8,
			cDepthBits   = 32,
			cStencilBits = 8,
		}

		pixel_format := windows.ChoosePixelFormat(hdc, &pfd)
		if pixel_format == 0 {
			fmt.printf("ChoosePixelFormat failed\n")
			return
		}

		if !windows.SetPixelFormat(hdc, pixel_format, &pfd) {
			fmt.printf("SetPixelFormat failed\n")
			return
		}

		// create opengl context
		ctx := windows.wglCreateContext(hdc)
		if ctx == nil {
			fmt.printf("wglCreateContext failed\n")
			return
		}
		if !windows.wglMakeCurrent(hdc, ctx) {
			fmt.printf("wglMakeCurrent failed\n")
			return
		}

		// enable vsync
		windows.wglSwapIntervalEXT = auto_cast windows.wglGetProcAddress("wglSwapIntervalEXT")
		windows.wglSwapIntervalEXT(1)

		PLATFORM.hwnd = hwnd
		PLATFORM.hdc = hdc

		
		window_size := windows.RECT{}
		windows.GetClientRect(hwnd, &window_size)
		PLATFORM.width = f32(window_size.right - window_size.left)
		PLATFORM.height = f32(window_size.bottom - window_size.top)
		
		gl_set_proc_address :: proc(p: rawptr, name: cstring) {
			fptr := windows.wglGetProcAddress(name)
			if fptr == nil {
				fmt.println(name, " not found in opengl32.dll");
				opengl_dll_str := windows.utf8_to_wstring("Opengl32.dll")
				fptr = windows.GetProcAddress(windows.LoadLibraryW(opengl_dll_str), name)
			}
			(^rawptr)(p)^ = fptr
		}
		_load_gl(gl_set_proc_address)
		input.init()

		windows.SetCursor(windows.LoadCursorA(nil, windows.IDC_ARROW))
		resize_window(f32(size.x), f32(size.y))
	}

	when ODIN_OS == .JS {
		// add allocator
		// mem.arena_init(&Heap_Arena, Heap_Memory[:])
		// Heap_Allocator = mem.arena_allocator(&Heap_Arena)
		// context.allocator = Heap_Allocator
	
		// mem.arena_init(&Temp_Arena, Temp_Memory[:])
		// Temp_Allocator = mem.arena_allocator(&Temp_Arena)
		// context.temp_allocator = Temp_Allocator

		js.add_window_event_listener(js.Event_Kind.Resize, nil, proc(ev: js.Event) {
			rect := js.get_bounding_client_rect(CANVAS_ID)

			PLATFORM.width = f32(rect.width)
			PLATFORM.height = f32(rect.height)
		})
		js.add_window_event_listener(js.Event_Kind.Key_Down, nil, proc(ev: js.Event) {
			key := ev.key._code_buf[2]
			if !PLATFORM.keys[key] {
				PLATFORM.keys_pressed_once[key] = true
			}
			PLATFORM.keys[key] = true
		})
		js.add_window_event_listener(js.Event_Kind.Key_Up, nil, proc(ev: js.Event) {
			key := ev.key._code_buf[2]
			PLATFORM.keys[key] = false
			PLATFORM.keys_pressed_once[key] = false
		})
		js.add_window_event_listener(js.Event_Kind.Mouse_Move, nil, proc(ev: js.Event) {
			PLATFORM.mouse_pos[0] = f32(ev.mouse.client.x)
			PLATFORM.mouse_pos[1] = f32(ev.mouse.client.y)
		})
		js.add_window_event_listener(js.Event_Kind.Touch_Move, nil, proc(ev: js.Event) {
			PLATFORM.mouse_pos[0] = f32(ev.mouse.client.x)
			PLATFORM.mouse_pos[1] = f32(ev.mouse.client.y)
		})

		js.add_window_event_listener(js.Event_Kind.Touch_Start, nil, proc(ev: js.Event){
			button := ev.mouse.button
			if !PLATFORM.mouse_buttons[button] {
				PLATFORM.mouse_buttons_once[button] = true
			}
			PLATFORM.mouse_buttons[button] = true
		})
		js.add_window_event_listener(js.Event_Kind.Touch_End, nil, proc(ev: js.Event){
			button := ev.mouse.button
			PLATFORM.mouse_buttons_once[button] = false
			PLATFORM.mouse_buttons[button] = false
		})
		js.add_window_event_listener(js.Event_Kind.Touch_Cancel, nil, proc(ev: js.Event){
			button := ev.mouse.button
			PLATFORM.mouse_buttons_once[button] = false
			PLATFORM.mouse_buttons[button] = false
		})

		js.add_window_event_listener(js.Event_Kind.Mouse_Down, nil, proc(ev: js.Event) {
			button := ev.mouse.button
			if button == 2 {
				button = 1
			} else if button == 1 {
				button = 2
			}


			if !PLATFORM.mouse_buttons[button] {
				PLATFORM.mouse_buttons_once[button] = true
			}
			PLATFORM.mouse_buttons[button] = true
		})
		js.add_window_event_listener(js.Event_Kind.Mouse_Up, nil, proc(ev: js.Event) {
			
			button := ev.mouse.button
			if button == 2 {
				button = 1
			} else if button == 1 {
				button = 2
			}

			PLATFORM.mouse_buttons_once[button] = false
			PLATFORM.mouse_buttons[button] = false
		})
		js.add_window_event_listener(
			js.Event_Kind.Wheel,
			nil,
			proc(ev: js.Event) {
				// PLATFORM.mouse_wheel_delta = f32(ev.mouse.)
			},
		)

		rect := js.get_bounding_client_rect(CANVAS_ID)
		PLATFORM.width = f32(rect.width)
		PLATFORM.height = f32(rect.height)

		_load_gl()
	}

	rand_seed(u64(time.since(time.Time{0})))

	_init_resources()
	init_audio()
}

reset_pressed_once :: proc(gamepad_axis_reset: f32 = 0.2){
	PLATFORM.keys_pressed_once = [256]bool{}
	PLATFORM.mouse_buttons_once = [10]bool{}
	PLATFORM.gamepad.buttons_pressed_once = [16]bool{}
	for i in 0..<6{
		if (PLATFORM.gamepad.axes[i] > -gamepad_axis_reset && PLATFORM.gamepad.axes[i] < gamepad_axis_reset) && PLATFORM.gamepad.axes_once[i]{
			PLATFORM.gamepad.axes_once[i] = false
		}
	}
}

next_frame :: proc() {
	_post_update()
	PLATFORM.last_mouse_pos = PLATFORM.mouse_pos

	when ODIN_OS == .Windows {
		windows.SwapBuffers(PLATFORM.hdc)
		msg := windows.MSG{}
		for windows.PeekMessageW(&msg, nil, 0, 0, windows.PM_REMOVE) {
			windows.TranslateMessage(&msg)
			windows.DispatchMessageW(&msg)
		}

		{
			gamepad_state : input.STATE
			result := input.GetState(0, &gamepad_state)
			if result == 0{
				PLATFORM.gamepad.connected = true
				// PLATFORM.gamepad.buttons_pressed_once = PLATFORM.gamepad.buttons
				// PLATFORM.gamepad.buttons = [16]bool{}
				// PLATFORM.gamepad.axes = [6]f32{}

				buttons : [16]bool;
				for i in 0..<16 {
					if gamepad_state.gamepad.wButtons & (1 << u32(i)) != 0 {
						using input
						switch i {
							case 1: buttons[Gamepad_Button.Up] = true
							case 2: buttons[Gamepad_Button.Down] = true
							case 3: buttons[Gamepad_Button.Left] = true
							case 4: buttons[Gamepad_Button.Right] = true
							case 5: buttons[Gamepad_Button.Start] = true
							case 6: buttons[Gamepad_Button.Select] = true
							case 7: buttons[Gamepad_Button.Left_Stick] = true
							case 8: buttons[Gamepad_Button.Right_Stick] = true
							case 9: buttons[Gamepad_Button.Left_Bumper] = true
							case 10: buttons[Gamepad_Button.Right_Bumper] = true
							// case 11: buttons[Gamepad_Button.Guide] = true (xbox button)
							case 12: buttons[Gamepad_Button.A] = true
							case 13: buttons[Gamepad_Button.B] = true
							case 14: buttons[Gamepad_Button.X] = true
							case 15: buttons[Gamepad_Button.Y] = true
						}
					}
				}

				for b, i in buttons{
					if b && !PLATFORM.gamepad.buttons[i] {
						PLATFORM.gamepad.buttons_pressed_once[i] = true
					}
					else {
						PLATFORM.gamepad.buttons_pressed_once[i] = false
					}
					PLATFORM.gamepad.buttons[i] = b
				}

				PLATFORM.gamepad.axes[0] = f32(gamepad_state.gamepad.sThumbLX) / 32768.0
				PLATFORM.gamepad.axes[1] = f32(gamepad_state.gamepad.sThumbLY) / 32768.0 * -1.0
				PLATFORM.gamepad.axes[2] = f32(gamepad_state.gamepad.sThumbRX) / 32768.0
				PLATFORM.gamepad.axes[3] = f32(gamepad_state.gamepad.sThumbRY) / 32768.0 * -1.0
				PLATFORM.gamepad.axes[4] = f32(gamepad_state.gamepad.bLeftTrigger) / 255.0
				PLATFORM.gamepad.axes[5] = f32(gamepad_state.gamepad.bRightTrigger) / 255.0
			} else {
				PLATFORM.gamepad.connected = false
			}
		}

	}
	when ODIN_OS == .JS {
		frame()
		get_state(&PLATFORM.gamepad)
	}

	PLATFORM.delta = f32(time.duration_seconds(time.tick_since(PLATFORM.last_tick)))
	PLATFORM.last_tick = time.tick_now()
	PLATFORM.time_since_start = f32(time.duration_seconds(time.tick_since(PLATFORM.start_tick)))
}

resize_window :: proc (width: f32, height: f32) {
	when ODIN_OS == .Windows{
		
		windows.SetWindowLongW(PLATFORM.hwnd, windows.GWL_STYLE, i32(window_style))
		c_rect, w_rect: windows.RECT
		windows.GetClientRect(PLATFORM.hwnd, &c_rect)
		windows.GetWindowRect(PLATFORM.hwnd, &w_rect)
		diff_x := (w_rect.right - w_rect.left) - c_rect.right
		diff_y := (w_rect.bottom - w_rect.top) - c_rect.bottom

		// center window
		w_rect.left = (windows.GetSystemMetrics(windows.SM_CXSCREEN) - i32(width)) / 2
		w_rect.top = (windows.GetSystemMetrics(windows.SM_CYSCREEN) - i32(height)) / 2
		windows.MoveWindow(PLATFORM.hwnd, w_rect.left, w_rect.top, i32(width + f32(diff_x)), i32(height + f32(diff_y)), true)
		
		if PLATFORM.is_fullscreen{
			PLATFORM.is_fullscreen = false
			resize_window(width, height)
		}
		
		PLATFORM.width = width
		PLATFORM.height = height
	}
}

set_fullscreen :: proc() {
	when ODIN_OS == .Windows{
		m_width, m_height := windows.GetSystemMetrics(windows.SM_CXSCREEN), windows.GetSystemMetrics(windows.SM_CYSCREEN)
		windows.SetWindowLongW(PLATFORM.hwnd, windows.GWL_STYLE, i32(window_style & ~windows.WS_OVERLAPPEDWINDOW))
		windows.SetWindowPos(PLATFORM.hwnd, windows.HWND_TOP, 0, 0, m_width, m_height, windows.SWP_FRAMECHANGED)
		PLATFORM.width = f32(m_width)
		PLATFORM.height = f32(m_height)
		PLATFORM.is_fullscreen = true
	}
}

should_close :: proc() -> bool {
	return PLATFORM.should_close
}

window_width :: proc() -> f32 {
	return PLATFORM.width
}

window_height :: proc() -> f32 {
	return PLATFORM.height
}

key_pressed :: proc(key: Key) -> bool {
	return PLATFORM.keys[key]
}

key_pressed_once :: proc(key: Key) -> bool {
	return PLATFORM.keys_pressed_once[key]
}

mouse_pos :: proc() -> Vec2 {
	return {PLATFORM.mouse_pos[0], PLATFORM.mouse_pos[1]}
}

mouse_moved :: proc() -> bool{
	return PLATFORM.mouse_pos != PLATFORM.last_mouse_pos
}

mouse_button_pressed :: proc(button: Mouse_Button) -> bool {
	return PLATFORM.mouse_buttons[button]
}

mouse_button_pressed_once :: proc(button: Mouse_Button) -> bool {
	return PLATFORM.mouse_buttons_once[button]
}


gamepad_pressed :: proc(button: Gamepad_Button) -> bool {
	return PLATFORM.gamepad.buttons[button]
}

gamepad_pressed_once :: proc(button: Gamepad_Button) -> bool {
	return PLATFORM.gamepad.buttons_pressed_once[button]
}

// use math.abs to check for deadzone
gamepad_axis :: proc(axis: Gamepad_Axis) -> f32 {
	return PLATFORM.gamepad.axes[axis]
}

gamepad_axis_once :: proc(axis: Gamepad_Axis, value: f32) -> bool {
	up := value > 0.0

	if up && PLATFORM.gamepad.axes[axis] >= value && !PLATFORM.gamepad.axes_once[axis] {
		PLATFORM.gamepad.axes_once[axis] = true
		return true
	}

	if !up && PLATFORM.gamepad.axes[axis] <= value && !PLATFORM.gamepad.axes_once[axis] {
		PLATFORM.gamepad.axes_once[axis] = true
		return true
	}

	return false
}

dt :: proc() -> f32 {
	return PLATFORM.delta
}

time_since_start :: proc() -> f32{
	return PLATFORM.time_since_start
}

time :: proc() -> f64{
	return f64(time.since(time.Time{0}))
}