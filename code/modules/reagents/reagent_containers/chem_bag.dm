/obj/item/reagent_containers/chem_bag
	name = "chemical bag"
	desc = "Contains chemicals used for transfusion. Must be attached to an IV drip."
	icon = 'icons/obj/bloodpack.dmi'
	icon_state = "bloodpack"
	volume = 200
	fill_icon_thresholds = list(10, 20, 30, 40, 50, 60, 70, 80, 90, 100)
	reagent_flags = TRANSPARENT | ABSOLUTELY_GRINDABLE

/obj/item/reagent_containers/chem_bag/Initialize(mapload)
	. = ..()
	if(!icon_state)
		icon_state = "bloodpack"
		update_icon()
	if(initial(label_name))
		name = "[label_name] chemical bag"

/obj/item/reagent_containers/chem_bag/examine(mob/user)
	. = ..()
	if(reagents)
		if(volume == reagents.total_volume)
			. += "<span class='notice'>It is fully filled.</span>"
		else if(!reagents.total_volume)
			. += "<span class='notice'>It's empty.</span>"
		else
			. += "<span class='notice'>It seems [round(reagents.total_volume/volume*100)]% filled.</span>"


// Format example: use `label_name` instead of using `name` directly.
/obj/item/reagent_containers/chem_bag/epinephrine
	label_name = "epinephrine"
	// with label_name, name variable will become "epinephrine chemical bag"
	list_reagents = list(/datum/reagent/medicine/epinephrine = 200)
