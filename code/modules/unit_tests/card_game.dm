/**
 * The gaming cloth's card game state, with no cloth and no window.
 *
 * Guards what must never regress: no hidden card name in another seat's payload, no card made or lost, nothing
 * left referenced after a deletion, and no change from a malformed value. Each check is a helper on a fresh
 * game made with new.
 */
/datum/unit_test/card_game
	/// Calls of the game's on_change counted by check_change_callback
	var/change_calls = 0

/datum/unit_test/card_game/Run()
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/third = allocate(/mob/living/carbon/human/consistent)
	check_add_cards()
	check_deal_hides_hands(first, second)
	check_peeks(first, second, third)
	check_handles(first, second)
	check_rotation_reset(first)
	check_show(first, second)
	check_leave_seat(first, second)
	check_conservation(first, second)
	check_take_all_names(first, second)
	check_deletion()
	check_away(first, second)
	check_change_callback(first)
	check_malformed_values(first, second)
	check_shown_order_hides_arrival(first, second)
	check_leaving_hand_lies_face_down(first, second)
	check_leaving_seat_stops_showing(first, second, third)
	check_leaving_seat_zeroes_ack(first, third)
	check_pack_up_is_shuffled()
	check_collect_hides_shown_hands(first, second)
	check_moving_away_frees_seat(first)
	check_death_frees_seat(first)
	check_add_to_bottom(first, second, third)

/// The 52 names a standard deck item holds
/datum/unit_test/card_game/proc/standard_names()
	. = list()
	for(var/suit in list("Hearts", "Spades", "Clubs", "Diamonds"))
		. += "Ace of [suit]"
		for(var/rank in 2 to 10)
			. += "[rank] of [suit]"
		for(var/person in list("Jack", "Queen", "King"))
			. += "[person] of [suit]"

/// A game holding a standard deck
/datum/unit_test/card_game/proc/new_game()
	var/datum/card_game/game = new
	game.add_cards(standard_names(), "syndicate")
	return game

/// The names in one seat's hand, in hand order
/datum/unit_test/card_game/proc/hand_names(datum/card_game/game, seat)
	. = list()
	for(var/datum/card_game_card/card as anything in game.hands[seat])
		. += card.name

/// The names of the last count cards on the felt, in paint order
/datum/unit_test/card_game/proc/last_felt_names(datum/card_game/game, count)
	. = list()
	var/list/felt = game.felt
	for(var/index in (length(felt) - count + 1) to length(felt))
		var/datum/card_game_card/card = felt[index]
		. += card.name

/// Every card name in the game, from the deck, the felt and every hand
/datum/unit_test/card_game/proc/all_names(datum/card_game/game)
	. = list()
	for(var/datum/card_game_card/deck_card as anything in game.deck)
		. += deck_card.name
	for(var/datum/card_game_card/felt_card as anything in game.felt)
		. += felt_card.name
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		. += hand_names(game, seat)

/// TRUE when two lists of distinct names hold the same names in any order
/datum/unit_test/card_game/proc/same_names(list/first_names, list/second_names)
	if(length(first_names) != length(second_names))
		return FALSE
	for(var/card_name in first_names)
		if(!(card_name in second_names))
			return FALSE
	return TRUE

/// TRUE when two lists hold the same entries in the same order
/datum/unit_test/card_game/proc/same_order(list/first_list, list/second_list)
	if(length(first_list) != length(second_list))
		return FALSE
	for(var/index in 1 to length(first_list))
		if(first_list[index] != second_list[index])
			return FALSE
	return TRUE

/// The payload's felt entry for a handle, or null
/datum/unit_test/card_game/proc/felt_entry(list/payload, handle)
	for(var/list/entry as anything in payload["felt"])
		if(entry["h"] == handle)
			return entry
	return null

/// One seat's entry in a payload
/datum/unit_test/card_game/proc/seat_entry(list/payload, seat)
	var/list/payload_seats = payload["seats"]
	return payload_seats[seat]

/// Counts on_change calls for check_change_callback
/datum/unit_test/card_game/proc/count_change()
	change_calls++

/// Check 1: a deck goes in whole and a second one is refused
/datum/unit_test/card_game/proc/check_add_cards()
	var/datum/card_game/game = new
	TEST_ASSERT(game.add_cards(standard_names(), "syndicate"), "the first deck was refused")
	TEST_ASSERT_EQUAL(length(game.deck), 52, "the deck does not hold 52 cards")
	TEST_ASSERT(!game.add_cards(standard_names(), "syndicate"), "a second deck was accepted")
	TEST_ASSERT_EQUAL(length(game.deck), 52, "a refused deck changed the card count")
	qdel(game)

/// Check 2: a dealt hand reaches only its own seat, and the shared payload holds no private key
/datum/unit_test/card_game/proc/check_deal_hides_hands(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 5), "the deal was refused")
	TEST_ASSERT_EQUAL(length(game.hands[1]), 5, "seat 1 was not dealt 5 cards")
	TEST_ASSERT_EQUAL(length(game.hands[2]), 5, "seat 2 was not dealt 5 cards")

	var/list/second_view = game.data_for(second)
	var/second_json = json_encode(second_view)
	for(var/card_name in hand_names(game, 1))
		TEST_ASSERT(!findtext(second_json, card_name), "seat 2's payload names [card_name] from seat 1's hand")
	for(var/datum/card_game_card/deck_card as anything in game.deck)
		TEST_ASSERT(!findtext(second_json, deck_card.name), "seat 2's payload names [deck_card.name] from the deck")
	var/list/sent_hand = list()
	for(var/list/entry as anything in second_view["hand"])
		sent_hand += entry["name"]
	TEST_ASSERT(same_names(sent_hand, hand_names(game, 2)), "seat 2's payload hand is not exactly its own five cards")

	game.data_for(first)
	for(var/private_key in list("you", "ack", "hand", "peeks"))
		TEST_ASSERT(!(private_key in game.public_cache), "public_cache holds the private key [private_key]")
	qdel(game)

/// Check 3: a face-down card is sent unnamed, a peek reaches only the peeker, and a new occupant inherits no peek
/datum/unit_test/card_game/proc/check_peeks(mob/first, mob/second, mob/third)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 5), "the deal was refused")
	var/list/first_hand = game.hands[1]
	var/datum/card_game_card/card = first_hand[1]
	TEST_ASSERT(game.play(1, card.handle, 500, 500, FALSE), "playing a card face down was refused")

	var/list/entry = felt_entry(game.data_for(first), card.handle)
	TEST_ASSERT(entry, "the played card is not in the payload's felt")
	TEST_ASSERT(isnull(entry["name"]), "a face-down card was sent with its name")

	TEST_ASSERT(game.peek(2, card.handle), "the peek was refused")
	var/list/second_view = game.data_for(second)
	var/list/second_peeks = second_view["peeks"]
	TEST_ASSERT_EQUAL(second_peeks["[card.handle]"], card.name, "the peek did not reach the peeker")
	var/list/first_view = game.data_for(first)
	var/list/first_peeks = first_view["peeks"]
	TEST_ASSERT(!length(first_peeks), "seat 2's peek reached seat 1")
	TEST_ASSERT(!findtext(json_encode(first_view), card.name), "seat 1's payload names a face-down card it never peeked at")
	TEST_ASSERT(!findtext(json_encode(game.data_for(third)), card.name), "a watcher's payload names a face-down card")

	TEST_ASSERT(game.leave_seat(2), "seat 2 could not leave")
	TEST_ASSERT(game.take_seat(third, 2), "a new mob could not take seat 2")
	var/list/third_view = game.data_for(third)
	var/list/third_peeks = third_view["peeks"]
	TEST_ASSERT(!length(third_peeks), "the new occupant of seat 2 inherited a peek")
	qdel(game)

/// Check 4: every zone change gives a new handle, and a handle from another hand is refused
/datum/unit_test/card_game/proc/check_handles(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 5), "the deal was refused")
	var/list/first_hand = game.hands[1]
	var/datum/card_game_card/card = first_hand[1]

	TEST_ASSERT(game.play(1, card.handle, 400, 400, FALSE), "the first play was refused")
	var/first_felt_handle = card.handle
	TEST_ASSERT(game.peek(2, first_felt_handle), "the peek was refused")
	TEST_ASSERT(game.take(1, first_felt_handle), "the take was refused")
	TEST_ASSERT(isnull(card.peekers), "a card kept its peekers through a zone change")
	var/hand_handle = card.handle
	TEST_ASSERT(game.play(1, hand_handle, 400, 400, TRUE), "the second play was refused")
	var/second_felt_handle = card.handle
	TEST_ASSERT(first_felt_handle != hand_handle && hand_handle != second_felt_handle && first_felt_handle != second_felt_handle, "a card kept a handle across a zone change")

	var/datum/card_game_card/other = first_hand[1]
	var/list/before = first_hand.Copy()
	TEST_ASSERT(!game.play(2, other.handle, 400, 400, TRUE), "seat 2 played a card from seat 1's hand")
	TEST_ASSERT(same_order(first_hand, before), "a refused play changed seat 1's hand")
	TEST_ASSERT_EQUAL(other.zone, CARD_ZONE_HAND, "a refused play moved the card")
	qdel(game)

/// Check 5: a card turned on the felt is upright again after a zone change
/datum/unit_test/card_game/proc/check_rotation_reset(mob/first)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1), "the mob could not sit")
	TEST_ASSERT(game.draw(1), "the draw was refused")
	var/list/first_hand = game.hands[1]
	var/datum/card_game_card/card = first_hand[1]
	TEST_ASSERT(game.play(1, card.handle, 500, 500, TRUE), "the play was refused")
	TEST_ASSERT(game.rotate(1, card.handle), "the rotate was refused")
	TEST_ASSERT_EQUAL(card.rot, 90, "a quarter turn did not give 90")
	TEST_ASSERT(game.take(1, card.handle), "the take was refused")
	TEST_ASSERT(game.play(1, card.handle, 500, 500, TRUE), "the second play was refused")
	TEST_ASSERT_EQUAL(card.rot, 0, "a card kept its turn through a zone change")
	qdel(game)

/// Check 6: a shown hand is named to all and hiding it removes the names
/datum/unit_test/card_game/proc/check_show(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 3), "the deal was refused")
	TEST_ASSERT(game.show(1, TRUE), "showing the hand was refused")
	var/list/show_event = game.events[length(game.events)]
	for(var/card_name in hand_names(game, 1))
		TEST_ASSERT(!findtext(show_event["text"], card_name), "the show line names [card_name]")
	var/list/seat_one = seat_entry(game.data_for(second), 1)
	var/list/shown = seat_one["showing"]
	TEST_ASSERT(islist(shown) && same_names(shown, hand_names(game, 1)), "a shown hand was not named to another seat")
	TEST_ASSERT(game.show(1, FALSE), "hiding the hand was refused")
	seat_one = seat_entry(game.data_for(second), 1)
	TEST_ASSERT(isnull(seat_one["showing"]), "a hidden hand is still named")
	TEST_ASSERT(!game.show(1, FALSE), "hiding a hidden hand counted as a change")
	qdel(game)

/// Check 7: leaving sets the hand down face down in a shuffled order and unregisters the mob
/datum/unit_test/card_game/proc/check_leave_seat(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	for(var/draw_count in 1 to 5)
		game.draw(1)
	var/list/held = hand_names(game, 1)
	TEST_ASSERT(game.leave_seat(1), "seat 1 could not leave")
	TEST_ASSERT(isnull(game.seats[1]), "seat 1 is still taken")
	TEST_ASSERT_EQUAL(length(game.hands[1]), 0, "the leaving hand was not set down")
	TEST_ASSERT_EQUAL(length(game.felt), 5, "the set-down hand is not on the felt")
	for(var/datum/card_game_card/card as anything in game.felt)
		TEST_ASSERT(!card.face_up, "a set-down card lies face up")
		TEST_ASSERT_EQUAL(card.y, 880, "a set-down card is not on seat 1's edge")
	TEST_ASSERT(!game.signal_procs || !game.signal_procs[first], "the mob that left is still registered")
	TEST_ASSERT(game.take_seat(first, 1), "the mob that left could not sit again")

	var/differed = !same_order(held, last_felt_names(game, 5))
	for(var/attempt in 2 to 20)
		if(differed)
			break
		game.collect(2)
		for(var/redraw_count in 1 to 5)
			game.draw(1)
		held = hand_names(game, 1)
		game.leave_seat(1)
		differed = !same_order(held, last_felt_names(game, 5))
		game.take_seat(first, 1)
	TEST_ASSERT(differed, "20 hands were set down in the order they were held")
	qdel(game)

/// Check 8: a scripted run of every action leaves 52 distinct cards
/datum/unit_test/card_game/proc/check_conservation(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 5), "deal was refused")
	TEST_ASSERT(game.draw(2), "draw was refused")
	TEST_ASSERT(game.place(1, TRUE), "place at the Flip Top spot was refused")
	TEST_ASSERT(game.place(2, FALSE, 300, 300), "place at a spot was refused")
	TEST_ASSERT(game.shuffle_deck(1), "shuffle was refused")

	var/list/first_hand = game.hands[1]
	var/datum/card_game_card/card = first_hand[1]
	TEST_ASSERT(game.play(1, card.handle, 500, 500, FALSE), "play was refused")
	TEST_ASSERT(game.move(2, card.handle, 600, 650), "move was refused")
	TEST_ASSERT(game.flip(2, card.handle), "flip was refused")
	TEST_ASSERT(game.rotate(1, card.handle), "rotate was refused")
	TEST_ASSERT(game.flip(1, card.handle), "flip back was refused")
	TEST_ASSERT(game.peek(2, card.handle), "peek was refused")
	TEST_ASSERT(game.take(2, card.handle), "take was refused")
	TEST_ASSERT(game.return_card(2, card.handle, "top"), "return to the top was refused")

	card = first_hand[1]
	TEST_ASSERT(game.return_card(1, card.handle, "bottom"), "return to the bottom was refused")
	var/list/felt_cards = game.felt
	card = felt_cards[1]
	TEST_ASSERT(game.return_card(1, card.handle, "shuffle"), "return shuffled in was refused")
	TEST_ASSERT(game.show(1, TRUE) && game.show(1, FALSE), "show and hide were refused")
	TEST_ASSERT(game.leave_seat(2), "stand was refused")
	TEST_ASSERT(game.take_seat(second, 2), "sitting again was refused")
	TEST_ASSERT(game.unseat(2), "unseating a mob with no client was refused")
	TEST_ASSERT(game.collect(1), "collect was refused")
	TEST_ASSERT(game.take_seat(second, 2), "sitting after collect was refused")
	TEST_ASSERT(game.deal(1, 13), "deal 13 was refused")
	TEST_ASSERT(game.place(2, TRUE), "a second Flip Top was refused")
	var/list/second_hand = game.hands[2]
	card = second_hand[1]
	TEST_ASSERT(game.play(2, card.handle, 200, 800, TRUE), "a second play was refused")

	var/list/names = all_names(game)
	TEST_ASSERT_EQUAL(length(names), 52, "cards were made or lost")
	TEST_ASSERT_EQUAL(length(uniqueList(names)), 52, "a card is in the game twice")
	TEST_ASSERT(same_names(names, standard_names()), "the game holds a name the deck never had")
	qdel(game)

/// Check 9: taking every card out returns the deck's 52 names
/datum/unit_test/card_game/proc/check_take_all_names(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 5) && game.place(1, TRUE), "the setup was refused")
	var/list/names = game.take_all_names()
	TEST_ASSERT_EQUAL(length(names), 52, "take_all_names did not return 52 names")
	TEST_ASSERT(same_names(names, standard_names()), "take_all_names returned other names than the deck's")
	TEST_ASSERT(!game.has_deck && !length(game.deck) && !length(game.felt) && !length(game.hands[1]), "cards are left in the game")
	qdel(game)

/// Check 10: a seated mob that is deleted frees its seat and the game keeps no reference to it
/datum/unit_test/card_game/proc/check_deletion()
	var/datum/card_game/game = new_game()
	var/mob/living/carbon/human/consistent/seated = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/never_sat = new(run_loc_floor_bottom_left)
	TEST_ASSERT(game.take_seat(seated, 1), "the mob could not sit")
	TEST_ASSERT(game.draw(1), "the draw was refused")
	qdel(seated)
	qdel(never_sat)
	TEST_ASSERT(isnull(game.seats[1]), "a deleted mob kept its seat")
	TEST_ASSERT_EQUAL(refcount(seated), refcount(never_sat), "the game kept a reference to a deleted mob")
	qdel(game)

/**
 * Check 11: away is read fresh on every data_for.
 *
 * Test mobs have no client, so a seated one is away from the start and its stat cannot change that. The check
 * therefore writes a stale value into the cache and expects data_for to overwrite it.
 */
/datum/unit_test/card_game/proc/check_away(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1), "the mob could not sit")
	TEST_ASSERT(game.away_mask() & 1, "a seated mob with no client is not away")
	TEST_ASSERT(!(game.away_mask() & 2), "an empty seat is away")
	var/list/seat_one = seat_entry(game.data_for(second), 1)
	TEST_ASSERT(seat_one["away"], "the payload does not mark a seated mob with no client away")
	var/list/seat_two = seat_entry(game.data_for(second), 2)
	TEST_ASSERT(!seat_two["away"], "the payload marks an empty seat away")

	var/list/cached_seats = game.public_cache["seats"]
	var/list/cached_first = cached_seats[1]
	cached_first["away"] = FALSE
	seat_one = seat_entry(game.data_for(second), 1)
	TEST_ASSERT(seat_one["away"], "data_for sent a cached away")

	first.stat = UNCONSCIOUS
	var/unconscious_mask = game.away_mask()
	first.stat = CONSCIOUS
	TEST_ASSERT(unconscious_mask & 1, "an unconscious seated mob is not away")
	qdel(game)

/// Check 12: an accepted action tells the owner once and a refused one not at all
/datum/unit_test/card_game/proc/check_change_callback(mob/first)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1), "the mob could not sit")
	change_calls = 0
	game.on_change = CALLBACK(src, PROC_REF(count_change))
	TEST_ASSERT(game.draw(1), "the draw was refused")
	TEST_ASSERT_EQUAL(change_calls, 1, "an accepted action did not call on_change exactly once")
	TEST_ASSERT(!game.take(1, 99999), "taking a card that is not on the felt was accepted")
	TEST_ASSERT_EQUAL(change_calls, 1, "a refused action called on_change")
	game.on_change = null
	qdel(game)

/// Values a window could send that no action may accept, and numbers outside the felt that are clamped
/datum/unit_test/card_game/proc/check_malformed_values(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 5), "the deal was refused")
	var/list/first_hand = game.hands[1]
	var/datum/card_game_card/card = first_hand[1]
	var/start_revision = game.revision

	TEST_ASSERT(!game.play(1, card.handle, "500", 500, TRUE), "a text coordinate was accepted")
	TEST_ASSERT(!game.deal(1, "5"), "a text count was accepted")
	TEST_ASSERT(!game.play(1, "[card.handle]", 500, 500, TRUE), "a text handle was accepted")
	TEST_ASSERT(!game.draw("1"), "a text seat was accepted")
	TEST_ASSERT(!game.draw(7), "a seat past the last was accepted")
	TEST_ASSERT(!game.draw(1.5), "a fractional seat was accepted")
	TEST_ASSERT(!game.draw(3), "an empty seat acted")
	TEST_ASSERT(!game.flip(1, card.handle), "a felt action reached a card in a hand")
	TEST_ASSERT(!game.return_card(1, card.handle, "sideways"), "an unknown return place was accepted")
	TEST_ASSERT(!game.place(1, TRUE, 500, null), "a place with one coordinate was accepted")
	TEST_ASSERT(!game.take_seat(second, 3), "a seated mob took a second seat")
	TEST_ASSERT(!game.take_seat(first, 2), "a taken seat was given away")
	TEST_ASSERT(!game.leave_seat(3), "an empty seat was left")
	TEST_ASSERT_EQUAL(game.revision, start_revision, "a refused action changed the game")
	TEST_ASSERT_EQUAL(card.zone, CARD_ZONE_HAND, "a refused action moved a card")

	TEST_ASSERT(game.play(1, card.handle, -400, 99999, TRUE), "a play outside the felt was refused rather than clamped")
	TEST_ASSERT_EQUAL(card.x, GAMING_CLOTH_EDGE_MARGIN, "x was not clamped to the margin")
	TEST_ASSERT_EQUAL(card.y, GAMING_CLOTH_FELT_SIZE - GAMING_CLOTH_EDGE_MARGIN, "y was not clamped to the margin")
	qdel(game)

/// A shown hand is named in an order set by the names alone, so it cannot tell which card arrived from which play
/datum/unit_test/card_game/proc/check_shown_order_hides_arrival(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	for(var/draw_count in 1 to 3)
		game.draw(1)
	TEST_ASSERT(game.show(1, TRUE), "showing the hand was refused")
	var/list/held = hand_names(game, 1)
	var/list/seat_one = seat_entry(game.data_for(second), 1)
	var/list/first_showing = seat_one["showing"]

	var/list/first_hand = game.hands[1]
	var/list/played = first_hand.Copy()
	for(var/datum/card_game_card/played_card as anything in played)
		TEST_ASSERT(game.play(1, played_card.handle, 500, 500, FALSE), "a play was refused")
	for(var/index in length(played) to 1 step -1)
		var/datum/card_game_card/returning = played[index]
		TEST_ASSERT(game.take(1, returning.handle), "a take was refused")
	TEST_ASSERT(!same_order(held, hand_names(game, 1)), "the hand kept its arrival order, so this check proves nothing")
	seat_one = seat_entry(game.data_for(second), 1)
	TEST_ASSERT(same_order(first_showing, seat_one["showing"]), "a shown hand is named in the order its cards arrived")
	qdel(game)

/// A zone change lays the card face down, which is all that sets a leaving hand down face down
/datum/unit_test/card_game/proc/check_leaving_hand_lies_face_down(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.draw(1), "the draw was refused")
	var/list/first_hand = game.hands[1]
	var/datum/card_game_card/card = first_hand[1]
	TEST_ASSERT(game.play(1, card.handle, 500, 500, FALSE), "the play was refused")
	// Turned up directly, since a flip would put the name in the log, which may name a card once face up
	card.face_up = TRUE
	TEST_ASSERT(game.take(1, card.handle), "the take was refused")
	TEST_ASSERT(game.leave_seat(1), "seat 1 could not leave")
	var/list/second_view = game.data_for(second)
	var/list/entry = felt_entry(second_view, card.handle)
	TEST_ASSERT(entry, "the set-down card is not on the felt")
	TEST_ASSERT(isnull(entry["name"]), "a card taken face up was set down face up")
	TEST_ASSERT(!findtext(json_encode(second_view), card.name), "another seat's payload names a set-down card")
	qdel(game)

/// A seat that leaves stops showing, so the hand of whoever sits there next stays hidden
/datum/unit_test/card_game/proc/check_leaving_seat_stops_showing(mob/first, mob/second, mob/third)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.draw(1) && game.show(1, TRUE), "the draw or the show was refused")
	TEST_ASSERT(game.leave_seat(1), "seat 1 could not leave")
	TEST_ASSERT(game.take_seat(third, 1) && game.draw(1), "the new occupant could not sit and draw")
	var/list/seat_one = seat_entry(game.data_for(second), 1)
	TEST_ASSERT(isnull(seat_one["showing"]), "the next occupant of a seat that was showing has its hand named")
	qdel(game)

/// A seat that leaves has its ack zeroed, so the next occupant's window does not start from the old count
/datum/unit_test/card_game/proc/check_leaving_seat_zeroes_ack(mob/first, mob/third)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1), "the mob could not sit")
	game.acks[1] = 7
	TEST_ASSERT(game.leave_seat(1), "seat 1 could not leave")
	TEST_ASSERT(game.take_seat(third, 1), "the new occupant could not sit")
	var/list/third_view = game.data_for(third)
	TEST_ASSERT_EQUAL(third_view["ack"], 0, "the next occupant inherited the seat's ack")
	qdel(game)

/// The names a Pack Up hands back to the deck item are shuffled
/datum/unit_test/card_game/proc/check_pack_up_is_shuffled()
	var/list/added = standard_names()
	var/differed = FALSE
	for(var/attempt in 1 to 20)
		var/datum/card_game/game = new
		game.add_cards(added, "syndicate")
		var/list/returned = game.take_all_names()
		qdel(game)
		if(!same_order(added, returned))
			differed = TRUE
			break
	TEST_ASSERT(differed, "20 decks came back from take_all_names in the order they went in")

/// Collect hides every shown hand
/datum/unit_test/card_game/proc/check_collect_hides_shown_hands(mob/first, mob/second)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.deal(1, 3) && game.show(1, TRUE), "the deal or the show was refused")
	TEST_ASSERT(game.collect(1), "the collect was refused")
	var/list/seat_one = seat_entry(game.data_for(second), 1)
	TEST_ASSERT(isnull(seat_one["showing"]), "a hand shown before a collect is still shown after it")
	qdel(game)

/// A seated mob that moves out of reach of the host gives up its seat, a step within reach does not
/datum/unit_test/card_game/proc/check_moving_away_frees_seat(mob/first)
	var/datum/card_game/game = new_game()
	game.host = run_loc_floor_bottom_left
	first.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(game.take_seat(first, 1), "the mob could not sit")
	first.forceMove(get_step(run_loc_floor_bottom_left, NORTH))
	TEST_ASSERT_EQUAL(game.seat_of(first), 1, "a step within reach of the host freed the seat")
	first.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(isnull(game.seats[1]), "moving out of reach of the host kept the seat")
	qdel(game)
	first.forceMove(run_loc_floor_bottom_left)

/// A seated mob that dies gives up its seat and sets its hand down
/datum/unit_test/card_game/proc/check_death_frees_seat(mob/first)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1), "the mob could not sit")
	TEST_ASSERT(game.draw(1) && game.draw(1), "the draws were refused")
	SEND_SIGNAL(first, COMSIG_LIVING_DEATH, FALSE)
	TEST_ASSERT(isnull(game.seats[1]), "a mob that died kept its seat")
	TEST_ASSERT_EQUAL(length(game.hands[1]), 0, "a mob that died kept its hand")
	TEST_ASSERT_EQUAL(length(game.felt), 2, "a mob that died did not set its hand down")
	qdel(game)

/**
 * Cards drawn as items before the deck was laid go back under the game deck, unnamed to every viewer.
 *
 * The names are long and distinct, since a one-letter name is found by findtext in any payload.
 */
/datum/unit_test/card_game/proc/check_add_to_bottom(mob/first, mob/second, mob/watcher)
	var/datum/card_game/game = new_game()
	TEST_ASSERT(game.take_seat(first, 1) && game.take_seat(second, 2), "two mobs could not sit")
	TEST_ASSERT(game.draw(1) && game.draw(2), "the draws were refused")
	TEST_ASSERT_EQUAL(length(game.deck), 50, "the deck does not hold 50 cards")
	var/list/deck_cards = game.deck
	var/datum/card_game_card/top_card = deck_cards[1]
	change_calls = 0
	game.on_change = CALLBACK(src, PROC_REF(count_change))

	TEST_ASSERT(game.add_to_bottom(list("Returned Card Alpha", 7, "Returned Card Beta")), "cards put back under the deck were refused")
	TEST_ASSERT_EQUAL(change_calls, 1, "an accepted add_to_bottom did not call on_change exactly once")
	deck_cards = game.deck
	TEST_ASSERT_EQUAL(length(deck_cards), 52, "the deck does not hold 52 cards after two were put back")
	var/datum/card_game_card/second_last = deck_cards[51]
	var/datum/card_game_card/last = deck_cards[52]
	TEST_ASSERT_EQUAL(second_last.name, "Returned Card Alpha", "the first card put back is not second from the bottom")
	TEST_ASSERT_EQUAL(last.name, "Returned Card Beta", "the second card put back is not at the bottom")
	TEST_ASSERT(deck_cards[1] == top_card, "putting cards back changed the top card")
	for(var/mob/viewer as anything in list(first, second, watcher))
		var/viewer_json = json_encode(game.data_for(viewer))
		TEST_ASSERT(!findtext(viewer_json, "Returned Card"), "a payload names a card put back under the deck")

	TEST_ASSERT(!game.add_to_bottom("Returned Card Gamma"), "a value that is not a list was accepted")
	TEST_ASSERT(!game.add_to_bottom(list(7)), "a list with no name was accepted")
	TEST_ASSERT_EQUAL(change_calls, 1, "a refused add_to_bottom called on_change")
	game.on_change = null
	qdel(game)

	var/datum/card_game/empty_game = new
	empty_game.on_change = CALLBACK(src, PROC_REF(count_change))
	TEST_ASSERT(!empty_game.add_to_bottom(list("Returned Card Delta")), "cards were put back into a game with no deck")
	TEST_ASSERT_EQUAL(change_calls, 1, "a refused add_to_bottom called on_change")
	TEST_ASSERT_EQUAL(length(empty_game.deck), 0, "a game with no deck took cards")
	empty_game.on_change = null
	qdel(empty_game)

/**
 * The gaming cloth around the game, driven through handle_ops() with no window.
 *
 * Test mobs have no client, so the window's status, the window itself and the prompt are not covered here.
 */
/datum/unit_test/gaming_cloth

/datum/unit_test/gaming_cloth/Run()
	var/obj/structure/gaming_cloth/cloth = allocate(/obj/structure/gaming_cloth)
	var/obj/item/toy/cards/deck/deck = allocate(/obj/item/toy/cards/deck)
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/far_away = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	check_data_on_unused_cloth(player)
	check_deck_goes_in(cloth, deck)
	check_sit_and_draw(cloth, player)
	check_ops_need_a_player(cloth, far_away)
	check_malformed_ops(cloth, player)
	check_one_push_per_message(cloth, player)
	check_op_numbers(cloth, player)
	check_card_table_deck_refused(player)
	check_drawn_cards_come_back(player)
	check_deck_from_a_bag()
	check_reach_refusals()
	check_card_table_during_wait()
	check_placement()
	check_full_cloth_refused()
	check_deletion_returns_deck(cloth, deck, player)

/// Both data procs answer on a cloth nobody has used, for a mob with no window, since tgui may call them at any time
/datum/unit_test/gaming_cloth/proc/check_data_on_unused_cloth(mob/player)
	var/obj/structure/gaming_cloth/unused = allocate(/obj/structure/gaming_cloth)
	var/list/data = unused.ui_data(player)
	TEST_ASSERT(islist(data), "ui_data gave no payload on an unused cloth")
	TEST_ASSERT_EQUAL(data["you"], 0, "a mob with no seat was given one")
	var/list/static_data = unused.ui_static_data(player)
	TEST_ASSERT(isnum(static_data["act_budget"]) && isnum(static_data["act_used"]), "the static data is not two numbers")

/// A deck goes inside the cloth and its 52 cards into the game
/datum/unit_test/gaming_cloth/proc/check_deck_goes_in(obj/structure/gaming_cloth/cloth, obj/item/toy/cards/deck/deck)
	TEST_ASSERT(cloth.add_deck(deck, null), "the deck was refused")
	TEST_ASSERT_EQUAL(deck.loc, cloth, "the deck is not inside the cloth")
	TEST_ASSERT_EQUAL(length(cloth.game.deck), 52, "the game deck does not hold 52 cards")
	TEST_ASSERT_EQUAL(length(deck.cards), 0, "the deck item kept its cards")

/// sit then draw in one message seats the player, deals the card and raises the ack to the last op
/datum/unit_test/gaming_cloth/proc/check_sit_and_draw(obj/structure/gaming_cloth/cloth, mob/player)
	var/list/ops = list(list("op" = 1, "a" = "sit", "seat" = 1), list("op" = 2, "a" = "draw"))
	TEST_ASSERT(cloth.handle_ops(player, ops), "sit then draw changed nothing")
	TEST_ASSERT_EQUAL(cloth.game.seat_of(player), 1, "the player is not in seat 1")
	TEST_ASSERT_EQUAL(cloth.game.acks[1], 2, "seat 1's ack is not the last op")
	TEST_ASSERT_EQUAL(length(cloth.game.hands[1]), 1, "the draw did not reach the hand")

/// The same kind of message from a mob out of reach changes nothing
/datum/unit_test/gaming_cloth/proc/check_ops_need_a_player(obj/structure/gaming_cloth/cloth, mob/far_away)
	var/start_revision = cloth.game.revision
	var/list/ops = list(list("op" = 1, "a" = "sit", "seat" = 2), list("op" = 2, "a" = "draw"))
	TEST_ASSERT(!cloth.handle_ops(far_away, ops), "a mob out of reach played")
	TEST_ASSERT_EQUAL(cloth.game.revision, start_revision, "a mob out of reach changed the game")
	TEST_ASSERT(isnull(cloth.game.seats[2]), "a mob out of reach took a seat")

/// Messages a modified window could send change nothing and cause no runtime. A refused action still raises the ack
/datum/unit_test/gaming_cloth/proc/check_malformed_ops(obj/structure/gaming_cloth/cloth, mob/player)
	var/datum/card_game/game = cloth.game
	var/start_revision = game.revision
	var/list/hand = game.hands[1]
	var/datum/card_game_card/card = hand[1]

	TEST_ASSERT(!cloth.handle_ops(player, "draw"), "ops that are not a list changed the game")
	var/list/too_many = list()
	for(var/index in 1 to GAMING_CLOTH_OPS_PER_MESSAGE + 1)
		too_many += list(list("op" = 10 + index, "a" = "draw"))
	TEST_ASSERT(!cloth.handle_ops(player, too_many), "a message of [length(too_many)] entries was run")
	TEST_ASSERT(!cloth.handle_ops(player, list(5, "draw")), "entries that are not lists changed the game")
	TEST_ASSERT(!cloth.handle_ops(player, list(list("op" = 40))), "an entry with no action changed the game")
	TEST_ASSERT(!cloth.handle_ops(player, list(list("op" = "41", "a" = "draw"))), "an entry with a text op changed the game")
	var/list/text_x_play = list(list("op" = 42, "a" = "play", "h" = card.handle, "x" = "500", "y" = 500, "up" = TRUE))
	TEST_ASSERT(!cloth.handle_ops(player, text_x_play), "a play with a text x changed the game")

	TEST_ASSERT_EQUAL(game.revision, start_revision, "a malformed message changed the game")
	TEST_ASSERT_EQUAL(length(game.hands[1]), 1, "a malformed message moved a card out of the hand")
	TEST_ASSERT_EQUAL(card.zone, CARD_ZONE_HAND, "a play with a text x moved the card")
	TEST_ASSERT_EQUAL(game.acks[1], 42, "a refused action did not raise the ack, or a skipped entry did")

/// Three accepted actions in one message make one push at its end, not three
/datum/unit_test/gaming_cloth/proc/check_one_push_per_message(obj/structure/gaming_cloth/cloth, mob/player)
	cloth.update_queued = FALSE
	COOLDOWN_RESET(cloth, update_gate)
	var/list/ops = list(list("op" = 50, "a" = "draw"), list("op" = 51, "a" = "draw"), list("op" = 52, "a" = "draw"))
	TEST_ASSERT(cloth.handle_ops(player, ops), "three draws changed nothing")
	TEST_ASSERT_EQUAL(length(cloth.game.hands[1]), 4, "the three draws did not all land")
	TEST_ASSERT(!cloth.update_queued, "a second push was scheduled, so the message pushed before its end")
	TEST_ASSERT_EQUAL(cloth.update_gate, world.time + GAMING_CLOTH_UPDATE_INTERVAL, "the message did not push at its end")

/**
 * op is rounded like any number from a window, so 2.5 acts as op 3, and an op outside 1 to 2 to the 24th is skipped.
 *
 * The huge op is made by json_decode from the text a window would send, since 1e300 cannot be written as a DM number.
 */
/datum/unit_test/gaming_cloth/proc/check_op_numbers(obj/structure/gaming_cloth/cloth, mob/player)
	var/datum/card_game/game = cloth.game
	game.acks[1] = 0
	var/start_cards = length(game.hands[1])
	cloth.handle_ops(player, list(list("op" = 2.5, "a" = "draw")))
	TEST_ASSERT_EQUAL(game.acks[1], 3, "an op of 2.5 was not handled as 3")
	TEST_ASSERT_EQUAL(length(game.hands[1]), start_cards + 1, "the draw with an op of 2.5 did not act")

	var/start_revision = game.revision
	var/list/huge_entry = json_decode("{\"op\":1e300,\"a\":\"draw\"}")
	var/list/bad_entries = list(list("op" = 0, "a" = "draw"), list("op" = -5, "a" = "draw"), huge_entry)
	for(var/list/bad_entry as anything in bad_entries)
		var/bad_op = bad_entry["op"]
		cloth.handle_ops(player, list(bad_entry))
		TEST_ASSERT_EQUAL(game.acks[1], 3, "an op of [bad_op] changed the ack")
	TEST_ASSERT_EQUAL(game.revision, start_revision, "an entry with an op out of range acted")
	TEST_ASSERT_EQUAL(length(game.hands[1]), start_cards + 1, "an entry with an op out of range drew a card")

/// The turf dx, dy tiles from the bottom left of the five by five test room
/datum/unit_test/gaming_cloth/proc/room_tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/**
 * A deck in a bag the player holds is within reach, and laying it out takes it out through the bag's storage onto
 * the player's own free tile. Afterwards the bag holds no trace of it, and a deck inside a cloth is not within reach,
 * so neither the prompt nor the card table can take it back out.
 *
 * Runs on the top right tile, clear of the other checks' cloths, and sleeps through the two second wait.
 */
/datum/unit_test/gaming_cloth/proc/check_deck_from_a_bag()
	var/mob/living/carbon/human/consistent/bag_owner = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/obj/item/storage/backpack/rogue/satchel/satchel = allocate(/obj/item/storage/backpack/rogue/satchel, run_loc_floor_top_right)
	var/obj/item/toy/cards/deck/bagged_deck = allocate(/obj/item/toy/cards/deck, run_loc_floor_top_right)
	bag_owner.setDir(SOUTH)
	TEST_ASSERT(bag_owner.put_in_hands(satchel), "the mob could not hold the satchel")
	TEST_ASSERT(SEND_SIGNAL(satchel, COMSIG_TRY_STORAGE_INSERT, bagged_deck, null, TRUE, TRUE), "the deck did not go into the satchel")
	TEST_ASSERT_EQUAL(bagged_deck.loc, satchel, "the deck is not in the satchel")
	var/datum/component/storage/storage = satchel.GetComponent(/datum/component/storage)
	TEST_ASSERT(storage, "the satchel has no storage")
	TEST_ASSERT(!storage.grid || (bagged_deck in storage.item_to_grid_coordinates), "the satchel's grid does not hold the deck, so the check after the lay proves nothing")
	TEST_ASSERT(gaming_cloth_within_reach(bag_owner, bagged_deck), "a deck in a held bag is out of reach")

	TEST_ASSERT(lay_gaming_cloth(bag_owner, bagged_deck), "a deck in a held bag was not laid out")
	var/obj/structure/gaming_cloth/bag_cloth = locate(/obj/structure/gaming_cloth) in bag_owner.loc
	TEST_ASSERT(bag_cloth, "no cloth lies at the mob's feet")
	TEST_ASSERT_EQUAL(bag_cloth.deck_item, bagged_deck, "the cloth at the mob's feet does not hold the deck")
	TEST_ASSERT_EQUAL(bagged_deck.loc, bag_cloth, "the deck is not inside the cloth")
	TEST_ASSERT(!(bagged_deck in satchel.contents), "the satchel still holds the deck")
	TEST_ASSERT(!(bagged_deck in storage.item_to_grid_coordinates), "the satchel's grid still counts the deck")
	TEST_ASSERT(!(bagged_deck in storage.first_coordinates_item), "the satchel still keeps a place for the deck")
	TEST_ASSERT(!(bagged_deck.item_flags & IN_STORAGE), "the deck still thinks it is in storage")
	TEST_ASSERT(!gaming_cloth_within_reach(bag_owner, bagged_deck), "a deck inside a cloth is within reach")
	qdel(bag_cloth)

/// A deck held by another mob, or in a bag another mob holds, is out of reach even from that mob's own tile
/datum/unit_test/gaming_cloth/proc/check_reach_refusals()
	var/turf/spot = room_tile(1, 0)
	var/mob/living/carbon/human/consistent/reacher = allocate(/mob/living/carbon/human/consistent, spot)
	var/mob/living/carbon/human/consistent/holder = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/toy/cards/deck/held_deck = allocate(/obj/item/toy/cards/deck, spot)
	var/obj/item/storage/backpack/rogue/satchel/satchel = allocate(/obj/item/storage/backpack/rogue/satchel, spot)
	var/obj/item/toy/cards/deck/bagged_deck = allocate(/obj/item/toy/cards/deck, spot)
	TEST_ASSERT(holder.put_in_hands(held_deck) && holder.put_in_hands(satchel), "the other mob could not hold the deck and the satchel")
	TEST_ASSERT(SEND_SIGNAL(satchel, COMSIG_TRY_STORAGE_INSERT, bagged_deck, null, TRUE, TRUE), "the deck did not go into the satchel")
	TEST_ASSERT(!gaming_cloth_within_reach(reacher, held_deck), "a deck in another mob's hand is within reach")
	TEST_ASSERT(!gaming_cloth_within_reach(reacher, bagged_deck), "a deck in a bag another mob holds is within reach")
	TEST_ASSERT(gaming_cloth_within_reach(holder, bagged_deck), "a deck in a bag its own holder holds is out of reach")

/// A deck set up as the card table during the laying wait leaves no cloth behind
/datum/unit_test/gaming_cloth/proc/check_card_table_during_wait()
	var/turf/spot = room_tile(2, 0)
	var/mob/living/carbon/human/consistent/layer_mob = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/toy/cards/deck/waited_deck = allocate(/obj/item/toy/cards/deck, spot)
	addtimer(VARSET_CALLBACK(waited_deck, card_table_mode, TRUE), 1 SECONDS)
	var/laid = lay_gaming_cloth(layer_mob, waited_deck)
	var/flipped = waited_deck.card_table_mode
	waited_deck.card_table_mode = FALSE
	TEST_ASSERT(flipped, "the deck was not set up as the card table during the wait, so this check proves nothing")
	TEST_ASSERT(!laid, "a deck set up as the card table was laid out")
	TEST_ASSERT(!(locate(/obj/structure/gaming_cloth) in spot), "a cloth was left on the tile")
	TEST_ASSERT_EQUAL(waited_deck.loc, spot, "the deck moved")

/**
 * Where a held deck's cloth goes: a table the mob faces first, then the mob's own tile, then open ground ahead.
 *
 * One full lay, onto the faced table. The other cases read the chosen tile from gaming_cloth_pick_spot() or end
 * before the wait, since every full lay sleeps two seconds.
 */
/datum/unit_test/gaming_cloth/proc/check_placement()
	var/turf/table_tile = room_tile(2, 2)
	allocate(/obj/structure/table/wood, table_tile)
	var/mob/living/carbon/human/consistent/at_table = allocate(/mob/living/carbon/human/consistent, room_tile(1, 2))
	var/obj/item/toy/cards/deck/table_deck = allocate(/obj/item/toy/cards/deck, room_tile(1, 2))
	at_table.setDir(EAST)
	TEST_ASSERT(at_table.put_in_hands(table_deck), "the mob could not hold the deck")
	TEST_ASSERT(lay_gaming_cloth(at_table, table_deck), "a held deck facing a table was not laid out")
	var/obj/structure/gaming_cloth/table_cloth = locate(/obj/structure/gaming_cloth) in table_tile
	TEST_ASSERT(table_cloth, "facing a table did not put the cloth on the table")
	TEST_ASSERT_EQUAL(table_cloth.deck_item, table_deck, "the cloth on the table does not hold the deck")
	qdel(table_cloth)

	var/turf/blocked_tile = room_tile(1, 3)
	allocate(/obj/structure/fluff/walldeco, blocked_tile)
	var/mob/living/carbon/human/consistent/blocked = allocate(/mob/living/carbon/human/consistent, blocked_tile)
	blocked.setDir(EAST)
	TEST_ASSERT_EQUAL(gaming_cloth_pick_spot(blocked), room_tile(2, 3), "a mob on a tile that cannot take a cloth did not get the open ground ahead")

	var/turf/cornered_tile = room_tile(0, 3)
	allocate(/obj/structure/fluff/walldeco, cornered_tile)
	var/mob/living/carbon/human/consistent/cornered = allocate(/mob/living/carbon/human/consistent, cornered_tile)
	var/obj/item/toy/cards/deck/kept_deck = allocate(/obj/item/toy/cards/deck, cornered_tile)
	cornered.setDir(WEST)
	TEST_ASSERT(cornered.put_in_hands(kept_deck), "the mob could not hold the deck")
	TEST_ASSERT(!lay_gaming_cloth(cornered, kept_deck), "a deck was laid out with no tile that can take a cloth")
	TEST_ASSERT(cornered.is_holding(kept_deck), "a refused lay took the deck out of the hand")
	TEST_ASSERT(!(locate(/obj/structure/gaming_cloth) in cornered_tile), "a refused lay left a cloth")

	var/mob/living/carbon/human/consistent/by_wall = allocate(/mob/living/carbon/human/consistent, room_tile(0, 2))
	by_wall.setDir(WEST)
	TEST_ASSERT_EQUAL(gaming_cloth_pick_spot(by_wall), room_tile(0, 2), "a mob on a free tile facing a wall did not get its own tile")

	var/mob/living/carbon/human/consistent/in_the_open = allocate(/mob/living/carbon/human/consistent, room_tile(3, 1))
	in_the_open.setDir(EAST)
	TEST_ASSERT_EQUAL(gaming_cloth_pick_spot(in_the_open), room_tile(3, 1), "open ground ahead was chosen over a free own tile")

	// A palisade is dense and on the tile's edge, which is what makes a neighbouring tile unreachable by a click
	var/turf/fenced_tile = room_tile(4, 2)
	allocate(/obj/structure/table/wood, fenced_tile)
	var/obj/structure/fluff/railing/fence/palisade = allocate(/obj/structure/fluff/railing/fence, fenced_tile)
	palisade.setDir(WEST)
	var/mob/living/carbon/human/consistent/fenced_off = allocate(/mob/living/carbon/human/consistent, room_tile(3, 2))
	fenced_off.setDir(EAST)
	TEST_ASSERT(!fenced_tile.Adjacent(fenced_off), "the palisade does not cut the tile off, so this check proves nothing")
	TEST_ASSERT_EQUAL(gaming_cloth_pick_spot(fenced_off), room_tile(3, 2), "a table the mob cannot reach was chosen")

/// Facing a table whose cloth already has a deck, a second held deck is refused before anything moves
/datum/unit_test/gaming_cloth/proc/check_full_cloth_refused()
	var/turf/full_tile = room_tile(4, 3)
	allocate(/obj/structure/table/wood, full_tile)
	var/obj/structure/gaming_cloth/full_cloth = allocate(/obj/structure/gaming_cloth, full_tile)
	var/obj/item/toy/cards/deck/first_deck = allocate(/obj/item/toy/cards/deck, full_tile)
	TEST_ASSERT(full_cloth.add_deck(first_deck, null), "the first deck was refused")
	var/mob/living/carbon/human/consistent/second_player = allocate(/mob/living/carbon/human/consistent, room_tile(3, 3))
	var/obj/item/toy/cards/deck/second_deck = allocate(/obj/item/toy/cards/deck, room_tile(3, 3))
	second_player.setDir(EAST)
	TEST_ASSERT(second_player.put_in_hands(second_deck), "the mob could not hold the second deck")
	TEST_ASSERT(!lay_gaming_cloth(second_player, second_deck), "a second deck joined a cloth that has one")
	TEST_ASSERT(second_player.is_holding(second_deck), "a refused lay took the second deck out of the hand")
	TEST_ASSERT_EQUAL(length(full_cloth.game.deck), 52, "the first game's deck changed")
	TEST_ASSERT(!(locate(/obj/structure/gaming_cloth) in room_tile(3, 3)), "a second cloth was laid at the mob's feet")
	qdel(full_cloth)

/// A deck set up as the rules-based card table does not join a cloth
/datum/unit_test/gaming_cloth/proc/check_card_table_deck_refused(mob/player)
	var/obj/structure/gaming_cloth/bare_cloth = allocate(/obj/structure/gaming_cloth)
	var/obj/item/toy/cards/deck/table_deck = allocate(/obj/item/toy/cards/deck)
	table_deck.card_table_mode = TRUE
	var/handled = bare_cloth.attackby(table_deck, player, "")
	table_deck.card_table_mode = FALSE
	TEST_ASSERT(handled, "attackby did not handle a deck")
	TEST_ASSERT(isnull(bare_cloth.deck_item), "a deck set up as a card table joined the cloth")
	TEST_ASSERT(table_deck.loc != bare_cloth, "a deck set up as a card table went into the cloth")
	TEST_ASSERT_EQUAL(length(table_deck.cards), 52, "a refused deck lost cards")

/**
 * Cards drawn as real items before the deck was laid go back under the game deck, and a card of another deck does not.
 *
 * The cards are drawn with the deck's own draw_card(), so they are the items a player would hold. A hand is made the
 * way the hand's own code makes one, from two drawn cards.
 */
/datum/unit_test/gaming_cloth/proc/check_drawn_cards_come_back(mob/player)
	var/obj/structure/gaming_cloth/cloth = allocate(/obj/structure/gaming_cloth)
	var/obj/item/toy/cards/deck/deck = allocate(/obj/item/toy/cards/deck)
	var/obj/item/toy/cards/deck/other_deck = allocate(/obj/item/toy/cards/deck)
	var/full_count = length(deck.cards)
	var/list/drawn = list()
	for(var/draw_count in 1 to 3)
		deck.draw_card(player)
		var/obj/item/toy/cards/singlecard/newest = locate_drawn_card(player, deck, drawn)
		TEST_ASSERT(newest, "draw_card made no card item")
		drawn += newest
	other_deck.draw_card(player)
	var/obj/item/toy/cards/singlecard/foreign = locate_drawn_card(player, other_deck, list())
	TEST_ASSERT(foreign, "draw_card made no card item from the other deck")

	var/obj/item/toy/cards/singlecard/second = drawn[2]
	var/obj/item/toy/cards/singlecard/third = drawn[3]
	var/obj/item/toy/cards/cardhand/held_hand = new(player.loc)
	held_hand.currenthand += second.cardname
	held_hand.currenthand += third.cardname
	held_hand.parentdeck = deck
	qdel(second)
	qdel(third)

	TEST_ASSERT(cloth.add_deck(deck, null), "the deck was refused")
	TEST_ASSERT_EQUAL(length(cloth.game.deck), full_count - 3, "the game does not hold the cards left in the deck")

	var/obj/item/toy/cards/singlecard/first = drawn[1]
	TEST_ASSERT(cloth.attackby(first, player, ""), "attackby did not handle a card")
	TEST_ASSERT(QDELETED(first), "a card that went back under the deck still exists")
	TEST_ASSERT_EQUAL(length(cloth.game.deck), full_count - 2, "the card did not go back under the deck")

	TEST_ASSERT(cloth.attackby(held_hand, player, ""), "attackby did not handle a hand")
	TEST_ASSERT(QDELETED(held_hand), "a hand that went back under the deck still exists")
	TEST_ASSERT_EQUAL(length(cloth.game.deck), full_count, "the hand's cards did not go back under the deck")

	TEST_ASSERT(cloth.attackby(foreign, player, ""), "attackby did not handle a card of another deck")
	TEST_ASSERT(!QDELETED(foreign), "a card of another deck was deleted")
	TEST_ASSERT_EQUAL(length(cloth.game.deck), full_count, "a card of another deck joined the game")
	qdel(cloth)
	TEST_ASSERT_EQUAL(length(deck.cards), full_count, "the deck did not come back whole")
	TEST_ASSERT_EQUAL(length(uniqueList(deck.cards)), full_count, "the deck came back with a card twice")

/// The card item draw_card() just made from that deck, held or at the mob's feet, skipping ones already found
/datum/unit_test/gaming_cloth/proc/locate_drawn_card(mob/player, obj/item/toy/cards/deck/source_deck, list/already)
	for(var/obj/item/toy/cards/singlecard/card in player.held_items + player.loc.contents)
		if(card.parentdeck == source_deck && !(card in already))
			return card
	return null

/// Deleting a cloth mid-game leaves its deck on the tile with every card
/datum/unit_test/gaming_cloth/proc/check_deletion_returns_deck(obj/structure/gaming_cloth/cloth, obj/item/toy/cards/deck/deck, mob/player)
	var/datum/card_game/game = cloth.game
	TEST_ASSERT(cloth.handle_ops(player, list(list("op" = 60, "a" = "place", "up" = TRUE))), "placing a card changed nothing")
	var/turf/cloth_turf = cloth.loc
	qdel(cloth)
	TEST_ASSERT_EQUAL(deck.loc, cloth_turf, "the deck was not left on the cloth's tile")
	TEST_ASSERT_EQUAL(length(deck.cards), 52, "the deck did not get every card back")
	TEST_ASSERT_EQUAL(length(uniqueList(deck.cards)), 52, "the deck got a card back twice")
	TEST_ASSERT(QDELETED(game), "the game outlived the cloth")
