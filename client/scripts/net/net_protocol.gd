## M3 technical spike: wire format for PROTOCOL.md v1 (JSON text frames).
## Transport-agnostic: the same frames go over the in-memory loopback used by
## tests today and over WebSocket (wss://) in M3. Not used by the offline game.
class_name NetProtocol
extends RefCounted

const VERSION := 1
const MAX_FRAME := 16384  # PROTOCOL.md §2: 16 KiB

# Client -> server
const HELLO := "Hello"            # {token, last_seq}
const COMMAND := "Command"        # {command: <ErCommand envelope>}
const SNAPSHOT_REQ := "SnapshotRequest"
# Server -> client
const WELCOME := "Welcome"        # {seat, player_id}
const SNAPSHOT := "Snapshot"      # {snapshot, seq, state_version, public_hash}
const EVENTS := "Events"          # {events, state_version, public_hash}
const RESULT := "CommandResult"   # {command_id, ok, error?, state_version, duplicate?}
const ERROR := "Error"            # {code}

const E_PAYLOAD_TOO_LARGE := "PAYLOAD_TOO_LARGE"
const E_UNAUTHENTICATED := "UNAUTHENTICATED"
const E_PROTOCOL_UNSUPPORTED := "PROTOCOL_UNSUPPORTED"
const E_BAD_REQUEST := "BAD_REQUEST"


static func encode(kind: String, body: Dictionary) -> String:
	var msg := body.duplicate()
	msg["kind"] = kind
	msg["protocol_version"] = VERSION
	return JSON.stringify(msg)


## Returns {ok: true, msg} or {ok: false, error}. Frame size and protocol
## version are checked before anything else (PROTOCOL.md §2, §4).
static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_FRAME:
		return {"ok": false, "error": E_PAYLOAD_TOO_LARGE}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("kind"):
		return {"ok": false, "error": E_BAD_REQUEST}
	if int(parsed.get("protocol_version", -1)) != VERSION:
		return {"ok": false, "error": E_PROTOCOL_UNSUPPORTED}
	return {"ok": true, "msg": _ints(parsed)}


## JSON numbers arrive as floats; rules code wants ints for whole numbers.
static func _ints(v: Variant) -> Variant:
	if v is float and v == floor(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _ints(v[k])
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(_ints(x))
		return a
	return v


## Stable hash of a public snapshot (keys sorted) so every client can prove
## it holds exactly the server's state for a given state_version.
static func public_hash(snapshot: Dictionary) -> String:
	return JSON.stringify(_ints(snapshot), "", true).sha256_text()
