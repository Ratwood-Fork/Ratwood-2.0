/// Per ckey, list(topic limiter minute, ops messages counted in it). The count behind a window's act_used
GLOBAL_LIST_EMPTY(gaming_cloth_act_counts)

/// Largest op a window may send, 2 to the 24th: past it a DM number no longer holds every whole number, so op + 1 could equal op
#define LARGEST_OP 16777216

/// The two sounds a gaming cloth window plays itself, a card landing and a card turning over
/datum/asset/simple/gaming_cloth_sounds
	assets = list(
		"gaming_cloth_land.ogg" = 'sound/foley/dropsound/paper_drop.ogg',
		"gaming_cloth_turn.ogg" = 'sound/items/book_page.ogg',
	)

/**
 * Opens a window, or passes on tgui's forced update of an open one while the cloth itself is pushing.
 *
 * Any interactive window can make tgui force an update of every window on the cloth, and each forced update
 * comes through here with ui set. Only our own push lets it through. A viewer has one gaming cloth window, so
 * opening this one closes any other cloth's.
 */
/obj/structure/gaming_cloth/ui_interact(mob/user, datum/tgui/ui)
	if(ui)
		// Every setSharedState passes here, and a later full update would send what it stored
		tgui_shared_states = null
		if(pushing)
			SStgui.try_update_ui(user, src, ui)
		return
	if(SStgui.get_open_ui(user, src))
		return
	var/datum/card_game/our_game = get_game()
	if(!our_game.seat_of(user) && watcher_window_count() >= GAMING_CLOTH_MAX_WATCHERS)
		to_chat(user, span_warning("Too many are watching this table already."))
		return
	var/list/open_windows = user.tgui_open_uis?.Copy()
	for(var/datum/tgui/other_ui as anything in open_windows)
		if(other_ui.src_object != src && istype(other_ui.src_object, /obj/structure/gaming_cloth))
			other_ui.close()
	// Known before open(), whose first status check would otherwise take the viewer for a moved window
	var/user_ref = REF(user)
	LAZYOR(known_viewers, user_ref)
	ui = new(user, src, "GamingCloth", "Gaming Cloth")
	ui.set_autoupdate(FALSE)
	if(!ui.open())
		known_viewers -= user_ref

/obj/structure/gaming_cloth/ui_close(mob/user)
	LAZYREMOVE(known_viewers, REF(user))

/obj/structure/gaming_cloth/ui_state(mob/user)
	return GLOB.always_state

/**
 * The window's status, overridden whole: tgui calls nothing else to decide it.
 *
 * Interactive for a player next to the cloth who can act, view only for anyone else within
 * GAMING_CLOTH_WATCH_RANGE on the same level, closed beyond that or without a client.
 *
 * It also watches two things nothing announces, and never pushes for either, since tgui calls it in the middle
 * of its own update. A player going away or coming back changes the game's away_mask(), and the change is
 * pushed a decisecond later. A viewer missing from known_viewers means a client moved its window to another
 * body without telling the cloth, so the list is rebuilt from the open windows and that window is sent a full
 * update a decisecond later, or it keeps showing the old body's seat and hand.
 */
/obj/structure/gaming_cloth/ui_status(mob/user, datum/ui_state/state)
	tgui_shared_states = null
	var/away_mask = get_game().away_mask()
	if(away_mask != last_away_mask)
		last_away_mask = away_mask
		addtimer(CALLBACK(src, PROC_REF(away_changed)), 0.1 SECONDS, TIMER_UNIQUE)
	var/user_ref = REF(user)
	if(!(user_ref in known_viewers))
		known_viewers = list(user_ref)
		for(var/datum/tgui/open_ui as anything in open_uis)
			if(open_ui.user)
				known_viewers |= REF(open_ui.user)
		addtimer(CALLBACK(src, PROC_REF(resend_window), user), 0.1 SECONDS)
	if(!user.client || !within_watch_range(user))
		return UI_CLOSE
	if(isobserver(user))
		return UI_UPDATE
	if(can_play(user))
		return UI_INTERACTIVE
	return UI_UPDATE

/// Pushes the game after a seated player went away or came back, which nothing in the game announces
/obj/structure/gaming_cloth/proc/away_changed()
	game?.changed()

/// Sends one viewer's window a full update, for a window that now belongs to another body
/obj/structure/gaming_cloth/proc/resend_window(mob/user)
	var/datum/tgui/ui = SStgui.get_open_ui(user, src)
	if(!ui)
		return
	tgui_shared_states = null
	ui.send_full_update()

/// TRUE when the mob may act at this cloth: living, awake, able, and next to it
/obj/structure/gaming_cloth/proc/can_play(mob/user)
	return isliving(user) && user.stat == CONSCIOUS && !user.incapacitated() && in_range(src, user)

/// Windows open on this cloth for mobs that hold no seat
/obj/structure/gaming_cloth/proc/watcher_window_count()
	. = 0
	for(var/datum/tgui/open_ui as anything in open_uis)
		if(!game?.seat_of(open_ui.user))
			. += 1

/obj/structure/gaming_cloth/ui_static_data(mob/user)
	return list(
		"act_budget" = act_budget(),
		"act_used" = act_used(user),
	)

/obj/structure/gaming_cloth/ui_data(mob/user)
	tgui_shared_states = null
	return get_game().data_for(user)

/obj/structure/gaming_cloth/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/gaming_cloth_sounds))

/// Ops messages a minute a client's cloth window may send, GAMING_CLOTH_ACT_SHARE of the topic limit and at least 10, or 0 when no limit is set
/obj/structure/gaming_cloth/proc/act_budget()
	var/minute_limit = CONFIG_GET(number/minute_topic_limit)
	if(!minute_limit)
		return 0
	return max(10, round(minute_limit * GAMING_CLOTH_ACT_SHARE))

/// Ops messages counted from this mob's player in the topic limiter's current minute
/obj/structure/gaming_cloth/proc/act_used(mob/user)
	var/user_ckey = user?.ckey
	if(!user_ckey)
		return 0
	var/list/count = GLOB.gaming_cloth_act_counts[user_ckey]
	if(!count || count[1] != round(world.time, 600))
		return 0
	return count[2]

/// Counts one ops message from this mob's player. The minute is the topic limiter's own, so the two count the same window
/obj/structure/gaming_cloth/proc/count_act(mob/user)
	var/user_ckey = user?.ckey
	if(!user_ckey)
		return
	var/minute = round(world.time, 600)
	var/list/count = GLOB.gaming_cloth_act_counts[user_ckey]
	if(!count || count[1] != minute)
		count = list(minute, 0)
		GLOB.gaming_cloth_act_counts[user_ckey] = count
	count[2] += 1

/**
 * The window's two actions. Always returns FALSE, since every push goes through queue_update().
 *
 * sync is answered whatever the window's status. ops runs only from an interactive window. A message that
 * changed nothing gets the seat's ack alone, to that one window.
 */
/obj/structure/gaming_cloth/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	..()
	if(!ui)
		return FALSE
	if(action == "sync")
		// A window that mounted and asks is ready, even if the topic limiter dropped its ping reply
		ui.initialized = TRUE
		ui.send_update()
		return FALSE
	if(action != "ops" || ui.status != UI_INTERACTIVE)
		return FALSE
	var/mob/user = ui.user
	count_act(user)
	if(handle_ops(user, islist(params) ? params["list"] : null))
		return FALSE
	var/seat = game?.seat_of(user)
	if(!seat)
		return FALSE
	tgui_shared_states = null
	ui.send_update(list("ack" = game.acks[seat]))
	return FALSE

/**
 * Runs one window message's actions in order and returns TRUE when anything changed.
 *
 * Its own proc so the unit test can drive it with no window. The whole message is refused unless the user can
 * play and it is a list of at most GAMING_CLOTH_OPS_PER_MESSAGE entries. An entry that is not a list with a
 * numeric op and a text a is skipped. op is rounded like every other number from a window, so 2.5 counts as 3,
 * and an entry whose rounded op is not 1 to LARGEST_OP is skipped with no action and no ack. Every other entry
 * raises the acting seat's ack to its op, accepted or not. Nothing is pushed until the last entry, then one push
 * carries the final state and ack.
 */
/obj/structure/gaming_cloth/proc/handle_ops(mob/user, list/ops)
	if(!can_play(user) || !islist(ops) || length(ops) > GAMING_CLOTH_OPS_PER_MESSAGE)
		return FALSE
	var/datum/card_game/our_game = get_game()
	batch_time = world.time
	batch_dirty = FALSE
	for(var/list/entry as anything in ops)
		if(!islist(entry))
			continue
		var/op = entry["op"]
		var/action = entry["a"]
		if(!isnum(op) || !istext(action))
			continue
		op = round(op, 1)
		// Written so a value no comparison holds for is skipped too
		if(!(op >= 1 && op <= LARGEST_OP))
			continue
		run_op(user, our_game, action, entry)
		var/seat = our_game.seat_of(user)
		if(seat)
			our_game.acks[seat] = max(our_game.acks[seat], op)
	batch_time = -1
	if(!batch_dirty)
		return FALSE
	queue_update()
	return TRUE

/**
 * Hands one window action to the game, mapped by name, never by calling a proc a client named.
 *
 * sit and unseat need no seat of the user's own, every other action acts from the user's seat. The game checks
 * every value it is given. Pack Up sleeps through its wait, so it runs async.
 */
/obj/structure/gaming_cloth/proc/run_op(mob/user, datum/card_game/our_game, action, list/entry)
	switch(action)
		if("sit")
			if(our_game.take_seat(user, entry["seat"]))
				announce(span_notice("[user] sits down at the gaming cloth."))
			return
		if("unseat")
			our_game.unseat(entry["seat"])
			return
	var/seat = our_game.seat_of(user)
	if(!seat)
		return
	switch(action)
		if("stand")
			if(our_game.leave_seat(seat))
				announce(span_notice("[user] gets up from the gaming cloth."))
		if("draw")
			our_game.draw(seat)
		if("deal")
			if(our_game.deal(seat, entry["count"]))
				announce(span_notice("[user] deals the cards."), 'sound/foley/dropsound/paper_drop.ogg')
		if("place")
			our_game.place(seat, entry["up"], entry["x"], entry["y"])
		if("shuffle")
			if(our_game.shuffle_deck(seat))
				announce(span_notice("[user] shuffles the deck."), 'sound/items/cardshuffle.ogg')
		if("collect")
			if(our_game.collect(seat))
				announce(span_notice("[user] gathers up the cards."), 'sound/items/cardshuffle.ogg')
		if("play")
			our_game.play(seat, entry["h"], entry["x"], entry["y"], entry["up"])
		if("move")
			our_game.move(seat, entry["h"], entry["x"], entry["y"])
		if("flip")
			our_game.flip(seat, entry["h"])
		if("rotate")
			our_game.rotate(seat, entry["h"])
		if("peek")
			our_game.peek(seat, entry["h"])
		if("take")
			our_game.take(seat, entry["h"])
		if("return")
			our_game.return_card(seat, entry["h"], entry["where"])
		if("show")
			if(our_game.show(seat, entry["on"]) && entry["on"])
				announce(span_notice("[user] shows [user.p_their()] hand."))
		if("pack_up")
			INVOKE_ASYNC(src, PROC_REF(try_fold), user)

#undef LARGEST_OP
