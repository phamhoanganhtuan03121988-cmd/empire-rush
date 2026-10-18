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


func _preset_section(cfg: ConfigFile, platform: String) -> String:
	for s in cfg.get_sections():
		if s.ends_with(".options"):
			continue
		if cfg.get_value(s, "platform", "") == platform:
			return s
	return ""


func test_ios_preset_has_no_committed_signing_identity() -> void:
	var cfg := _presets()
	var s := _preset_section(cfg, "iOS")
	assert_true(s != "", "iOS preset exists")
	var o := s + ".options"
	# The team ID is injected by scripts/export_build.sh from IOS_TEAM_ID.
	assert_eq(cfg.get_value(o, "application/app_store_team_id", "x"), "", "team id not committed")
	assert_eq(cfg.get_value(o, "application/export_project_only", false), true, "Xcode project export")
	assert_eq(cfg.get_value(o, "user_data/accessible_from_files_app", false), true, "device reports reachable in Files")
	for key in cfg.get_section_keys(o):
		var k: String = key
		if k.contains("provisioning_profile") or k.contains("code_sign"):
			assert_eq(str(cfg.get_value(o, k)), "", "%s not committed" % k)


func test_presets_pack_data_and_skip_tests() -> void:
	var cfg := _presets()
	for platform in ["iOS", "Linux"]:
		var s := _preset_section(cfg, platform)
		assert_true(s != "", "%s preset exists" % platform)
		assert_true(str(cfg.get_value(s, "include_filter", "")).contains("data/*.json"), "%s packs rules JSON" % platform)
		assert_true(str(cfg.get_value(s, "exclude_filter", "")).contains("tests/*"), "%s excludes tests" % platform)


func test_app_icon_is_set() -> void:
	var icon: String = ProjectSettings.get_setting("application/config/icon", "")
	assert_true(icon != "" and ResourceLoader.exists(icon), "project icon set (iOS export requires one)")
