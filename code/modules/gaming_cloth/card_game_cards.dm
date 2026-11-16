/// First Flip Top spot on the felt, the next three follow it along x
#define FLIP_TOP_X 540
#define FLIP_TOP_Y 500
/// Felt units between two Flip Top spots
#define FLIP_TOP_STEP 70
/// Flip Top spots before the next card lands on the first one again
#define FLIP_TOP_SPOTS 4

/**
 * One card of a card game. Plain values only, so it is never deleted and nothing it holds can keep a mob alive.
 */
/datum/card_game_card
	/// The deck's own string for the card, "Ace of Spades" or "The Fool"
	var/name
	/// The number windows know this card by, 0 while it is in the deck. New on every zone change
	var/handle = 0
	/// CARD_ZONE_DECK, CARD_ZONE_HAND or CARD_ZONE_FELT
	var/zone = CARD_ZONE_DECK
	/// The seat whose hand holds the card, 0 outside a hand
	var/seat = 0
	/// Felt x of the card's centre, meaningful only on the felt
	var/x = 0
	/// Felt y of the card's centre, meaningful only on the felt
	var/y = 0
	/// Quarter turns on the felt in degrees, 0, 90, 180 or 270
	var/rot = 0
	/// TRUE while the card lies face up on the felt
	var/face_up = FALSE
	/// Seat numbers that peeked at this face-down card, null when none
	var/list/peekers

/**
 * Moves a card to another zone, the only place a card's zone changes.
 *
 * The card gets a new handle (0 in the deck), loses its peekers and its rotation and lies face down, so a
 * window cannot recognise it after the move by its number, its turn or who looked at it. A card bound for
 * the felt is placed by the caller after this returns.
 * Arguments:
 * * zone - the CARD_ZONE_* it moves to
 * * seat - the receiving hand's seat, for CARD_ZONE_HAND only
 * * position - where it goes in the receiving list, 0 for the end. Deck position 1 is the top
 */
/datum/card_game/proc/move_card(datum/card_game_card/card, zone, seat = 0, position = 0)
	var/list/source
	switch(card.zone)
		if(CARD_ZONE_DECK)
			source = deck
		if(CARD_ZONE_HAND)
			source = hands[card.seat]
		if(CARD_ZONE_FELT)
			source = felt
	source -= card

	var/list/destination
	switch(zone)
		if(CARD_ZONE_DECK)
			destination = deck
		if(CARD_ZONE_HAND)
			destination = hands[seat]
		if(CARD_ZONE_FELT)
			destination = felt
	if(position)
		destination.Insert(position, card)
	else
		destination += card

	card.zone = zone
	card.seat = zone == CARD_ZONE_HAND ? seat : 0
	card.handle = zone == CARD_ZONE_DECK ? 0 : next_handle++
	card.peekers = null
	card.rot = 0
	card.face_up = FALSE

/// The card with this handle in that seat's hand, or null. Looks nowhere else, so a guessed handle cannot reach another hand
/datum/card_game/proc/hand_card(seat, handle)
	if(!isnum(handle))
		return null
	for(var/datum/card_game_card/card as anything in hands[seat])
		if(card.handle == handle)
			return card
	return null

/// The card with this handle on the felt, or null. Looks nowhere else
/datum/card_game/proc/felt_card(handle)
	if(!isnum(handle))
		return null
	for(var/datum/card_game_card/card as anything in felt)
		if(card.handle == handle)
			return card
	return null

/// How a log entry names a card: by name only while it lies face up on the felt, else "a card"
/datum/card_game/proc/card_words(datum/card_game_card/card)
	if(card.zone != CARD_ZONE_FELT || !card.face_up)
		return "a card"
	if(findtext(card.name, "The ", 1, 5))
		return card.name
	return "the [card.name]"

/**
 * Puts a deck's cards into the game, one card per name in order, the first name on top.
 *
 * Refused while a deck is already in the game. Entries that are not text are skipped.
 */
/datum/card_game/proc/add_cards(list/names, style)
	if(has_deck || !islist(names))
		return FALSE
	has_deck = TRUE
	deck_style = istext(style) ? style : ""
	flips_since_shuffle = 0
	for(var/card_name in names)
		if(!istext(card_name))
			continue
		var/datum/card_game_card/card = new
		card.name = card_name
		deck += card
	log_event("add", 0, "A deck is laid on the cloth.")
	changed()
	return TRUE

/**
 * Puts cards that were drawn from the game's deck item before it was laid back into the game, at the bottom of the deck.
 *
 * It takes no acting seat, since whoever uses the card on the cloth may be seated or not. Refused when no deck is in
 * the game. Entries that are not text are skipped, and a list with no text entry is refused.
 */
/datum/card_game/proc/add_to_bottom(list/names)
	if(!has_deck || !islist(names))
		return FALSE
	var/added = 0
	for(var/card_name in names)
		if(!istext(card_name))
			continue
		var/datum/card_game_card/card = new
		card.name = card_name
		deck += card
		added++
	if(!added)
		return FALSE
	log_event("add", 0, "[added] card\s [added == 1 ? "is" : "are"] put back under the deck.")
	changed()
	return TRUE

/**
 * Takes every card out of the game for the deck item to hold again, and returns their names.
 *
 * The names are shuffled, so the deck that comes back says nothing about where any card was.
 */
/datum/card_game/proc/take_all_names()
	var/list/names = list()
	for(var/datum/card_game_card/deck_card as anything in deck)
		names += deck_card.name
	for(var/datum/card_game_card/felt_entry as anything in felt)
		names += felt_entry.name
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		for(var/datum/card_game_card/held_card as anything in hands[seat])
			names += held_card.name
	clear_cards()
	return shuffle(names)

/// Drops every card and the deck with them, for a deck item that no longer exists
/datum/card_game/proc/clear_cards()
	deck = list()
	felt = list()
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		hands[seat] = list()
		showing[seat] = FALSE
	has_deck = FALSE
	flips_since_shuffle = 0
	log_event("remove", 0, "The deck is taken off the cloth.")
	changed()

/// Deck top to the seat's hand
/datum/card_game/proc/draw(seat)
	if(!acting_seat(seat) || !length(deck))
		return FALSE
	move_card(deck[1], CARD_ZONE_HAND, seat)
	log_event("draw", seat, "[seat_display_name(seats[seat])] draws a card.")
	changed()
	return TRUE

/**
 * Deals count cards to each occupied seat in turn, starting after the dealer, until the deck runs out.
 *
 * The count is rounded and kept within 1 to GAMING_CLOTH_DEAL_MAX.
 */
/datum/card_game/proc/deal(seat, count)
	if(!acting_seat(seat) || !isnum(count) || !length(deck))
		return FALSE
	count = clamp(round(count, 1), 1, GAMING_CLOTH_DEAL_MAX)
	var/dealt = 0
	for(var/deal_round in 1 to count)
		if(!length(deck))
			break
		for(var/offset in 1 to GAMING_CLOTH_SEATS)
			var/receiver = ((seat - 1 + offset) % GAMING_CLOTH_SEATS) + 1
			if(isnull(seats[receiver]))
				continue
			if(!length(deck))
				break
			move_card(deck[1], CARD_ZONE_HAND, receiver)
			dealt++
	log_event("deal", seat, "[seat_display_name(seats[seat])] deals [dealt] card\s.")
	changed()
	return TRUE

/**
 * Deck top to the felt, face up or down.
 *
 * With no x and no y it goes to the next Flip Top spot. With either given, both must be numbers.
 */
/datum/card_game/proc/place(seat, up, x, y)
	if(!acting_seat(seat) || !length(deck))
		return FALSE
	var/flip_top = isnull(x) && isnull(y)
	var/spot_x
	var/spot_y
	if(flip_top)
		spot_x = FLIP_TOP_X + FLIP_TOP_STEP * (flips_since_shuffle % FLIP_TOP_SPOTS)
		spot_y = FLIP_TOP_Y
		flips_since_shuffle++
	else
		spot_x = felt_coordinate(x)
		spot_y = felt_coordinate(y)
		if(isnull(spot_x) || isnull(spot_y))
			return FALSE

	var/datum/card_game_card/card = deck[1]
	move_card(card, CARD_ZONE_FELT)
	card.x = spot_x
	card.y = spot_y
	card.face_up = !!up
	log_event("place", seat, "[seat_display_name(seats[seat])] places [card_words(card)] from the deck.", card.handle, "deck")
	changed()
	return TRUE

/// Shuffles the deck
/datum/card_game/proc/shuffle_deck(seat)
	if(!acting_seat(seat) || !length(deck))
		return FALSE
	shuffle_inplace(deck)
	flips_since_shuffle = 0
	log_event("shuffle", seat, "[seat_display_name(seats[seat])] shuffles the deck.")
	changed()
	return TRUE

/**
 * Every hand and felt card back into the deck, then a shuffle.
 *
 * Every shown hand is hidden again, so the next deal is not dealt face up to the table.
 */
/datum/card_game/proc/collect(seat)
	if(!acting_seat(seat))
		return FALSE
	var/list/gathered = felt.Copy()
	for(var/hand_seat in 1 to GAMING_CLOTH_SEATS)
		gathered += hands[hand_seat]
	if(!length(gathered) && !length(deck))
		return FALSE
	for(var/datum/card_game_card/card as anything in gathered)
		move_card(card, CARD_ZONE_DECK)
	shuffle_inplace(deck)
	flips_since_shuffle = 0
	for(var/shown_seat in 1 to GAMING_CLOTH_SEATS)
		showing[shown_seat] = FALSE
	log_event("collect", seat, "[seat_display_name(seats[seat])] gathers the cards and shuffles the deck.")
	changed()
	return TRUE

/// A card from the seat's own hand to the felt at x, y, face up or down
/datum/card_game/proc/play(seat, h, x, y, up)
	if(!acting_seat(seat))
		return FALSE
	var/datum/card_game_card/card = hand_card(seat, h)
	var/spot_x = felt_coordinate(x)
	var/spot_y = felt_coordinate(y)
	if(!card || isnull(spot_x) || isnull(spot_y))
		return FALSE
	move_card(card, CARD_ZONE_FELT)
	card.x = spot_x
	card.y = spot_y
	card.face_up = !!up
	log_event("play", seat, "[seat_display_name(seats[seat])] plays [card_words(card)].", card.handle, "seat[seat]")
	changed()
	return TRUE

/// A felt card to x, y and to the top of the paint order. It stays on the felt, so it keeps its handle
/datum/card_game/proc/move(seat, h, x, y)
	if(!acting_seat(seat))
		return FALSE
	var/datum/card_game_card/card = felt_card(h)
	var/spot_x = felt_coordinate(x)
	var/spot_y = felt_coordinate(y)
	if(!card || isnull(spot_x) || isnull(spot_y))
		return FALSE
	if(card.x == spot_x && card.y == spot_y && felt[length(felt)] == card)
		return FALSE
	card.x = spot_x
	card.y = spot_y
	felt -= card
	felt += card
	log_event("move", seat, "[seat_display_name(seats[seat])] moves [card_words(card)].", card.handle)
	changed()
	return TRUE

/// Turns a felt card over
/datum/card_game/proc/flip(seat, h)
	if(!acting_seat(seat))
		return FALSE
	var/datum/card_game_card/card = felt_card(h)
	if(!card)
		return FALSE
	card.face_up = !card.face_up
	var/what = card.face_up ? "turns up [card_words(card)]" : "turns a card face down"
	log_event("flip", seat, "[seat_display_name(seats[seat])] [what].", card.handle)
	changed()
	return TRUE

/// Gives a felt card a quarter turn
/datum/card_game/proc/rotate(seat, h)
	if(!acting_seat(seat))
		return FALSE
	var/datum/card_game_card/card = felt_card(h)
	if(!card)
		return FALSE
	card.rot = (card.rot + 90) % 360
	log_event("rotate", seat, "[seat_display_name(seats[seat])] rotates [card_words(card)].", card.handle)
	changed()
	return TRUE

/// The seat looks at a face-down felt card. Logged, and refused when that seat already looked at it
/datum/card_game/proc/peek(seat, h)
	if(!acting_seat(seat))
		return FALSE
	var/datum/card_game_card/card = felt_card(h)
	if(!card || card.face_up)
		return FALSE
	if(card.peekers && (seat in card.peekers))
		return FALSE
	LAZYADD(card.peekers, seat)
	log_event("peek", seat, "[seat_display_name(seats[seat])] peeks at a card.", card.handle)
	changed()
	return TRUE

/// A felt card into the seat's hand
/datum/card_game/proc/take(seat, h)
	if(!acting_seat(seat))
		return FALSE
	var/datum/card_game_card/card = felt_card(h)
	if(!card)
		return FALSE
	move_card(card, CARD_ZONE_HAND, seat)
	log_event("take", seat, "[seat_display_name(seats[seat])] takes a card.")
	changed()
	return TRUE

/**
 * A card from the seat's own hand or from the felt back into the deck.
 *
 * The action is "return" in the payload contract, a word DM keeps for itself.
 * Arguments:
 * * where - "top", "bottom" or "shuffle", the last putting it at a random depth
 */
/datum/card_game/proc/return_card(seat, h, where)
	if(!acting_seat(seat))
		return FALSE
	var/position
	switch(where)
		if("top")
			position = 1
		if("bottom")
			position = 0
		if("shuffle")
			position = rand(1, length(deck) + 1)
		else
			return FALSE
	var/datum/card_game_card/card = hand_card(seat, h) || felt_card(h)
	if(!card)
		return FALSE
	move_card(card, CARD_ZONE_DECK, 0, position)
	var/list/where_words = list("top" = "on top of the deck", "bottom" = "at the bottom of the deck", "shuffle" = "into the deck")
	log_event("return", seat, "[seat_display_name(seats[seat])] puts a card [where_words[where]].")
	changed()
	return TRUE

#undef FLIP_TOP_X
#undef FLIP_TOP_Y
#undef FLIP_TOP_STEP
#undef FLIP_TOP_SPOTS
