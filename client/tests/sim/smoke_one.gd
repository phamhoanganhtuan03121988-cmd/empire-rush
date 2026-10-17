extends SceneTree
func _initialize() -> void:
	var cfg := GameConfig.load_from_dir()
	if not cfg.is_valid():
		print("CONFIG ERRORS: ", cfg.errors)
		quit(1)
		return
	var r := MatchSimulator.run(cfg, 1, 4, {})
	r.erase("round_samples")
	print(JSON.stringify(r, "  "))
	quit(0)
