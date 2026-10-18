## M2.2 device validation: frame statistics used by the on-device reports and
## the committed export configuration (no signing secrets, data packed).
extends TestCase


func test_frame_stats_percentiles() -> void:
	var f := PackedFloat32Array()
	for i in 100:
		f.append(float(i + 1))  # 1..100 ms
	var s := DeviceProbe.frame_stats(f)
	assert_eq(s["frames"], 100, "frames")
	assert_eq(s["p50_ms"], 50.0, "p50")
	assert_eq(s["p95_ms"], 95.0, "p95")
	assert_eq(s["p99_ms"], 99.0, "p99")
	assert_eq(s["max_ms"], 100.0, "max")
	assert_eq(s["pct_over_33ms"], 67.0, "share of frames slower than 30 FPS")
	assert_eq(s["pct_over_16_7ms"], 84.0, "share of frames slower than 60 FPS")
	# 100 frames in 5050 ms.
	assert_true(absf(s["mean_fps"] - 19.8) < 0.05, "mean fps %s" % s["mean_fps"])


func test_frame_stats_empty() -> void:
	assert_eq(DeviceProbe.frame_stats(PackedFloat32Array())["frames"], 0, "empty")


func _presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg loads")
	return cfg


func _preset_sections(cfg: ConfigFile, platform: String) -> Array[String]:
	var out: Array[String] = []
	for s in cfg.get_sections():
		if s.ends_with(".options"):
			continue
		if cfg.get_value(s, "platform", "") == platform:
			out.append(s)
	return out


func test_ios_presets_have_no_committed_signing_identity() -> void:
	var cfg := _presets()
	var secs := _preset_sections(cfg, "iOS")
	assert_eq(secs.size(), 2, "iOS internal + public presets")
	for s in secs:
		var o := s + ".options"
		# The team ID is injected by scripts/export_build.sh from IOS_TEAM_ID.
		assert_eq(cfg.get_value(o, "application/app_store_team_id", "x"), "", "%s: team id not committed" % s)
		assert_eq(cfg.get_value(o, "application/export_project_only", false), true, "%s: Xcode project export" % s)
		for key in cfg.get_section_keys(o):
			var k: String = key
			if k.contains("provisioning_profile") or k.contains("code_sign"):
				assert_eq(str(cfg.get_value(o, k)), "", "%s: %s not committed" % [s, k])


func test_presets_pack_data_and_skip_tests() -> void:
	var cfg := _presets()
	for platform in ["iOS", "Linux"]:
		var secs := _preset_sections(cfg, platform)
		assert_true(secs.size() > 0, "%s preset exists" % platform)
		for s in secs:
			assert_true(str(cfg.get_value(s, "include_filter", "")).contains("data/*.json"), "%s packs rules JSON" % s)
			assert_true(str(cfg.get_value(s, "exclude_filter", "")).contains("tests/*"), "%s excludes tests" % s)


## M2.2.1 release lock: device tools only in "Internal Test" presets; every
## platform has a public preset without them (and, on iOS, without Files-app
## access to user data).
func test_device_tools_only_in_internal_presets() -> void:
	var cfg := _presets()
	for platform in ["iOS", "Linux"]:
		var publics := 0
		var internals := 0
		for s in _preset_sections(cfg, platform):
			var name: String = cfg.get_value(s, "name", "")
			var feats := str(cfg.get_value(s, "custom_features", "")).split(",", false)
			var has_tools := false
			for f in feats:
				if f.strip_edges() == BuildFlavor.DEVICE_TOOLS_FEATURE:
					has_tools = true
			if name.ends_with("Public Release"):
				publics += 1
				assert_false(has_tools, "%s must not enable device tools" % name)
				if platform == "iOS":
					var o := s + ".options"
					assert_eq(cfg.get_value(o, "user_data/accessible_from_files_app", true), false, "%s: no Files-app access" % name)
					assert_eq(cfg.get_value(o, "user_data/accessible_from_itunes_sharing", true), false, "%s: no iTunes sharing" % name)
			elif name.ends_with("Internal Test"):
				internals += 1
				assert_true(has_tools, "%s enables device tools" % name)
			else:
				assert_true(false, "preset '%s' must be named '... Internal Test' or '... Public Release'" % name)
		assert_eq(publics, 1, "%s: one public preset" % platform)
		assert_eq(internals, 1, "%s: one internal preset" % platform)


func test_build_flavor_policy() -> void:
	var saved := BuildFlavor.override
	BuildFlavor.override = 0
	assert_false(BuildFlavor.device_tools_enabled(), "public release: tools off")
	assert_eq(BuildFlavor.name(), "public-release", "name")
	BuildFlavor.override = 1
	assert_true(BuildFlavor.device_tools_enabled(), "internal: tools on")
	BuildFlavor.override = -1
	# The test runner itself is a debug build, so detection says "on".
	assert_eq(BuildFlavor.device_tools_enabled(), OS.is_debug_build() or OS.has_feature("device_tools"), "detection")
	BuildFlavor.override = saved


func test_app_icon_is_set() -> void:
	var icon: String = ProjectSettings.get_setting("application/config/icon", "")
	assert_true(icon != "" and ResourceLoader.exists(icon), "project icon set (iOS export requires one)")
