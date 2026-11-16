/// Felt units between two cards a leaving player sets down along their edge
#define SET_DOWN_SPACING 12

/// The seat a mob holds, or 0
/datum/card_game/proc/seat_of(mob/user)
	if(isnull(user))
		return 0
	return seats.Find(user)

/// A seat's anchor on the felt as list(x, y): seat 1 bottom, 2 left, 3 top, 4 right in seat 1's view
/datum/card_game/proc/seat_anchor(seat)
	var/static/list/anchors = list(list(500, 880), list(120, 500), list(500, 120), list(880, 500))
	return anchors[seat]

/// The name a seat shows: what others would see of a living occupant, else its name
/datum/card_game/proc/seat_display_name(mob/occupant)
	if(isliving(occupant))
		var/mob/living/living_occupant = occupant
		return living_occupant.get_visible_name()
	return occupant.name

/// TRUE when the occupant has no client or is not conscious, which is when others may unseat it
/datum/card_game/proc/occupant_away(mob/occupant)
	return !occupant.client || occupant.stat != CONSCIOUS

/**
 * One bit per seat whose occupant is away, bit 0 for seat 1.
 *
 * Nothing in the game announces a player falling unconscious or disconnecting, so the owner compares this
 * from one status check to the next to notice it.
 */
/datum/card_game/proc/away_mask()
	. = 0
	for(var/seat in 1 to GAMING_CLOTH_SEATS)
		var/mob/occupant = seats[seat]
		if(occupant && occupant_away(occupant))
			. |= (1 << (seat - 1))

/**
 * Seats a mob, refusing a taken seat and a mob that already holds one.
 *
 * A mob is registered at most once per game, since registering the same signal twice from one listener is a
 * stack trace. Moving out of reach of the host, dying or being deleted then gives the seat up.
 */
/datum/card_game/proc/take_seat(mob/user, seat)
	if(!ismob(user) || QDELETED(user) || !valid_seat_number(seat))
		return FALSE
	if(!isnull(seats[seat]) || seat_of(user))
		return FALSE
	seats[seat] = user
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_seated_moved))
	RegisterSignal(user, COMSIG_QDELETING, PROC_REF(on_seated_gone))
	RegisterSignal(user, COMSIG_LIVING_DEATH, PROC_REF(on_seated_gone))
	log_event("sit", seat, "[seat_display_name(user)] sits down at the table.")
	changed()
	on_seat_change?.Invoke(seat, null, user)
	return TRUE

/**
 * Frees a seat, setting its hand down face down along that seat's edge.
 *
 * The hand is shuffled first, so the set-down order says nothing about the order it was held in. The seat's
 * peeks, shown hand and ack end with it, so the next player in that seat inherits nothing.
 * Arguments:
 * * kind - the event kind logged, "stand" or "unseat"
 */
/datum/card_game/proc/leave_seat(seat, kind = "stand")
	if(!acting_seat(seat))
		return FALSE
	var/mob/leaver = seats[seat]
	var/leaver_name = seat_display_name(leaver)

	var/list/set_down = shuffle(hands[seat])
	var/list/anchor = seat_anchor(seat)
	var/along_x = seat == 1 || seat == 3
	for(var/index in 1 to length(set_down))
		var/datum/card_game_card/card = set_down[index]
		var/offset = (index - (length(set_down) + 1) / 2) * SET_DOWN_SPACING
		move_card(card, CARD_ZONE_FELT)
		card.x = felt_coordinate(anchor[1] + (along_x ? offset : 0))
		card.y = felt_coordinate(anchor[2] + (along_x ? 0 : offset))

	for(var/datum/card_game_card/peeked as anything in felt)
		if(!peeked.peekers)
			continue
		peeked.peekers -= seat
		if(!length(peeked.peekers))
			peeked.peekers = null

	showing[seat] = FALSE
	acks[seat] = 0
	seats[seat] = null
	UnregisterSignal(leaver, seat_signals)
	if(kind == "unseat")
		log_event("unseat", seat, "[leaver_name] is unseated and [leaver.p_their()] hand is set down.")
	else
		log_event("stand", seat, "[leaver_name] leaves the table.")
	changed()
	on_seat_change?.Invoke(seat, leaver, null)
	return TRUE

/// Frees a seat whose occupant is away. It takes no acting seat, anyone at the cloth may do it
/datum/card_game/proc/unseat(seat)
	if(!acting_seat(seat) || !occupant_away(seats[seat]))
		return FALSE
	return leave_seat(seat, "unseat")

/// Shows the seat's hand to all, or hides it again. The log line names no card
/datum/card_game/proc/show(seat, on)
	if(!acting_seat(seat))
		return FALSE
	on = !!on
	if(showing[seat] == on)
		return FALSE
	showing[seat] = on
	var/mob/shower = seats[seat]
	if(on)
		log_event("show", seat, "[seat_display_name(shower)] shows [shower.p_their()] hand.")
	else
		log_event("hide", seat, "[seat_display_name(shower)] hides [shower.p_their()] hand.")
	changed()
	return TRUE

/// A seated mob moved. Out of reach of the host it gives up its seat
/datum/card_game/proc/on_seated_moved(mob/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(isnull(host) || in_range(source, host))
		return
	var/seat = seat_of(source)
	if(seat)
		INVOKE_ASYNC(src, PROC_REF(leave_seat), seat)

/// A seated mob died or is being deleted, and gives up its seat
/datum/card_game/proc/on_seated_gone(mob/source)
	SIGNAL_HANDLER
	var/seat = seat_of(source)
	if(seat)
		INVOKE_ASYNC(src, PROC_REF(leave_seat), seat)

#undef SET_DOWN_SPACING
