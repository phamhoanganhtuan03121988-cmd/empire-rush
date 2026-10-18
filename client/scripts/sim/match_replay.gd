## Bug reproduction (Phase 2, B3): everything needed to rebuild a match
## exactly - seed, seats, match id, start time and the engine's input log
## (accepted commands + timer advances with their match times). Internal
## builds save it with the session telemetry; `tools/replay_match.gd`
## replays it on a desktop. This is a debug record, NOT match recovery: the
## game never resumes a match from it (force quit = match lost, by design).
class_name MatchReplay
extends RefCounted


static func record(engine: GameEngine) -> Dictionary:
	var s := engine.state
	var seats: Array = []
	for p in s.players:
		seats.append({"player_id": p["player_id"], "character_id": p["character_id"]})
	return {"format": 1, "seed": s.seed_value, "match_id": s.match_id, "start_ms": s.match_start_ms,
		"seats": seats, "input_log": engine.input_log.duplicate(true), "state_version": s.state_version,
		"state_hash": s.state_hash()}


## Replays a record (as parsed from JSON). `until` stops after that many log
## entries (-1 = all) so a bug can be inspected at the step it happened.
## Returns {engine, ok, applied, error}.
static func replay(config: GameConfig, rec: Dictionary, until := -1) -> Dictionary:
	var r: Dictionary = NetProtocol._ints(rec)
	var e := GameEngine.create(config, MatchClock.new(r["start_ms"]), r["seats"], r["seed"], r["match_id"])
	var applied := 0
	for entry in r["input_log"]:
		if until >= 0 and applied >= until:
			break
		e.clock.set_now(entry["at"])
		if entry.has("cmd"):
			var res := e.submit(entry["cmd"])
			if not res["ok"]:
				return {"engine": e, "ok": false, "applied": applied, "error": "entry %d rejected: %s" % [applied, res["error"]]}
		else:
			e.advance()
		applied += 1
	return {"engine": e, "ok": true, "applied": applied, "error": ""}
