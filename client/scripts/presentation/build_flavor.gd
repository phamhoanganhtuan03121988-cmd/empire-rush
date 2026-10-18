## Which build flavour is running (M2.2.1). Device-measurement tools (the
## DeviceProbe reports, the DevPanel overlay/benchmark and session telemetry
## files) exist only in:
## - debug builds (editor runs, `--export-debug`, tests), and
## - release builds exported with the custom feature tag "device_tools"
##   (the internal-test presets in export_presets.cfg).
## A public release build has neither, so the tools are not created at all:
## no hidden gesture, command-line flag or file can turn them on.
class_name BuildFlavor
extends RefCounted

const DEVICE_TOOLS_FEATURE := "device_tools"

## Tests only: -1 = detect, 0 = behave like a public release, 1 = internal.
static var override := -1


static func device_tools_enabled() -> bool:
	if override >= 0:
		return override == 1
	return OS.is_debug_build() or OS.has_feature(DEVICE_TOOLS_FEATURE)


static func name() -> String:
	if not device_tools_enabled():
		return "public-release"
	return "debug" if OS.is_debug_build() and override < 0 else "internal-test"
