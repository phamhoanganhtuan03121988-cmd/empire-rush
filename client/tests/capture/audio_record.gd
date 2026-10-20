## Phase 5.1: records what the Master bus actually mixes during one human
## roll (AudioEffectRecord) and prints a loudness timeline with the beat
## times, so sound sync is measured from the mixed signal, not from code.
## No speaker is involved: this proves signal, not that a person heard it.
##   godot --path client --script res://tests/capture/audio_record.gd -- --out=FILE.wav
extends SceneTree

var main: Node3D
var beats: Array = []
var t0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = {"players": "2", "seed": "3", "quality": "low", "still": "1", "telemetry": "user://test_telemetry/audio_rec.json"}
	root.add_child(main)
	main.presenter.cue.connect(func(n: String, _d: Dictionary): beats.append([n, Time.get_ticks_msec() - t0]))
	var roll: Button = null
	for i in 1200:
		await process_frame
		for act in main.hud.actions:
			if act["type"] == ErCommand.ROLL_DICE and not act["button"].disabled:
				roll = act["button"]
		if roll and main.presenter.is_idle():
			break
	rec.set_recording_active(true)
	t0 = Time.get_ticks_msec()
	roll.pressed.emit()
	await create_timer(2.6).timeout
	rec.set_recording_active(false)
	var wav := rec.get_recording()
	if wav == null:
		print("AUDIO_RECORD none (no mixing on this audio driver)")
		quit(1)
		return
	wav.save_to_wav(args.get("out", "user://audio_rec.wav"))
	print("AUDIO_DRIVER ", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?", " mix_rate=", AudioServer.get_mix_rate())
	for b in beats:
		print("BEAT %s %d" % [b[0], b[1]])
	quit(0)
