/**
 * # Gaming cloth
 *
 * A cloth laid on a table or on open ground where up to four players play any card game in a tgui window.
 * It owns a [/datum/card_game] and is that game's world object: it takes the deck item in and hands it back,
 * draws a few overlays, answers clicks and is the source of every window (`gaming_cloth_ui.dm`).
 *
 * ## Pushing to windows
 * The game tells the cloth of every change through [/obj/structure/gaming_cloth/proc/queue_update]. A change
 * pushes to every window at once when the last push was at least GAMING_CLOTH_UPDATE_INTERVAL ago, otherwise one
 * push is scheduled for when that interval ends, so no flood makes more than five pushes a second. While one
 * window message is being handled nothing is pushed, and one push follows its last action.
 *
 * ## Items
 * The deck item lies inside the cloth while its cards are in the game, holding none of them. It gets every card
 * back, shuffled, when the cloth is folded or destroyed, or when it leaves the cloth any other way.
 */
/obj/structure/gaming_cloth
	name = "gaming cloth"
	desc = "A square of felt laid out for cards and dice."
	icon = 'icons/roguetown/misc/gaming_cloth.dmi'
	icon_state = "cloth"
	color = "#5f9a63"
	anchored = TRUE
	density = FALSE
	layer = TABLE_LAYER + 0.05
	max_integrity = 40
	resistance_flags = FLAMMABLE
	/// The card game, made on first use by get_game(). Read it through get_game() wherever it may not exist yet
	var/datum/card_game/game
	/// The deck item whose cards are in the game. It lies inside the cloth until it is handed back
	var/obj/item/toy/cards/deck/deck_item
	/// Ends GAMING_CLOTH_UPDATE_INTERVAL after the last push
	COOLDOWN_DECLARE(update_gate)
	/// TRUE while a push is scheduled. That push carries every change made before it fires
	var/update_queued = FALSE
	/// TRUE only while push_update() runs, so ui_interact() can tell our own push from a forced update
	var/pushing = FALSE
	/// world.time while handle_ops() runs, -1 otherwise. A stale stamp cannot hold pushes, since time moves on
	var/batch_time = -1
	/// TRUE when the game changed during the message handle_ops() is running
	var/batch_dirty = FALSE
	/// The game's away_mask() at the last status check, to notice a player going away or coming back
	var/last_away_mask = 0
	/// Ends GAMING_CLOTH_ANNOUNCE_INTERVAL after the last chat line and sound
	COOLDOWN_DECLARE(announce_gate)
	/// The overlay buckets as text, so the overlays are rebuilt only when one changes
	var/overlay_key
	/// REF() texts of the mobs that have a window open on this cloth. Text, so it keeps no mob alive
	var/list/known_viewers

/obj/structure/gaming_cloth/Destroy(force)
	eject_all()
	QDEL_NULL(game)
	known_viewers = null
	return ..()

/// The game, made the first time anything needs it, since a cloth nobody has used yet has none
/obj/structure/gaming_cloth/proc/get_game()
	RETURN_TYPE(/datum/card_game)
	if(game)
		return game
	game = new
	game.host = src
	game.on_change = CALLBACK(src, PROC_REF(queue_update))
	game.on_seat_change = CALLBACK(src, PROC_REF(seat_changed))
	return game

/// Called by the game after a seat changes hands, with the seat, the mob that left and the mob that sat
/obj/structure/gaming_cloth/proc/seat_changed(seat, mob/left, mob/sat)
	return

/**
 * Pushes the game to every window now, or schedules one push for when the update interval ends.
 *
 * Inside a message handled by handle_ops() it only marks the message dirty, and handle_ops() calls it once at
 * the end. A scheduled push owns the next flush, so a timer that fires late is never doubled by a direct push.
 * A cloth being deleted pushes nothing: its windows are about to close, and a timer added now would point at it.
 */
/obj/structure/gaming_cloth/proc/queue_update()
	if(QDELETED(src))
		return
	if(batch_time == world.time)
		batch_dirty = TRUE
		return
	if(update_queued)
		return
	if(COOLDOWN_FINISHED(src, update_gate))
		push_update()
		return
	update_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(push_update)), COOLDOWN_TIMELEFT(src, update_gate))

/// Refreshes the overlays and sends the game to every open window
/obj/structure/gaming_cloth/proc/push_update()
	update_queued = FALSE
	COOLDOWN_START(src, update_gate, GAMING_CLOTH_UPDATE_INTERVAL)
	refresh_overlays()
	pushing = TRUE
	SStgui.update_uis(src)
	pushing = FALSE

/// A chat line and an optional sound for the table's big moments, at most one per GAMING_CLOTH_ANNOUNCE_INTERVAL
/obj/structure/gaming_cloth/proc/announce(message, sound_file)
	if(!COOLDOWN_FINISHED(src, announce_gate))
		return
	COOLDOWN_START(src, announce_gate, GAMING_CLOTH_ANNOUNCE_INTERVAL)
	visible_message(message)
	if(sound_file)
		playsound(src, sound_file, 60, TRUE)

/obj/structure/gaming_cloth/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/toy/cards/deck))
		add_deck(I, user)
		return TRUE
	var/list/names = our_card_names(I)
	if(names)
		return_card_item(I, names, user)
		return TRUE
	if(user.cmode || (I.item_flags & ABSTRACT))
		return ..()
	if(!user.transferItemToLoc(I, drop_location(), silent = FALSE))
		return TRUE
	var/list/click_params = params2list(params)
	if(!click_params || !click_params["icon-x"] || !click_params["icon-y"])
		return TRUE
	// Clamped so the item never leaves the tile
	I.pixel_x = initial(I.pixel_x) + CLAMP(text2num(click_params["icon-x"]) - 16, -(world.icon_size/2), world.icon_size/2) + pixel_x
	I.pixel_y = initial(I.pixel_y) + CLAMP(text2num(click_params["icon-y"]) - 16, -(world.icon_size/2), world.icon_size/2) + pixel_y
	return TRUE

/**
 * TRUE when the cloth can take this item into its game now, else the user is told why and it returns FALSE.
 *
 * The one place an item that starts or joins a game is judged, so laying out can ask before anything moves and
 * add_deck() refuses with the same line. Only decks are taken so far, any other item is refused without a line.
 * Arguments:
 * * user - told why, or null
 */
/obj/structure/gaming_cloth/proc/can_take_starter(obj/item/starter, mob/user)
	if(!istype(starter, /obj/item/toy/cards/deck))
		return FALSE
	var/obj/item/toy/cards/deck/deck = starter
	if(deck.card_table_mode)
		if(user)
			to_chat(user, span_warning("Pack the card table up first."))
		return FALSE
	if(deck_item)
		if(user)
			to_chat(user, span_warning("There is already a deck on the cloth."))
		return FALSE
	return TRUE

/**
 * Puts a deck item's cards into the game and the item inside the cloth.
 *
 * Refuses a deck set up as the rules-based card table and a second deck. The cards go in only once the item
 * is inside the cloth. From then on the item holds no cards until it is handed back.
 * Arguments:
 * * user - who lays it, or null
 */
/obj/structure/gaming_cloth/proc/add_deck(obj/item/toy/cards/deck/deck, mob/user)
	if(!can_take_starter(deck, user))
		return FALSE
	if(user?.is_holding(deck))
		if(!user.transferItemToLoc(deck, src))
			return FALSE
	else
		deck.forceMove(src)
	if(deck.loc != src)
		return FALSE
	if(!get_game().add_cards(deck.cards, deck.deckstyle))
		deck.forceMove(drop_location())
		return FALSE
	deck_item = deck
	deck.cards = list()
	RegisterSignal(deck, COMSIG_QDELETING, PROC_REF(on_deck_deleted))
	RegisterSignal(deck, COMSIG_MOVABLE_MOVED, PROC_REF(on_deck_moved))
	if(user)
		to_chat(user, span_notice("I lay the deck on the cloth."))
	return TRUE

/// The names a single card or hand of this cloth's deck carries, or null for any other item, a card of another deck included
/obj/structure/gaming_cloth/proc/our_card_names(obj/item/I)
	if(isnull(deck_item))
		return null
	if(istype(I, /obj/item/toy/cards/singlecard))
		var/obj/item/toy/cards/singlecard/single = I
		return single.parentdeck == deck_item ? list(single.cardname) : null
	if(istype(I, /obj/item/toy/cards/cardhand))
		var/obj/item/toy/cards/cardhand/held_hand = I
		return held_hand.parentdeck == deck_item ? held_hand.currenthand.Copy() : null
	return null

/**
 * Puts a card or hand dealt from the cloth's deck item back under the game deck and deletes the item.
 *
 * Nothing is lost or doubled. The item leaves the user's inventory first, and only once the game has taken
 * the names is it deleted. If the game refuses them, a held item goes back into a hand, or onto the tile when
 * no hand takes it. An item that cannot leave the inventory is left as it is.
 */
/obj/structure/gaming_cloth/proc/return_card_item(obj/item/card_item, list/names, mob/user)
	var/held = user.is_holding(card_item)
	if(!user.temporarilyRemoveItemFromInventory(card_item))
		to_chat(user, span_warning("I can't let go of it."))
		return FALSE
	if(!game?.add_to_bottom(names))
		if(held && !user.put_in_hands(card_item))
			card_item.forceMove(drop_location())
		return FALSE
	qdel(card_item)
	to_chat(user, span_notice("I slip [length(names) == 1 ? "the card" : "the cards"] under the deck."))
	return TRUE

/// The deck item was deleted inside the cloth, so its cards leave the game with it
/obj/structure/gaming_cloth/proc/on_deck_deleted(obj/item/toy/cards/deck/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
	deck_item = null
	game?.clear_cards()

/// The deck item left the cloth some other way than eject_all(). It takes every card with it, so it is never in two games
/obj/structure/gaming_cloth/proc/on_deck_moved(obj/item/toy/cards/deck/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(source.loc == src)
		return
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
	deck_item = null
	if(game)
		source.cards = game.take_all_names()
	source.update_icon()

/**
 * Hands the deck item back with every card of the game, shuffled, onto the cloth's tile.
 *
 * Safe on a cloth that never had a game. The signals go before the move, so the move is not taken for the
 * deck leaving on its own.
 */
/obj/structure/gaming_cloth/proc/eject_all()
	if(isnull(deck_item))
		return
	var/obj/item/toy/cards/deck/deck = deck_item
	UnregisterSignal(deck, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
	deck_item = null
	if(game)
		deck.cards = game.take_all_names()
	deck.update_icon()
	var/atom/drop_spot = drop_location()
	if(isnull(drop_spot))
		qdel(deck)
		return
	deck.forceMove(drop_spot)

/obj/structure/gaming_cloth/attack_right(mob/user, params)
	// No parent call: the parent opens the window through _try_interact as a hand click does
	try_fold(user)
	return TRUE

/**
 * Folds the cloth away after two seconds, handing the deck back. Sleeps, so a window's Pack Up runs it async.
 *
 * Refused while anyone but the user is seated, and every check runs again once the wait is over.
 */
/obj/structure/gaming_cloth/proc/try_fold(mob/user)
	if(!can_fold(user))
		return FALSE
	to_chat(user, span_notice("I start folding up the cloth."))
	if(!do_after(user, 2 SECONDS, TRUE, src))
		return FALSE
	if(QDELETED(src) || !can_fold(user))
		return FALSE
	announce(span_notice("[user] folds up the gaming cloth."))
	qdel(src)
	return TRUE

/// TRUE when the user may fold the cloth now: able to play at it, and nobody else seated
/obj/structure/gaming_cloth/proc/can_fold(mob/user)
	if(!can_play(user))
		return FALSE
	for(var/mob/occupant as anything in game?.seats)
		if(occupant && occupant != user)
			to_chat(user, span_warning("Everyone else must leave the table first."))
			return FALSE
	return TRUE

/obj/structure/gaming_cloth/examine(mob/user)
	. = ..()
	if(game)
		var/list/seated_names = list()
		for(var/mob/occupant as anything in game.seats)
			if(occupant)
				seated_names += game.seat_display_name(occupant)
		if(length(seated_names))
			. += span_notice("[english_list(seated_names)] [length(seated_names) == 1 ? "sits" : "sit"] at it.")
	. += span_smallnotice("Click it to play or watch. Right-click it to fold it away once everyone else has left.")
	if(!game || !within_watch_range(user))
		return
	var/list/face_up_names = list()
	for(var/index in length(game.felt) to 1 step -1)
		var/datum/card_game_card/card = game.felt[index]
		if(card.face_up)
			face_up_names += card.name
	if(!length(face_up_names))
		return
	var/extra = length(face_up_names) - 8
	if(extra <= 0)
		. += span_notice("Face up on the felt: [english_list(face_up_names)].")
		return
	face_up_names.Cut(9)
	. += span_notice("Face up on the felt: [jointext(face_up_names, ", ")] and [extra] more.")

/// TRUE when the mob is on the cloth's level and within GAMING_CLOTH_WATCH_RANGE tiles of it
/obj/structure/gaming_cloth/proc/within_watch_range(mob/user)
	var/turf/cloth_turf = get_turf(src)
	var/turf/user_turf = get_turf(user)
	if(!cloth_turf || !user_turf || cloth_turf.z != user_turf.z)
		return FALSE
	return get_dist(cloth_turf, user_turf) <= GAMING_CLOTH_WATCH_RANGE

/// The deck pile's overlay bucket by cards left in the game deck: 0 none, 1 low, 2 half, 3 full, as the deck item draws itself
/obj/structure/gaming_cloth/proc/deck_bucket()
	var/count = length(game?.deck)
	if(count > 26)
		return 3
	if(count > 10)
		return 2
	if(count > 0)
		return 1
	return 0

/// Card backs drawn for the cards on the felt: none, 1 for one card, 2 for two to five, 3 for six or more
/obj/structure/gaming_cloth/proc/felt_bucket()
	var/count = length(game?.felt)
	if(count >= 6)
		return 3
	if(count >= 2)
		return 2
	if(count >= 1)
		return 1
	return 0

/// Rebuilds the overlays only when a bucket or the deck style changed, since most changes move no bucket
/obj/structure/gaming_cloth/proc/refresh_overlays()
	var/key = "[deck_bucket()]-[felt_bucket()]-[game?.deck_style]"
	if(key == overlay_key)
		return
	overlay_key = key
	update_icon()

/obj/structure/gaming_cloth/update_overlays()
	. = ..()
	var/style = game?.deck_style
	var/static/list/pile_sizes = list("low", "half", "full")
	var/pile = deck_bucket()
	if(pile)
		. += cloth_overlay("deck_[style]_[pile_sizes[pile]]", -5, 0)
	for(var/back in 1 to felt_bucket())
		. += cloth_overlay("singlecard_down_[style]", 3 + back, 2 - back)

/// One overlay from the deck's own sprites. RESET_COLOR, or the cloth's tint would turn it green
/obj/structure/gaming_cloth/proc/cloth_overlay(state, offset_x, offset_y)
	var/mutable_appearance/overlay = mutable_appearance('icons/obj/toy.dmi', state)
	overlay.appearance_flags = RESET_COLOR
	overlay.pixel_x = offset_x
	overlay.pixel_y = offset_y
	return overlay
