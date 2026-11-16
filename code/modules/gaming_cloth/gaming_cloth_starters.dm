/**
 * Lays out a gaming cloth under an item, or adds the item to the cloth already there.
 *
 * An item already lying on a tile next to the user stays there, and the cloth goes on that tile or not at all.
 * An item the user holds, or one in a bag within reach, is placed first by gaming_cloth_place_starter(), table
 * first, and stays where it was when no tile can take a cloth.
 *
 * A tile that already has a cloth is joined at once. A new cloth takes two seconds and a table tile or open ground,
 * and every check runs again after the wait, so a cloth someone else laid there meanwhile is joined rather than
 * doubled. A cloth this call made that then takes no item is removed again.
 */
/proc/lay_gaming_cloth(mob/user, obj/item/starter)
	if(!isliving(user) || QDELETED(starter))
		return FALSE
	if(!isturf(starter.loc) && !gaming_cloth_place_starter(user, starter))
		return FALSE
	if(!gaming_cloth_starter_ready(user, starter))
		return FALSE
	var/turf/spot = starter.loc
	var/obj/structure/gaming_cloth/cloth = locate(/obj/structure/gaming_cloth) in spot
	if(cloth)
		return gaming_cloth_take_starter(cloth, starter, user)
	if(!gaming_cloth_spot_free(spot, user))
		return FALSE
	to_chat(user, span_notice("I start laying out a gaming cloth."))
	if(!do_after(user, 2 SECONDS, TRUE, starter))
		return FALSE
	if(!gaming_cloth_starter_ready(user, starter) || starter.loc != spot)
		return FALSE
	cloth = locate(/obj/structure/gaming_cloth) in spot
	var/laid_new = FALSE
	if(!cloth)
		if(!gaming_cloth_spot_free(spot, user))
			return FALSE
		cloth = new /obj/structure/gaming_cloth(spot)
		laid_new = TRUE
	if(!gaming_cloth_take_starter(cloth, starter, user))
		if(laid_new)
			qdel(cloth)
		return FALSE
	if(laid_new)
		cloth.announce(span_notice("[user] lays out a gaming cloth."))
	return TRUE

/**
 * Moves a held or bagged starter onto the tile its cloth will use, and returns TRUE once it lies there.
 *
 * Nothing moves until a tile is chosen. The tile is, in this order: the tile the user faces when a click could reach
 * it and it has a table, the user's own tile when it can take a cloth, the faced tile when it is open ground that
 * can take one. A tile that already has a cloth counts at its place in that order, and that cloth is asked first
 * whether it can take the starter. If it cannot, its own line is said and nothing moves. With no tile the user is
 * told once and the starter stays in the hand or the bag. A bag gives it up through its storage, so its grid stays
 * right.
 */
/proc/gaming_cloth_place_starter(mob/user, obj/item/starter)
	if(QDELETED(user) || user.stat != CONSCIOUS || user.incapacitated())
		return FALSE
	var/held = user.is_holding(starter)
	if(!held && !gaming_cloth_within_reach(user, starter))
		return FALSE
	var/turf/spot = gaming_cloth_pick_spot(user)
	if(!spot)
		to_chat(user, span_warning("There is no room here to lay out the cloth."))
		return FALSE
	// A cloth on the chosen tile is the target, so no later tile is tried and no second cloth laid
	var/obj/structure/gaming_cloth/waiting_cloth = locate(/obj/structure/gaming_cloth) in spot
	if(waiting_cloth && !waiting_cloth.can_take_starter(starter, user))
		return FALSE
	if(held)
		user.transferItemToLoc(starter, spot)
	else
		starter.remove_item_from_storage(spot)
	return starter.loc == spot

/// The tile a held or bagged starter's cloth goes on, table first, or null. Says nothing, the caller speaks
/proc/gaming_cloth_pick_spot(mob/user)
	var/turf/own_turf = get_turf(user)
	var/turf/ahead = get_step(user, user.dir)
	var/ahead_reachable = ahead && ahead != own_turf && ahead.Adjacent(user)
	if(ahead_reachable && (locate(/obj/structure/table) in ahead))
		return ahead
	if(own_turf && ((locate(/obj/structure/gaming_cloth) in own_turf) || gaming_cloth_spot_free(own_turf)))
		return own_turf
	if(ahead_reachable && ((locate(/obj/structure/gaming_cloth) in ahead) || gaming_cloth_spot_free(ahead)))
		return ahead
	return null

/**
 * TRUE when the item is where a fresh click from the user could reach it: in their hands, in a bag they carry, or
 * on a tile next to them.
 *
 * It is the click's own Adjacent(), so it fails for an item inside a gaming cloth or held or worn by someone else.
 */
/proc/gaming_cloth_within_reach(mob/user, obj/item/starter)
	return !QDELETED(user) && !QDELETED(starter) && starter.Adjacent(user)

/// TRUE when the user can act and the item lies on a tile next to them, checked before and after any wait. A deck set up as the card table is never ready
/proc/gaming_cloth_starter_ready(mob/user, obj/item/starter)
	if(QDELETED(user) || QDELETED(starter))
		return FALSE
	if(user.stat != CONSCIOUS || user.incapacitated())
		return FALSE
	if(istype(starter, /obj/item/toy/cards/deck))
		var/obj/item/toy/cards/deck/deck = starter
		if(deck.card_table_mode)
			return FALSE
	return isturf(starter.loc) && in_range(starter, user)

/**
 * TRUE when a cloth may be laid on the tile: a table, or open ground with no structure and nothing dense, as a bedroll needs.
 *
 * Arguments:
 * * user - told why the tile is refused, or null for a silent check
 */
/proc/gaming_cloth_spot_free(turf/spot, mob/user)
	if(locate(/obj/structure/table) in spot)
		return TRUE
	if(!isfloorturf(spot))
		if(user)
			to_chat(user, span_warning("I need a table or open ground to lay the cloth on."))
		return FALSE
	for(var/obj/thing in spot)
		if(istype(thing, /obj/structure) || (thing.density && !(thing.flags_1 & ON_BORDER_1)))
			if(user)
				to_chat(user, span_warning("There is no room for the cloth here."))
			return FALSE
	return TRUE

/// Adds a starter item to a cloth's game by its kind
/proc/gaming_cloth_take_starter(obj/structure/gaming_cloth/cloth, obj/item/starter, mob/user)
	if(istype(starter, /obj/item/toy/cards/deck))
		return cloth.add_deck(starter, user)
	return FALSE

/**
 * Asks whether a deck becomes the rules-based card table or a gaming cloth, and returns the button or null.
 *
 * The prompt can stay open for any length of time, so once it returns everything a fresh right-click would
 * need is checked again. A deck someone laid into a cloth meanwhile is inside that cloth, so it fails the last
 * check and the card table can never pull it back out.
 */
/obj/item/toy/cards/deck/proc/pick_table_kind(mob/user)
	var/choice = tgui_alert(user, "Card table: blackjack and poker with the rules built in. Gaming cloth: any game, with cards and dice you move yourself.", "Lay out the deck", list(GAMING_CLOTH_PICK_TABLE, GAMING_CLOTH_PICK_CLOTH))
	if(!choice || QDELETED(user) || QDELETED(src))
		return null
	if(user.stat != CONSCIOUS || user.incapacitated() || card_table_mode)
		return null
	if(!gaming_cloth_within_reach(user, src))
		return null
	return choice

/obj/item/toy/cards/deck/rmb_self(mob/user)
	// A right-click on the item in the active hand comes here, not to attack_right
	attack_right(user)
