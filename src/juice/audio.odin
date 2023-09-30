package juice


when ODIN_OS == .Windows {
	import "audio/wasapi"
	import "core:sys/windows"
	import "core:thread"
	import "core:sync"
	import "core:math"
	import "audio"

	mutex_lock: sync.Mutex
}
when ODIN_OS == .JS {
	foreign import "audio"
	import "core:fmt"

	@(default_calling_convention = "c")
	foreign audio {
		init_audio :: proc() ---
		_load_sound :: proc(ptr: rawptr, len: i32) -> u32 ---
		play_sound :: proc(sound_file_id: u32, volume: f32 = 1., pitch: f32 = 1., looped: bool = false) -> u32 ---
		stop_sound :: proc(sound_play_id: u32) ---
		stop_all_sounds :: proc() ---
		pitch_sound :: proc(sound_play_id: u32, pitch: f32) ---
		volume_sound :: proc(sound_play_id: u32, volume: f32) ---
	}

	load_sound :: proc(a_bytes: []u8) -> u32{
		a := raw_data(a_bytes)
		b := i32(len(a_bytes))
		return _load_sound(a, b)
	}
}

WavFile :: struct {
	//RIFF chunk
	riff_id:         u32,
	riff_chunk_size: u32,
	wave_id:         u32,

	// fmt chunk
	fmt_id:          u32,
	fmt_chunk_size:  u32,
	audio_format:    u16,
	num_channels:    u16,
	sample_rate:     u32,
	byte_rate:       u32,
	block_align:     u16,
	bits_per_sample: u16,

	// data chunk
	data_id:         u32,
	data_chunk_size: u32,
	// samples: [^]u16,
}


sound_files: [dynamic]SoundFile
sounds_playing: [dynamic]SoundPlaying
sound_playing_id_counter: u32

SoundFile :: struct {
	channels:     u32,
	sample_count: u32,
	sample_data:  [^]u16,
}

SoundPlaying :: struct {
	sound_file_id: u32,
	sample_index:  f32,
	volume:        f32,
	pitch:         f32,
	looped:        bool,
	playing:       bool,
}


when ODIN_OS == .Windows {
	load_sound :: proc(a_bytes: []u8) -> u32 {
		// wav file
		if a_bytes[0] == 'R' && a_bytes[1] == 'I' && a_bytes[2] == 'F' && a_bytes[3] == 'F' {
			wav := (cast(^WavFile)(raw_data(a_bytes)))
			assert(wav.wave_id == 0x45564157, "not a WAVE file")
			assert(wav.fmt_id == 0x20746D66, "not a fmt chunk")
			assert(wav.audio_format == 1, "not PCM")
			assert(wav.data_id == 0x61746164, "not a data chunk")
			// assert(wav.num_channels == 2, "only stereo supported")
			assert(wav.bits_per_sample == 16, "only 16 bit supported")
			assert(wav.sample_rate == 44100, "only 44100 sample rate supported")

			sample_data := cast([^]u16)(raw_data(a_bytes[size_of(WavFile):]))
			channels := u32(wav.num_channels)
			chank_size := wav.data_chunk_size
			if wav.num_channels == 1 {
				// convert mono to stereo
				samples := wav.data_chunk_size / (u32(wav.bits_per_sample) / 8)
				data := make([]u16, samples * 2)
				for i in 0 ..<samples {
					data[i * 2 + 0] = cast(u16)(sample_data[i])
					data[i * 2 + 1] = cast(u16)(sample_data[i])
				}
				channels = 2
				chank_size = samples * 2 * (u32(wav.bits_per_sample) / 8)
				sample_data = cast([^]u16)(&data[0])
			}

			a := SoundFile {
				channels     = channels,
				sample_count = chank_size / (channels * size_of(u16)),
				sample_data  = sample_data,
			}
			id := u32(len(sound_files))
			append(&sound_files, a)
			return id
		}
		// ogg file
		if a_bytes[0] == 'O' && a_bytes[1] == 'g' && a_bytes[2] == 'g' && a_bytes[3] == 'S' {
			channels: i32 = 0
			sample_rate: i32 = 0
			data: [^]i16
			samples := audio.decode_memory(
				raw_data(a_bytes),
				i32(len(a_bytes)),
				&channels,
				&sample_rate,
				&data,
			)

			assert(channels == 2, "only stereo supported")
			assert(sample_rate == 44100, "only 44100 sample rate supported")

			a := SoundFile {
				channels     = u32(channels),
				sample_count = u32(samples),
				sample_data  = cast([^]u16)(cast(^u16)(data)),
			}
			id := u32(len(sound_files))
			append(&sound_files, a)
			return id
		}
		assert(false, "audio file format not supported")
		return 0
	}

	play_sound :: proc(
		#any_int sound_file_id: u32,
		volume: f32 = 1.,
		pitch: f32 = 1.,
		looped: bool = false,
	) -> u32 {
		assert(sound_file_id < u32(len(sound_files)), "invalid sound file id")

		for !sync.mutex_try_lock(&mutex_lock) {
		}
		defer sync.mutex_unlock(&mutex_lock)

		// sound already playing
		for s in &sounds_playing {
			if s.sound_file_id == sound_file_id && s.sample_index == 0 {
				return s.sound_file_id
			}
		}

		id := sound_file_id
		append(
			&sounds_playing,
			SoundPlaying{
				sound_file_id = id,
				sample_index = 0,
				volume = volume,
				pitch = pitch,
				looped = looped,
				playing = true,
			},
		)

		sound_playing_id_counter += 1
		if sound_playing_id_counter > 4_294_967_290 {
			sound_playing_id_counter = 0
		}

		return id
	}

	stop_sound :: proc(sound_play_id: u32) {
		for sound in &sounds_playing {
			if sound.sound_file_id == sound_play_id {
				sound.playing = false
				break
			}
		}
	}

	stop_all_sounds :: proc() {
		for sound in &sounds_playing {
			sound.playing = false
		}
	}

	pitch_sound :: proc(sound_play_id: u32, pitch: f32) {
		for sound in &sounds_playing {
			if sound.sound_file_id == sound_play_id {
				sound.pitch = pitch
				break
			}
		}
	}

	volume_sound :: proc(sound_play_id: u32, volume: f32) {
		for sound in &sounds_playing {
			if sound.sound_file_id == sound_play_id {
				sound.volume = volume
				break
			}
		}
	}


	init_audio :: proc() {
		when ODIN_OS == .Windows {
			thread.create_and_start(
				proc() {

					hr := windows.CoInitializeEx(nil, windows.COINIT.SPEED_OVER_MEMORY)
					assert(hr >= 0, "CoInitializeEx failed")

					buffer_end_event := windows.CreateEventW(nil, false, false, nil)

					using wasapi
					device_enumerator: ^IMMDeviceEnumerator
					hr = windows.CoCreateInstance(
						&CLSID_MMDeviceEnumerator,
						nil,
						CLSCTX_ALL,
						IMMDeviceEnumerator_UUID,
						cast(^rawptr)&device_enumerator,
					)
					assert(hr >= 0, "CoCreateInstance failed")
					defer device_enumerator->Release()

					audio_device: ^IMMDevice
					hr =
					device_enumerator->GetDefaultAudioEndpoint(
						EDataFlow.eRender,
						ERole.eConsole,
						&audio_device,
					)
					assert(hr >= 0, "GetDefaultAudioEndpoint failed")
					defer audio_device->Release()

					audio_client: ^IAudioClient2
					hr =
					audio_device->Activate(
						IAudioClient2_UUID,
						CLSCTX_ALL,
						nil,
						cast(^rawptr)&audio_client,
					)
					assert(hr >= 0, "Device Activate failed")

					state: DEVICE_STATE
					audio_device->GetState(&state)
					assert(u32(state) == 1, "Device not active")

					channels: u16 = 2
					sample_rate: u32 = 44100
					buffer_frames: u32 = 4096
					nBlockAlign: u16 = (channels * 16) / 8
					format := WAVEFORMATEX {
						wFormatTag      = 1, // WAVE_FORMAT_EXTENSIBLE 0xFFFE maybe need WAVE_FORMAT_PCM 1
						nChannels       = channels,
						nSamplesPerSec  = sample_rate,
						wBitsPerSample  = 16,
						nBlockAlign     = nBlockAlign,
						nAvgBytesPerSec = u32(sample_rate) * u32(nBlockAlign),
					}


					AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM: u32 = 0x80000000
					AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY: u32 = 0x08000000
					AUDCLNT_STREAMFLAGS_EVENTCALLBACK: u32 = 0x00040000

					flags: u32 =
						AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
						AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
						AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY

					dur := f64(buffer_frames) / (f64(sample_rate) * 1 / 10000000.0)
					hr =
					audio_client->Initialize(
						AUDCLNT_SHAREMODE.SHARED,
						flags,
						i64(dur),
						0,
						&format,
						nil,
					)
					assert(hr >= 0, "Initialize failed")

					dst_buffer_frames: u32 = 0
					hr = audio_client->GetBufferSize(&dst_buffer_frames)
					assert(hr >= 0, "GetBufferSize failed")

					render_client: ^IAudioRenderClient
					hr =
					audio_client->GetService(IAudioRenderClient_UUID, cast(^rawptr)&render_client)
					assert(hr >= 0, "GetService failed")

					hr = audio_client->SetEventHandle(buffer_end_event)
					assert(hr >= 0, "SetEventHandle failed")

					hr = audio_client->Start()
					assert(hr >= 0, "Start failed")


					for {
						windows.WaitForSingleObject(buffer_end_event, windows.INFINITE)


						padding: u32 = 0
						if audio_client->GetCurrentPadding(&padding) < 0 {
							continue
						}

						frames_to_write := dst_buffer_frames - padding
						if frames_to_write == 0 {
							continue
						}

						buffer: ^u8
						if render_client->GetBuffer(frames_to_write, &buffer) < 0 {
							continue
						}
						assert(buffer != nil, "GetBuffer failed")

						buffer_ptr: [^]i16 = cast([^]i16)(buffer)

						// clear buffer
						for i := 0; i < int(frames_to_write) * 2; i += 1 {
							buffer_ptr[i] = 0
						}

						for !sync.mutex_try_lock(&mutex_lock) {
						}
						defer sync.mutex_unlock(&mutex_lock)

						for s, s_i in &sounds_playing {
							if !s.playing {
								continue
							}

							sound_file := sound_files[s.sound_file_id]
							offset := 0
							for i := u32(0); i < frames_to_write; i += 1 {

								left_sample_index := sound_file.channels * u32(s.sample_index)
								right_sample_index := left_sample_index + sound_file.channels - 1

								left_sample_index_next := right_sample_index + 1
								right_sample_index_next :=
									left_sample_index_next + sound_file.channels - 1

								left_sample := f32(
									(cast(^i16)(sound_file.sample_data[left_sample_index:]))^,
								)
								right_sample := f32(
									(cast(^i16)(sound_file.sample_data[right_sample_index:]))^,
								)
								left_sample_next := f32(
									(cast(^i16)(sound_file.sample_data[left_sample_index_next:]))^,
								)
								right_sample_next := f32(
									(cast(^i16)(sound_file.sample_data[right_sample_index_next:]))^,
								)


								left_lerp := math.lerp(
									left_sample,
									left_sample_next,
									s.sample_index - math.floor(s.sample_index),
								)
								right_lerp := math.lerp(
									right_sample,
									right_sample_next,
									s.sample_index - math.floor(s.sample_index),
								)

								s.sample_index += s.pitch


								buffer_ptr[offset] += i16(left_lerp * s.volume)
								offset += 1
								buffer_ptr[offset] += i16(right_lerp * s.volume)
								offset += 1

								if u32(s.sample_index) >= sound_file.sample_count - 1 {
									if s.looped {
										s.sample_index = 0
									} else {
										unordered_remove(&sounds_playing, s_i)
										break
									}
								}


							}
						}
						render_client->ReleaseBuffer(frames_to_write, 0)

					}
				},
			)

		}
	}
}
