
/*
	Hello, friends, this is Doohl from sexylands. You may be wondering what this
	monstrous code file is. Sit down, boys and girls, while I tell you the tale.


	The telecom machines were designed to be compatible with any radio
	signals, provided they use subspace transmission. Currently they are only used for
	headsets, but they can eventually be outfitted for real COMPUTER networks. This
	is just a skeleton, ladies and gentlemen.

	Look at radio.dm for the prequel to this code.
*/

GLOBAL_LIST_EMPTY(telecomms_list)

/obj/machinery/telecomms
	icon = 'icons/obj/machines/telecomms.dmi'
	critical_machine = TRUE
	light_color = LIGHT_COLOR_CYAN

	network_id = __NETWORK_SERVER

	var/list/links = list() // list of machines this machine is linked to
	var/traffic = 0 // value increases as traffic increases
	var/netspeed = 2.5 // how much traffic to lose per second (50 gigabytes/second * netspeed)
	var/list/autolinkers = list() // list of text/number values to link with
	var/id = "NULL" // identification string
	var/network = "NULL" // the network of the machinery

	var/list/freq_listening = list() // list of frequencies to tune into: if none, will listen to all

	var/on = TRUE
	var/toggled = TRUE 	// Is it toggled on
	var/long_range_link = FALSE  // Can you link it across Z levels or on the otherside of the map? (Relay & Hub)
	var/hide = FALSE  // Is it a hidden machine?


/obj/machinery/telecomms/proc/relay_information(datum/signal/subspace/signal, filter, copysig, amount = 20)
	// relay signal to all linked machinery that are of type [filter]. If signal has been sent [amount] times, stop sending

	if(!on)
		return
	var/send_count = 0
	// Apply some lag based on traffic rates
	var/netlag = round(traffic / 50)
	if(netlag > signal.data["slow"])
		signal.data["slow"] = netlag

	// Aply some lag from throttling
	var/efficiency = GetComponent(/datum/component/server).efficiency
	var/throttling = (10 - 10 * efficiency)
	signal.data["slow"] += throttling

	// Loop through all linked machines and send the signal or copy.
	for(var/obj/machinery/telecomms/machine in links)
		if(filter && !istype( machine, filter ))
			continue
		if(!machine.on)
			continue
		if(amount && send_count >= amount)
			break
		if(get_virtual_z_level() != machine.loc.get_virtual_z_level() && !long_range_link && !machine.long_range_link)
			continue

		send_count++
		if(machine.is_freq_listening(signal))
			machine.traffic++

		if(copysig)
			machine.receive_information(signal.copy(), src)
		else
			machine.receive_information(signal, src)

	if(send_count > 0 && is_freq_listening(signal))
		traffic++

	return send_count

/obj/machinery/telecomms/proc/relay_direct_information(datum/signal/signal, obj/machinery/telecomms/machine)
	// send signal directly to a machine
	machine.receive_information(signal, src)

/obj/machinery/telecomms/proc/receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)
	// receive information from linked machinery

/obj/machinery/telecomms/proc/is_freq_listening(datum/signal/signal)
	// return TRUE if found, FALSE if not found
	return signal && (!freq_listening.len || (signal.frequency in freq_listening))

/obj/machinery/telecomms/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/server) // they generate heat
	update_network() // we try to connect to NTnet
	RegisterSignal(src, COMSIG_COMPONENT_NTNET_RECEIVE, PROC_REF(ntnet_receive))
	GLOB.telecomms_list += src
	if(mapload && autolinkers.len)
		return INITIALIZE_HINT_LATELOAD

/obj/machinery/telecomms/LateInitialize()
	..()
	for(var/obj/machinery/telecomms/telecomms_machine in GLOB.telecomms_list)
		if (long_range_link || IN_GIVEN_RANGE(src, telecomms_machine, 20))
			add_link(telecomms_machine)

/obj/machinery/telecomms/Destroy()
	UnregisterSignal(src, COMSIG_COMPONENT_NTNET_RECEIVE)
	GLOB.telecomms_list -= src
	for(var/obj/machinery/telecomms/comm in GLOB.telecomms_list)
		comm.links -= src
	links = list()
	return ..()

/obj/machinery/telecomms/proc/get_temperature()
	return GetComponent(/datum/component/server).temperature

/obj/machinery/telecomms/proc/get_efficiency()
	return GetComponent(/datum/component/server).efficiency

/obj/machinery/telecomms/proc/get_overheat_temperature()
	return GetComponent(/datum/component/server).overheated_temp

// Used in auto linking
/obj/machinery/telecomms/proc/add_link(obj/machinery/telecomms/T)
	var/turf/position = get_turf(src)
	var/turf/T_position = get_turf(T)
	var/same_zlevel = FALSE
	if(position && T_position)	//Stops a bug with a phantom telecommunications interceptor which is spawned by circuits caching their components into nullspace
		if(position.get_virtual_z_level() == T_position.get_virtual_z_level())
			same_zlevel = TRUE
	if(same_zlevel || (long_range_link && T.long_range_link))
		if(src != T)
			for(var/x in autolinkers)
				if(x in T.autolinkers)
					links |= T
					T.links |= src

/obj/machinery/telecomms/proc/update_network()
	if(!network || network == "NULL")
		return
	var/new_network_id = NETWORK_NAME_COMBINE(__NETWORK_SERVER, network) // should result in something like SERVER.TCOMMSAT
	var/area/A = get_area(src)
	if(A)
		if(!A.network_root_id)
			log_telecomms("Area '[A.name]([REF(A)])' has no network network_root_id, force assigning in object [src]([REF(src)])")
			SSnetworks.lookup_area_root_id(A)
			new_network_id = NETWORK_NAME_COMBINE(A.network_root_id, new_network_id) // should result in something like SS13.SERVER.TCOMMSAT
		else
			log_telecomms("Created [src]([REF(src)] in nullspace, assuming network to be in station")
			new_network_id = NETWORK_NAME_COMBINE(STATION_NETWORK_ROOT, new_network_id) // should result in something like SS13.SERVER.TCOMMSAT
	new_network_id = simple_network_name_fix(new_network_id) // make sure the network name is valid
	var/datum/ntnet/new_network = SSnetworks.create_network_simple(new_network_id)
	new_network.move_interface(GetComponent(/datum/component/ntnet_interface), new_network_id, network_id)
	network_id = new_network_id

/obj/machinery/telecomms/proc/ntnet_receive(datum/source, datum/netdata/data)

	//Check radio signal jamming
	if(is_jammed(JAMMER_PROTECTION_WIRELESS) || machine_stat & (BROKEN|NOPOWER|MAINT|EMPED))
		return

	switch(data.data["type"])
		if("ping") // we respond to the ping with our status
			var/list/send_data = list()
			send_data["name"] = name
			send_data["temperature"] = get_temperature()
			send_data["overheat_temperature"] = get_overheat_temperature()
			send_data["efficiency"] = get_efficiency()
			send_data["overheated"] = (machine_stat & OVERHEATED)

			ntnet_send(send_data, data["sender_id"])

/obj/machinery/telecomms/update_icon()
	if(on)
		if(panel_open)
			icon_state = "[initial(icon_state)]_o"
		else
			icon_state = initial(icon_state)
	else
		if(panel_open)
			icon_state = "[initial(icon_state)]_o_off"
		else
			icon_state = "[initial(icon_state)]_off"

/obj/machinery/telecomms/proc/update_power()
	var/newState = on

	if(toggled)
		if(machine_stat & (BROKEN|NOPOWER|EMPED|OVERHEATED)) // if powered, on. if not powered, off. if too damaged, off
			newState = FALSE
		else
			newState = TRUE
	else
		newState = FALSE

	if(newState != on)
		on = newState
		ui_update()
		set_light(on)

/obj/machinery/telecomms/process(delta_time)
	update_power()

	// Update the icon
	update_icon()

	if(traffic > 0)
		traffic -= netspeed * delta_time

/obj/machinery/telecomms/obj_break(damage_flag)
	. = ..()
	update_power()

/obj/machinery/telecomms/power_change()
	..()
	update_power()
