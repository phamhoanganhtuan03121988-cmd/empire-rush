## Test-only TLS material: a fresh self-signed certificate for CN=localhost,
## generated at run time into a temp dir. Nothing here is a production
## certificate, and no key or certificate is ever committed to the repo.
##   godot --headless --path client --script res://tools/net/make_test_cert.gd -- --out=DIR [--name=server]
extends SceneTree


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	var out: String = args.get("out", "")
	var name: String = args.get("name", "server")
	DirAccess.make_dir_recursive_absolute(out)
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var now := Time.get_datetime_dict_from_system(true)
	var cert := crypto.generate_self_signed_certificate(key, "CN=localhost,O=EmpireRush test,C=VN",
		"%04d%02d%02d000000" % [now["year"], now["month"], now["day"]], "%04d%02d%02d000000" % [now["year"] + 1, now["month"], now["day"]])
	key.save(out.path_join(name + ".key"))
	cert.save(out.path_join(name + ".crt"))
	print("CERT ", out.path_join(name + ".crt"))
	quit()
