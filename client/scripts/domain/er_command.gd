## Command/error vocabulary shared by the rules engine, bots, tests and (later)
## the network gateway. Mirrors docs/PROTOCOL.md §3 and §6.
class_name ErCommand
extends RefCounted

const PROTOCOL_VERSION := 1

const ROLL_DICE := "RollDice"
const BUY_PROPERTY := "BuyProperty"
const PASS_PROPERTY := "PassProperty"
const PLACE_BID := "PlaceBid"
const CHOOSE_OPTION := "ChooseOption"
const UPGRADE := "Upgrade"
const PROPOSE_TRADE := "ProposeTrade"
const RESPOND_TRADE := "RespondTrade"
const USE_ABILITY := "UseAbility"
const LIQUIDATE := "Liquidate"
const DECLARE_BANKRUPTCY := "DeclareBankruptcy"
const END_TURN := "EndTurn"

const E_BAD_REQUEST := "BAD_REQUEST"
const E_PROTOCOL_UNSUPPORTED := "PROTOCOL_UNSUPPORTED"
const E_NOT_SEATED := "NOT_SEATED"
const E_STALE_STATE := "STALE_STATE"
const E_MATCH_ENDED := "MATCH_ENDED"
const E_NOT_YOUR_TURN := "NOT_YOUR_TURN"
const E_WRONG_PHASE := "WRONG_PHASE"
const E_DEADLINE_PASSED := "DEADLINE_PASSED"
const E_INVALID_TARGET := "INVALID_TARGET"
const E_INSUFFICIENT_FUNDS := "INSUFFICIENT_FUNDS"
const E_NOT_OWNER := "NOT_OWNER"
const E_DISTRICT_INCOMPLETE := "DISTRICT_INCOMPLETE"
const E_MAX_LEVEL := "MAX_LEVEL"
const E_ABILITY_UNAVAILABLE := "ABILITY_UNAVAILABLE"
const E_ACTION_USED := "STRATEGY_ACTION_USED"
const E_TRADE_INVALID := "TRADE_INVALID"
const E_BID_TOO_LOW := "BID_TOO_LOW"


static func make(match_id: String, player_id: String, command_id: String, expected_version: int,
		type: String, payload: Dictionary = {}) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION, "match_id": match_id, "command_id": command_id,
		"player_id": player_id, "expected_state_version": expected_version,
		"type": type, "payload": payload,
	}
