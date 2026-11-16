/**
 * # Card game
 *
 * The pure state of one freeform card table: four seats, one deck, the felt and a short table log.
 * No rules are enforced. Players move the cards and the log records what they did.
 *
 * It holds no item and names no world object. Whoever owns it hands it plain values and is told of every
 * change through [/datum/card_game/var/on_change], so it compiles and runs with nothing around it, as the
 * unit test does. Card datums hold no references and are never deleted, they are dropped with their lists.
 *
 * ## Hidden information
 * Windows refer to cards by a handle, never by identity. [/datum/card_game/proc/move_card] is the only place
 * a card changes zone, and it gives the card a new handle, clears who peeked at it and sets it upright, so
 * nothing about a card follows it from one zone to the next. [/datum/card_game/proc/data_for] is the only
 * place a payload is assembled: a hand is named only to its own seat, a face-down felt card only to the seats
 * that peeked at it, and the deck's order never leaves the server.
 *
 * ## Actions
 * Each action proc takes the acting seat first and checks every value it is given, since the owner passes
 * values from a window straight through. A bad value is refused: the proc returns FALSE and nothing changes.
 * An accepted action logs one event, calls [/datum/card_game/proc/changed] and returns TRUE.
 */
/datum/card_game
	/// The atom seated players must stay next to. Null in a unit test, where nothing measures the distance
	var/atom/host
	/// Called with no arguments after every change
	var/datum/callback/on_change
	/// Called with (seat, the mob that left or null, the mob that sat or null) after a seat changes hands
	var/datum/callback/on_seat_change
	/// One entry per seat, the seated mob or null
	var/list/seats
	/// One entry per seat, TRUE while that seat shows its hand to all
	var/list/showing
	/// One entry per seat, the highest op number handled from that seat, 0 when none
	var/list/acks
	/// The deck item's deckstyle, which windows use to tint card backs
	var/deck_style = ""
	/// TRUE while a deck is in the game. Its cards may all be out of the deck list
	var/has_deck = FALSE
	/// The game deck, /datum/card_game_card, with [1] on top
	var/list/deck
	/// One list per seat of the cards in that hand, in the order they arrived
	var/list/hands
	/// The cards on the felt in paint order, the last one on top
	var/list/felt
	/// Handle the next card entering a hand or the felt gets. Never reused within one game
	var/next_handle = 1
	/// Cards Flip Top has placed since the deck was last shuffled, which picks the next Flip Top spot
	var/flips_since_shuffle = 0
	/// Rises by one on every change
	var/revision = 0
	/// The last GAMING_CLOTH_EVENTS_KEPT table log entries, each an assoc list shaped as the payload's events
	var/list/events
	/// Sequence number of the last event logged
	var/event_seq = 0
	/// The part of the payload every viewer shares, null until the first data_for after a change. Never holds a private key
	var/list/public_cache
	/// The signals registered on every seated mob
	var/static/list/seat_signals = list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_LIVING_DEATH)

/datum/card_game/New()
	. = ..()
	seats = new /list(GAMING_CLOTH_SEATS)
	showing = new /list(GAMING_CLOTH_SEATS)
	acks = new /list(GAMING_CLOTH_SEATS)
	hands = new /list(GAMING_CLOTH_SEATS)
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		showing[seat] = FALSE
		acks[seat] = 0
		hands[seat] = list()
	deck = list()
	felt = list()
	events = list()

/datum/card_game/Destroy(force)
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		var/mob/occupant = seats[seat]
		if(occupant)
			UnregisterSignal(occupant, seat_signals)
	seats = null
	showing = null
	acks = null
	hands = null
	deck = null
	felt = null
	events = null
	public_cache = null
	host = null
	on_change = null
	on_seat_change = null
	return ..()

/**
 * Marks the game changed: a new revision, the shared payload rebuilt on its next read, and the owner told.
 *
 * Every accepted action ends here. A caller tearing the game down clears on_change first if it must not be told.
 */
/datum/card_game/proc/changed()
	revision++
	public_cache = null
	on_change?.Invoke()

/**
 * Appends one table log entry and keeps the last GAMING_CLOTH_EVENTS_KEPT.
 *
 * Every entry goes to every window, so text names a card only through card_words(), which names it only
 * while it is face up on the felt.
 * Arguments:
 * * kind - one of the event kinds of the payload contract
 * * seat - the acting seat, 0 for none
 * * h - the handle of a card now on the felt, left out of the entry when 0 or null
 * * from - "deck" or "seat1" to "seat4", where a newly arrived felt card came from
 */
/datum/card_game/proc/log_event(kind, seat, text, h, from)
	var/list/entry = list("seq" = ++event_seq, "kind" = kind, "seat" = seat, "text" = text)
	if(h)
		entry["h"] = h
	if(from)
		entry["from"] = from
	events += list(entry)
	if(length(events) > GAMING_CLOTH_EVENTS_KEPT)
		events.Cut(1, length(events) - GAMING_CLOTH_EVENTS_KEPT + 1)

/**
 * The whole ui_data payload for one viewer.
 *
 * The shared part is built once per change into public_cache and copied one level here, then each seat's
 * away is written fresh, since nothing announces a player falling unconscious or disconnecting. The viewer's
 * own seat, ack, hand and peeks are added to the copy only. Every top-level key is written on every call,
 * because a window keeps the last value of a key an update leaves out.
 */
/datum/card_game/proc/data_for(mob/user)
	if(isnull(public_cache))
		public_cache = build_public_data()
	var/list/data = public_cache.Copy()

	var/list/cached_seats = public_cache["seats"]
	var/list/seat_entries = list()
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		var/list/entry = cached_seats[seat]
		entry = entry.Copy()
		var/mob/occupant = seats[seat]
		entry["away"] = occupant ? occupant_away(occupant) : FALSE
		seat_entries += list(entry)
	data["seats"] = seat_entries

	var/you = seat_of(user)
	data["you"] = you
	if(!you)
		data["ack"] = 0
		data["hand"] = list()
		data["peeks"] = list()
		return data
	data["ack"] = acks[you]
	data["hand"] = hand_data(you)
	data["peeks"] = peek_data(you)
	return data

/// The payload part every viewer shares. Names only face-up felt cards and the hands of seats that show them
/datum/card_game/proc/build_public_data()
	var/list/seat_entries = list()
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		var/mob/occupant = seats[seat]
		var/list/hand = hands[seat]
		var/list/shown_names = null
		if(occupant && showing[seat])
			shown_names = list()
			for(var/datum/card_game_card/shown_card as anything in hand)
				shown_names += shown_card.name
			// Sorted by name, since arrival order would tell which shown card came from which play
			shown_names = sort_list(shown_names)
		seat_entries += list(list(
			"name" = occupant ? seat_display_name(occupant) : null,
			"cards" = length(hand),
			"showing" = shown_names,
			"away" = FALSE,
			"chips" = 0,
		))

	var/list/felt_entries = list()
	for(var/datum/card_game_card/card as anything in felt)
		felt_entries += list(list(
			"h" = card.handle,
			"x" = card.x,
			"y" = card.y,
			"rot" = card.rot,
			"name" = card.face_up ? card.name : null,
		))

	return list(
		"revision" = revision,
		"seats" = seat_entries,
		"deck" = list("present" = has_deck, "count" = length(deck), "style" = deck_style),
		"pot" = 0,
		"felt" = felt_entries,
		"dice" = list(),
		"events" = events.Copy(),
	)

/// One seat's hand as the payload's hand entries, for that seat's own window only
/datum/card_game/proc/hand_data(seat)
	. = list()
	for(var/datum/card_game_card/card as anything in hands[seat])
		. += list(list("h" = card.handle, "name" = card.name))

/// Handle to name for each face-down felt card the seat peeked at. Keys are text, a number key would index by position
/datum/card_game/proc/peek_data(seat)
	. = list()
	for(var/datum/card_game_card/card as anything in felt)
		if(card.face_up || !card.peekers)
			continue
		if(seat in card.peekers)
			.["[card.handle]"] = card.name

/// TRUE when seat is a whole number from 1 to GAMING_CLOTH_SEATS
/datum/card_game/proc/valid_seat_number(seat)
	return isnum(seat) && seat == round(seat, 1) && seat >= 1 && seat <= GAMING_CLOTH_SEATS

/// TRUE when seat is a valid seat number with someone in it, the check every action makes on its acting seat
/datum/card_game/proc/acting_seat(seat)
	return valid_seat_number(seat) && !isnull(seats[seat])

/// A felt coordinate from a window, rounded and kept inside the edge margin, or null when it is not a number
/datum/card_game/proc/felt_coordinate(value)
	if(!isnum(value))
		return null
	return clamp(round(value, 1), GAMING_CLOTH_EDGE_MARGIN, GAMING_CLOTH_FELT_SIZE - GAMING_CLOTH_EDGE_MARGIN)
