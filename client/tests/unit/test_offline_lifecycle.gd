## M2.2.1 offline lifecycle: while the app is in the background the offline
## match clock (turn / auction / trade / rescue deadlines and the 30-minute
## cap) does not move. Time is fully simulated: frames are fed to
## LocalMatch._process() by hand and real time comes from an injected fake,
## so nothing sleeps and nothing depends on machine speed.
## The strongest check: a run with background periods produces exactly the
## same engine event log as a reference run that only saw the foreground time.
extends TestCase

const STEP := 0.25  # seconds per simulated foreground frame
const RESUME_FRAME_S := 0.1  # real time between resume and the first frame

var _config: GameConfig


func _cfg() -> GameConfig:
	if _config == null:
		_config = GameConfig.load_from_dir()
	return _config


## Builds an offline match (seat 0 human, others bots) with a fake real-time
## source. `bots_act` false keeps bots idle so every turn runs to its timeout.
func _match(players: int, seed_value: int, bots_act: bool, mobile_focus_policy := true) -> Dictionary:
	var m := LocalMatch.new()
	var seats: Array = []
	for i in players:
		seats.append({"player_id": "p%d" % i, "character_id": ["TYCOON", "INVESTOR", "NEGOTIATOR", "TYCOON"][i]})
	m.start(_cfg(), seats, seed_value, [0] as Array[int])
	m.can_act = func(): return bots_act
	m.bot_delay_range = Vector2(0.5, 1.0)
	m.pause_on_focus_loss = mobile_focus_policy
	var wall := {"us": 0}
	m.lifecycle.wall_us = func() -> int: return wall["us"]
	return {"m": m, "wall": wall}


func _frame(h: Dictionary, delta: float) -> void:
	h["wall"]["us"] += int(delta * 1000000.0)
	h["m"]._process(delta)


func _foreground(h: Dictionary, seconds: float) -> void:
	var n := int(round(seconds / STEP))
	for i in n:
		_frame(h, STEP)


## One background period as iOS delivers it: suspend notification, (maybe)
## stray frames, `seconds` of real time passing, resume notification, then a
## first frame whose delta contains the whole suspension. `frame_before_resume`
## covers the other ordering (big frame arrives before the resume notice).
func _background(h: Dictionary, seconds: float, frame_before_resume := false) -> void:
	var m: LocalMatch = h["m"]
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	m._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	m._process(0.5)  # a frame or two can still arrive while suspending
	m._process(0.5)
	h["wall"]["us"] += int(seconds * 1000000.0)
	if frame_before_resume:
		m._process(seconds)
	m._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	h["wall"]["us"] += int(RESUME_FRAME_S * 1000000.0)
	m._process(seconds + RESUME_FRAME_S)


## Reference: the same match fed only the foreground time.
func _reference_resume_frame(h: Dictionary) -> void:
	_frame(h, RESUME_FRAME_S)


func _remaining_ms(h: Dictionary) -> int:
	var m: LocalMatch = h["m"]
	return m.engine.current_deadline_ms() - m.clock.now_ms()


func _count(h: Dictionary, type: String, phase := "") -> int:
	var n := 0
	for ev in h["m"].engine.event_log:
		if ev["type"] == type and (phase == "" or str(ev["data"].get("phase", "")) == phase):
			n += 1
	return n


func _same_log(a: Dictionary, b: Dictionary, what: String) -> void:
	var la: Array = a["m"].engine.event_log
	var lb: Array = b["m"].engine.event_log
	assert_eq(la.size(), lb.size(), "%s: event count" % what)
	assert_eq(JSON.stringify(la), JSON.stringify(lb), "%s: identical event log" % what)
	assert_eq(a["m"].engine.state.state_hash(), b["m"].engine.state.state_hash(), "%s: identical state" % what)


func _free(hs: Array) -> void:
	for h in hs:
		h["m"].free()


# 1. Background with plenty of time left.
func test_background_with_time_left_keeps_remaining_time() -> void:
	var h := _match(2, 11, false)
	_foreground(h, 10.0)
	var before := _remaining_ms(h)
	assert_eq(before, 35000, "35 s left after 10 s")
	_background(h, 300.0)
	assert_eq(_remaining_ms(h), before - int(RESUME_FRAME_S * 1000), "only the real resume frame counted")
	assert_eq(_count(h, "DeadlineExpired"), 0, "no timeout from 5 minutes in the background")
	assert_true(h["m"].lifecycle.withheld_s >= 300.0, "background delta withheld")
	_free([h])


# 2. Background just before the turn would time out.
func test_background_near_deadline_times_out_only_after_foreground_time() -> void:
	var h := _match(2, 12, false)
	_foreground(h, 44.0)
	_background(h, 600.0, true)
	assert_eq(_count(h, "DeadlineExpired"), 0, "no timeout while away or on resume")
	assert_eq(_remaining_ms(h), 900, "0.9 s left after resume")
	_foreground(h, 0.75)
	assert_eq(_count(h, "DeadlineExpired"), 0, "still 0.15 s left")
	_foreground(h, 0.25)
	assert_eq(_count(h, "DeadlineExpired", str(GameState.AWAIT_ROLL)), 1, "timeout fires once the foreground time runs out")
	_free([h])


# 3 + 4. Many background/foreground cycles; resume never resets the timer.
func test_many_cycles_do_not_reset_or_drain_the_turn_timer() -> void:
	var h := _match(2, 13, false)
	_foreground(h, 5.0)
	var expected := 40000
	for i in 6:
		_background(h, 30.0 + i * 50.0, i % 2 == 1)
		expected -= int(RESUME_FRAME_S * 1000)
		assert_eq(_remaining_ms(h), expected, "cycle %d: not reset to 45 s, not drained" % i)
		_foreground(h, 2.0)
		expected -= 2000
		assert_eq(_remaining_ms(h), expected, "cycle %d: foreground time counts" % i)
	assert_eq(h["m"].lifecycle.pause_count, 6, "six pauses")
	assert_eq(_count(h, "DeadlineExpired"), 0, "no timeout")
	_free([h])


# 5. A timeout is applied once, however often the app pauses afterwards.
func test_timeout_fires_once_across_pause_resume() -> void:
	var h := _match(2, 14, false)
	var r := _match(2, 14, false)
	for x in [h, r]:
		_foreground(x, 46.0)
	var after_first := _count(h, "DeadlineExpired")
	assert_true(after_first >= 1, "turn 1 timed out")
	for i in 5:
		_background(h, 120.0)
		_reference_resume_frame(r)
		assert_eq(_count(h, "DeadlineExpired"), after_first, "pause/resume %d adds no timeout" % i)
	for x in [h, r]:
		_foreground(x, 30.0)
	_same_log(h, r, "after repeated pauses")
	_free([h, r])


# 6. The 30-minute cap counts foreground time only.
func test_time_cap_ignores_background_time() -> void:
	var h := _match(2, 15, false)
	var r := _match(2, 15, false)
	for x in [h, r]:
		_foreground(x, 1000.0)
	_background(h, 3600.0)
	_reference_resume_frame(r)
	assert_false(h["m"].engine.is_ended(), "an hour in the background does not end the match")
	for i in 400:
		for x in [h, r]:
			_foreground(x, 5.0)
		if r["m"].engine.is_ended():
			break
	assert_true(h["m"].engine.is_ended(), "match ended")
	var ended: Dictionary = {}
	for ev in h["m"].engine.event_log:
		if ev["type"] == "MatchEnded":
			ended = ev["data"]
	assert_eq(ended.get("reason", ""), "time_cap", "ended by the time cap")
	assert_true(int(ended.get("duration_ms", 0)) >= 1800000 and int(ended.get("duration_ms", 0)) < 1800000 + 120000,
		"cap reached on foreground time (duration %s ms)" % ended.get("duration_ms", 0))
	_same_log(h, r, "time cap run")
	_free([h, r])


# 7. Always in the foreground: nothing changes. Also desktop focus loss.
func test_foreground_only_is_unchanged_and_desktop_focus_loss_does_not_pause() -> void:
	var h := _match(3, 16, true, false)
	var ref_clock := FrameClock.new(0)
	var steps := 0
	for i in 800:
		if i == 200:
			# Desktop policy: alt-tab away and back must not pause the match.
			h["m"]._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			assert_false(h["m"].is_suspended(), "desktop focus loss does not pause")
		if i == 260:
			h["m"]._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_frame(h, STEP)
		ref_clock.tick(STEP)
		steps += 1
	assert_eq(h["m"].clock.now_ms(), ref_clock.now_ms(), "match clock equals plain frame time")
	assert_eq(h["m"].lifecycle.pause_count, 0, "never paused")
	assert_eq(h["m"].lifecycle.withheld_s, 0.0, "nothing withheld")
	assert_true(h["m"].engine.event_log.size() > 20, "bots played (%d events)" % h["m"].engine.event_log.size())
	# Same seed and frames, mobile focus policy, but no lifecycle events at all.
	var r := _match(3, 16, true, true)
	for i in steps:
		_frame(r, STEP)
	_same_log(h, r, "foreground only")
	_free([h, r])


# Bots and animations: with bots acting, a run with background periods still
# matches the foreground-only reference event for event.
func test_bots_and_background_match_reference() -> void:
	var h := _match(4, 17, true)
	var r := _match(4, 17, true)
	for k in 4:
		for x in [h, r]:
			_foreground(x, 37.0)
		_background(h, 90.0 * (k + 1), k == 2)
		_reference_resume_frame(r)
	for x in [h, r]:
		_foreground(x, 20.0)
	_same_log(h, r, "bots + background")
	_free([h, r])


func test_gate_unit_behaviour() -> void:
	var g := LifecycleGate.new()
	var wall := {"us": 0}
	g.wall_us = func() -> int: return wall["us"]
	assert_eq(g.filter(0.016), 0.016, "foreground passes through")
	g.pause("suspended")
	g.pause("focus")
	assert_eq(g.filter(5.0), 0.0, "paused")
	g.resume("suspended")
	assert_true(g.is_paused(), "still paused while focus is out")
	wall["us"] += 2000000
	g.resume("focus")
	wall["us"] += 20000
	assert_true(absf(g.filter(120.0) - 0.02) < 1e-6, "first frame capped to real time since resume")
	assert_eq(g.filter(0.016), 0.016, "then normal again")
	g.resume("never-paused")
	assert_eq(g.pause_count, 1, "one pause period")
	# time_scale: game seconds = real seconds x scale.
	g.pause("suspended")
	g.resume("suspended")
	wall["us"] += 100000
	assert_true(absf(g.filter(10.0, 4.0) - 0.4) < 1e-6, "cap scales with time_scale")
