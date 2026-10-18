## M3 technical spike: deterministic in-memory network between one MatchHost
## and N NetClients. Each link is ordered (like a WebSocket over TCP) with a
## random per-frame latency; a disconnect drops every frame in flight on that
## link, which is how commands and results really get lost. Time is
## simulated (no sleeps), so multi-client tests are exact and fast.
class_name LoopbackNetwork
extends RefCounted

var host: MatchHost
var clients: Array = []      # NetClient per link id
var now_ms := 0
var latency_ms := Vector2i(20, 120)
var rng := RandomNumberGenerator.new()
var frames_dropped := 0
var _up: Array = []          # per link: [[due_ms, text], ...] client -> host
var _down: Array = []        # per link: host -> client
var _connected: Array = []


func setup(p_host: MatchHost, p_clients: Array, seed_value: int) -> void:
	host = p_host
	clients = p_clients
	rng.seed = seed_value
	for i in clients.size():
		_up.append([])
		_down.append([])
		_connected.append(false)


## Breaks the client <-> network reference cycle (RefCounted would leak).
func teardown() -> void:
	for c in clients:
		c.net = null
	clients = []
	host = null


func connect_client(link: int) -> void:
	_connected[link] = true
	clients[link].on_connected(self, link)


func disconnect_client(link: int) -> void:
	_connected[link] = false
	frames_dropped += _up[link].size() + _down[link].size()
	_up[link].clear()
	_down[link].clear()
	host.disconnect_link(link)
	clients[link].on_disconnected()


func is_connected_link(link: int) -> bool:
	return _connected[link]


func _due(queue: Array) -> int:
	# Ordered link: a frame never overtakes the previous one.
	var last: int = queue.back()[0] if not queue.is_empty() else now_ms
	return maxi(last, now_ms + rng.randi_range(latency_ms.x, latency_ms.y))


func send_up(link: int, text: String) -> void:
	if not _connected[link]:
		frames_dropped += 1
		return
	_up[link].append([_due(_up[link]), text])


func _send_down(link: int, text: String) -> void:
	if link < 0 or link >= _down.size() or not _connected[link]:
		frames_dropped += 1
		return
	_down[link].append([_due(_down[link]), text])


## Advances simulated time by `dt_ms`: server timers, then deliveries.
func step(dt_ms: int) -> void:
	now_ms += dt_ms
	for o in host.tick(now_ms):
		_send_down(o[0], o[1])
	for link in _up.size():
		while not _up[link].is_empty() and _up[link][0][0] <= now_ms:
			var f: Array = _up[link].pop_front()
			for o in host.handle_frame(link, f[1]):
				_send_down(o[0], o[1])
	for link in _down.size():
		while not _down[link].is_empty() and _down[link][0][0] <= now_ms:
			var f: Array = _down[link].pop_front()
			clients[link].handle_frame(f[1])
	for c in clients:
		c.tick(now_ms)
