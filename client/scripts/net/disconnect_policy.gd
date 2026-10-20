## M3 spike (Phase 2, C4): what the server does with a seat whose client has
## disconnected. CONFIGURATION, not a game rule: the owner picks the final
## policy after playtests (docs/M3_ARCHITECTURE.md §Disconnect policy).
## While a seat is held the match is never paused for others: the engine's
## own turn timers still apply (auto-roll / pass to auction / end turn), so a
## missing player can never stall the table.
class_name DisconnectPolicy
extends RefCounted

## Seat held; only the engine timers act for it (slow: one full turn timer
## per decision).
const TIMERS := "timers"
## After `hold_ms` a server-side bot plays the seat until the player
## reconnects (the player gets the seat back on reconnect).
const BOT := "bot"
## Listed for completeness, NOT implemented: removing a player mid-match needs
## a rules decision (what happens to cash and properties), see the report.
const FORFEIT := "forfeit"

## Proposed default for testing only: hold the seat 60 s, then a bot plays it.
var hold_ms := 60000
var on_expiry := BOT
## Bot think time after each state change, so humans can follow its moves.
var bot_think_ms := 1200


static func from_dict(d: Dictionary) -> DisconnectPolicy:
	var p := DisconnectPolicy.new()
	p.hold_ms = int(d.get("hold_ms", p.hold_ms))
	p.on_expiry = str(d.get("on_expiry", p.on_expiry))
	p.bot_think_ms = int(d.get("bot_think_ms", p.bot_think_ms))
	assert(p.on_expiry in [TIMERS, BOT], "unsupported disconnect policy: %s" % p.on_expiry)
	return p


func to_dict() -> Dictionary:
	return {"hold_ms": hold_ms, "on_expiry": on_expiry, "bot_think_ms": bot_think_ms}
