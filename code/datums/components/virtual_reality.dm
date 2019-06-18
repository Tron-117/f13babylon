/datum/component/virtual_reality
	dupe_mode = COMPONENT_DUPE_ALLOWED //mindswap memes, shouldn't stack up otherwise.
	var/datum/mind/mastermind // where is my mind t. pixies
	var/datum/mind/current_mind
	var/obj/machinery/vr_sleeper/vr_sleeper
	var/datum/action/quit_vr/quit_action
	var/you_die_in_the_game_you_die_for_real = FALSE

/datum/component/virtual_reality/Initialize(mob/M, obj/machinery/vr_sleeper/gaming_pod, yolo = FALSE, new_char = TRUE)
	if(!ismob(parent) || !istype(M))
		return COMPONENT_INCOMPATIBLE
	var/mob/vr_M
	mastermind = M.mind
	RegisterSignal(mastermind, COMSIG_MIND_TRANSFER, .proc/switch_player)
	RegisterSignal(mastermind, COMSIG_MOB_KEY_CHANGE, .proc/switch_player)
	you_die_in_the_game_you_die_for_real = yolo
	quit_action = new()
	RegisterSignal(quit_action, COMSIG_ACTION_TRIGGER, .proc/revert_to_reality)
	if(gaming_pod)
		vr_sleeper = gaming_pod
		RegisterSignal(vr_sleeper, COMSIG_ATOM_EMAG_ACT, .proc/you_only_live_once)
		RegisterSignal(vr_sleeper, COMSIG_MACHINE_EJECT_OCCUPANT, .proc/virtual_reality_in_a_virtual_reality)
	vr_M.ckey = M.ckey
	SStgui.close_user_uis(M, src)

/datum/component/virtual_reality/RegisterWithParent()
	var/mob/M = parent
	current_mind = M.mind
	quit_action.Grant(M)
	RegisterSignal(M, list(COMSIG_MOB_DEATH, COMSIG_PARENT_QDELETED), .proc/game_over)
	RegisterSignal(M, list(COMSIG_MOB_KEY_CHANGE, COMSIG_MIND_TRANSFER), .proc/pass_me_the_remote)
	RegisterSignal(M, COMSIG_MOB_GHOSTIZE, .proc/be_a_quitter)
	mastermind.current.audiovisual_redirect = M

/datum/component/virtual_reality/UnregisterFromParent()
	quit_action.Remove(parent)
	UnregisterSignal(parent, list(COMSIG_MOB_DEATH, COMSIG_PARENT_QDELETED, COMSIG_MOB_KEY_CHANGE, COMSIG_MOB_GHOSTIZE))
	UnregisterSignal(quit_action, COMSIG_ACTION_TRIGGER)
	UnregisterSignal(current_mind, COMSIG_MIND_TRANSFER)
	current_mind = null
	mastermind.current.audiovisual_redirect = null

/datum/component/virtual_reality/proc/switch_player(datum/source, mob/new_mob, mob/old_mob)
	if(vr_sleeper || !new_mob.mind)
		// Machineries currently don't deal up with the occupant being polymorphed or the such. Or the admin dared to use outdated transformation procs.
		virtual_reality_in_a_virtual_reality(FALSE, new_mob)
		return
	old_mob.audiovisual_redirect = null
	old_mob.inception = null
	new_mob.audiovisual_redirect = parent
	new_mob.inception = src

/datum/component/virtual_reality/proc/action_trigger(datum/signal_source, datum/action/source)
	if(source != quit_action)
		return COMPONENT_ACTION_BLOCK_TRIGGER
	revert_to_reality(signal_source)

/datum/component/virtual_reality/proc/you_only_live_once()
	if(you_die_in_the_game_you_die_for_real)
		return FALSE
	you_die_in_the_game_you_die_for_real = TRUE
	return TRUE

/datum/component/virtual_reality/proc/pass_me_the_remote(datum/source, mob/new_mob)
	if(new_mob == mastermind.current)
		revert_to_reality(source)
	new_mob.TakeComponent(src)
	return TRUE

/datum/component/virtual_reality/PostTransfer()
	if(!ismob(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/virtual_reality/proc/revert_to_reality(datum/source)
	quit_it()

/datum/component/virtual_reality/proc/game_over(datum/source)
	quit_it(TRUE, TRUE)

/datum/component/virtual_reality/proc/be_a_quitter(datum/source, can_reenter_corpse)
	quit_it()
	return COMPONENT_BLOCK_GHOSTING

/datum/component/virtual_reality/proc/virtual_reality_in_a_virtual_reality(killme = FALSE, mob_override)
	var/mob/M = parent
	if(!QDELETED(M.inception)  && M.inception.parent)
		M.inception.virtual_reality_in_a_virtual_reality()
	quit_it(FALSE, killme, mob_override)
	if(killme)
		M.death(FALSE)

/datum/component/virtual_reality/proc/quit_it(deathcheck = FALSE, cleanup = FALSE, mob_override)
	var/mob/M = parent
	var/mob/dreamer = mob_override ? mob_override : mastermind.current
	if(!mastermind)
		to_chat(M, "<span class='warning'>You feel like something terrible happened. You try to wake up from this dream, but you can't...</span>")
	else
		dreamer.ckey = M.ckey
		dreamer.stop_sound_channel(CHANNEL_HEARTBEAT)
		dreamer.inception = null
		dreamer.audiovisual_redirect = null
		if(deathcheck)
			if(you_die_in_the_game_you_die_for_real)
				to_chat(mastermind, "<span class='warning'>You feel everything fading away...</span>")
				dreamer.death(FALSE)
		if(cleanup)
			var/obj/effect/vr_clean_master/cleanbot = locate() in get_area(M)
			if(cleanbot)
				LAZYADD(cleanbot.corpse_party, M)
		if(vr_sleeper)
			vr_sleeper.vr_mob = null
			vr_sleeper = null
	qdel(src)

/datum/component/virtual_reality/Destroy()
	var/datum/action/quit_vr/delet_me = quit_action
	. = ..()
	qdel(delet_me)