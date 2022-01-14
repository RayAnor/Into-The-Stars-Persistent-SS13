// Powersink - used to drain station power

/obj/item/device/powersink
	name = "power sink"
	desc = "A nulling power sink which drains energy from electrical systems."
	icon_state = "powersink0"
	item_state = "electronic"
	w_class = ITEM_SIZE_LARGE
	obj_flags = OBJ_FLAG_CONDUCTIBLE
	throwforce = 5
	throw_speed = 1
	throw_range = 2

	matter = list(MATERIAL_STEEL = 750, MATERIAL_WASTE = 750)

	origin_tech = list(TECH_POWER = 3, TECH_ILLEGAL = 5, TECH_ESOTERIC = 5)
	var/drain_rate = 1500000		// amount of power to drain per tick
	var/apc_drain_rate = 5000 		// Max. amount drained from single APC. In Watts.
	var/dissipation_rate = 20000	// Passive dissipation of drained power. In Watts.
	var/power_drained = 0 			// Amount of power drained.
	var/max_power = 5e9				// Detonation point.
	var/mode = 0					// 0 = off, 1=clamped (off), 2=operating
	var/drained_this_tick = 0		// This is unfortunately necessary to ensure we process powersinks BEFORE other machinery such as APCs.

	var/datum/powernet/PN			// Our powernet
	var/obj/structure/cable/attached		// the attached cable

	var/const/DISCONNECTED = 0
	var/const/CLAMPED_OFF = 1
	var/const/OPERATING = 2

/obj/item/device/powersink/update_icon()
	icon_state = "powersink[mode == OPERATING]"
	..()

/obj/item/device/powersink/proc/set_mode(value)
	if(value == mode)
		return
	switch(value)
		if(DISCONNECTED)
			attached = null
			if(mode == OPERATING)
				STOP_PROCESSING_POWER_OBJECT(src)
			anchored = FALSE
		if(CLAMPED_OFF)
			if(!attached)
				return
			if(mode == OPERATING)
				STOP_PROCESSING_POWER_OBJECT(src)
			anchored = TRUE
		if(OPERATING)
			if(!attached)
				return
			START_PROCESSING_POWER_OBJECT(src)
			anchored = TRUE
	mode = value
	update_icon()
	set_light(0)

/obj/item/device/powersink/Destroy()
	if(mode == OPERATING)
		STOP_PROCESSING_POWER_OBJECT(src)
	. = ..()

/obj/item/device/powersink/attackby(var/obj/item/I, var/mob/user)
	if(isScrewdriver(I))
		if(mode == DISCONNECTED)
			var/turf/T = loc
			if(isturf(T) && !!T.is_plating())
				attached = locate() in T
				if(!attached)
					to_chat(user, "No exposed cable here to attach to.")
				else
					set_mode(CLAMPED_OFF)
					src.visible_message("<span class='notice'>[user] attaches [src] to the cable!</span>")
			else
				to_chat(user, "Device must be placed over an exposed cable to attach to it.")
		else
			set_mode(DISCONNECTED)
			src.visible_message("<span class='notice'>[user] detaches [src] from the cable!</span>")
	else
		return ..()

/obj/item/device/powersink/attack_ai()
	return

/obj/item/device/powersink/attack_hand(var/mob/user)
	switch(mode)
		if(DISCONNECTED)
			..()
		if(CLAMPED_OFF)
			user.visible_message("<span class='notice'>[user] activates [src]!</span>")
			set_mode(OPERATING)
		if(OPERATING)  //This switch option wasn't originally included. It exists now. --NeoFite
			src.visible_message("<span class='notice'>[user] deactivates [src]!</span>")
			set_mode(CLAMPED_OFF)

/obj/item/device/powersink/pwr_drain()
	if(!attached)
		set_mode(DISCONNECTED)
		return

	if(drained_this_tick)
		return 1
	drained_this_tick = 1

	var/drained = 0

	if(!PN)
		return 1

	set_light(12)
	PN.trigger_warning()
	// found a powernet, so drain up to max power from it
	drained = PN.draw_power(drain_rate)
	// if tried to drain more than available on powernet
	// now look for APCs and drain their cells
	if(drained < drain_rate)
		for(var/obj/machinery/power/terminal/T in PN.nodes)
			// Enough power drained this tick, no need to torture more APCs
			if(drained >= drain_rate)
				break
			if(istype(T.master, /obj/machinery/power/apc))
				var/obj/machinery/power/apc/A = T.master
				if(A.operating && A.cell)
					var/cur_charge = A.cell.charge / CELLRATE
					var/drain_val = min(apc_drain_rate, cur_charge)
					A.cell.use(drain_val * CELLRATE)
					drained += drain_val
	power_drained += drained
	return 1


/obj/item/device/powersink/Process()
	drained_this_tick = 0
	power_drained -= min(dissipation_rate, power_drained)
	if(power_drained > max_power * 0.95)
		playsound(src, 'sound/effects/screech.ogg', 100, 1, 1)
	if(power_drained >= max_power)
		explosion(src.loc, 3,6,9,12)
		qdel(src)
		return
	if(attached && attached.powernet)
		PN = attached.powernet
	else
		PN = null
