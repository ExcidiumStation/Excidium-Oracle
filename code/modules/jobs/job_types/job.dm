/datum/job
	//The name of the job
	var/title = "NOPE"

	//Job access. The use of minimal_access or access is determined by a config setting: config.jobs_have_minimal_access
	var/list/minimal_access = list()		//Useful for servers which prefer to only have access given to the places a job absolutely needs (Larger server population)
	var/list/access = list()				//Useful for servers which either have fewer players, so each person needs to fill more than one role, or servers which like to give more access, so players can't hide forever in their super secure departments (I'm looking at you, chemistry!)

	//Determines who can demote this position
	var/department_head = list()

	//Tells the given channels that the given mob is the new department head. See communications.dm for valid channels.
	var/list/head_announce = null

	//Bitflags for the job
	var/flag = 0
	var/department_flag = 0

	//Players will be allowed to spawn in as jobs that are set to "Station"
	var/faction = "None"

	//How many players can be this job
	var/total_positions = 0

	//How many players can spawn in as this job
	var/spawn_positions = 0

	//How many players have this job
	var/current_positions = 0

	//Supervisors, who this person answers to directly
	var/supervisors = ""

	//Sellection screen color
	var/selection_color = "#ffffff"


	//If this is set to 1, a text is printed to the player when jobs are assigned, telling him that he should let admins know that he has to disconnect.
	var/req_admin_notify

	//If you have the use_age_restriction_for_jobs config option enabled and the database set up, this option will add a requirement for players to be at least minimal_player_age days old. (meaning they first signed in at least that many days before.)
	var/minimal_player_age = 0

	var/outfit = null

	var/exp_requirements = 0

	var/exp_type = ""
	var/exp_type_department = ""

	//A special, very large and noticeable message for certain roles reminding them of something important. Ex: "Blueshields are not security"
	var/special_notice = ""

	// A link to the relevant wiki related to the job. Ex: "Space_law" would link to wiki.blah/Space_law
	var/wiki_page = ""

	var/tmp/list/gear_leftovers = list()

//Only override this proc, unless altering loadout code. Loadouts act on H but get info from M
//H is usually a human unless an /equip override transformed it
/datum/job/proc/after_spawn(mob/living/H, mob/M)
//do actions on H but send messages to M as the key may not have been transferred_yet
	if(!ishuman(H))
		return
	var/mob/living/carbon/human/human = H
	if(M.client && (M.client.prefs.gear && M.client.prefs.gear.len))
		for(var/gear in M.client.prefs.gear)
			var/datum/gear/G = GLOB.gear_datums[gear]
			if(G)
				var/permitted = FALSE

				if(G.allowed_roles && H.mind && (H.mind.assigned_role in G.allowed_roles))
					permitted = TRUE
				else if(!G.allowed_roles)
					permitted = TRUE
				else
					permitted = FALSE

				if(G.whitelisted && G.whitelisted != human.dna.species.name)
					permitted = FALSE

				if(!permitted)
					to_chat(M, "<span class='warning'>Your current job or whitelist status does not permit you to spawn with [gear]!</span>")
					continue

				if(G.slot)
					if(H.equip_to_slot_or_del(G.spawn_item(H), G.slot))
						to_chat(M, "<span class='notice'>Equipping you with [gear]!</span>")
					else
						gear_leftovers += G
				else
					gear_leftovers += G

	if(gear_leftovers.len)
		for(var/datum/gear/G in gear_leftovers)
			var/metadata = M.client.prefs.gear[G.display_name]
			var/item = G.spawn_item(null, metadata)
			var/atom/placed_in = human.equip_or_collect(item)

			if(istype(placed_in))
				if(isturf(placed_in))
					to_chat(M, "<span class='notice'>Placing [G.display_name] on [placed_in]!</span>")
				else
					to_chat(M, "<span class='noticed'>Placing [G.display_name] in [placed_in.name]]")
				continue

			if(H.equip_to_appropriate_slot(item))
				to_chat(M, "<span class='notice'>Placing [G.display_name] in your inventory!</span>")
				continue
			if(H.put_in_hands(item))
				to_chat(M, "<span class='notice'>Placing [G.display_name] in your hands!</span>")
				continue

			var/obj/item/storage/B = locate() in H
			if(B)
				G.spawn_item(B, metadata)
				to_chat(M, "<span class='notice'>Placing [G.display_name] in [B.name]!</span>")
				continue

			to_chat(M, "<span class='danger'>Failed to locate a storage object on your mob, either you spawned with no hands free and no backpack or this is a bug.</span>")
			qdel(item)

		qdel(gear_leftovers)


/datum/job/proc/announce(mob/living/carbon/human/H)
	if(head_announce)
		announce_head(H, head_announce)


//Don't override this unless the job transforms into a non-human (Silicons do this for example)
/datum/job/proc/equip(mob/living/carbon/human/H, visualsOnly = FALSE, announce = TRUE)
	if(!H)
		return 0

	//Equip the rest of the gear
	H.dna.species.before_equip_job(src, H, visualsOnly)

	if(outfit)
		H.equipOutfit(outfit, visualsOnly)

	H.dna.species.after_equip_job(src, H, visualsOnly)

	if(!visualsOnly && announce)
		announce(H)

	if(CONFIG_GET(flag/enforce_human_authority) && (title in GLOB.command_positions))
		H.dna.features["tail_human"] = "None"
		H.dna.features["ears"] = "None"
		H.regenerate_icons()

/datum/job/proc/get_access()
	if(!config)	//Needed for robots.
		return src.minimal_access.Copy()

	. = list()

	if(CONFIG_GET(flag/jobs_have_minimal_access))
		. = src.minimal_access.Copy()
	else
		. = src.access.Copy()

	if(CONFIG_GET(flag/everyone_has_maint_access)) //Config has global maint access set
		. |= list(ACCESS_MAINT_TUNNELS)

/datum/job/proc/announce_head(var/mob/living/carbon/human/H, var/channels) //tells the given channel that the given mob is the new department head. See communications.dm for valid channels.
	if(H && GLOB.announcement_systems.len)
		//timer because these should come after the captain announcement
		SSticker.OnRoundstart(CALLBACK(GLOBAL_PROC, .proc/addtimer, CALLBACK(pick(GLOB.announcement_systems), /obj/machinery/announcement_system/proc/announce, "NEWHEAD", H.real_name, H.job, channels), 1))

//If the configuration option is set to require players to be logged as old enough to play certain jobs, then this proc checks that they are, otherwise it just returns 1
/datum/job/proc/player_old_enough(client/C)
	if(available_in_days(C) == 0)
		return 1	//Available in 0 days = available right now = player is old enough to play.
	return 0


/datum/job/proc/available_in_days(client/C)
	if(!C)
		return 0
	if(!CONFIG_GET(flag/use_age_restriction_for_jobs))
		return 0
	if(!isnum(C.player_age))
		return 0 //This is only a number if the db connection is established, otherwise it is text: "Requires database", meaning these restrictions cannot be enforced
	if(!isnum(minimal_player_age))
		return 0

	return max(0, minimal_player_age - C.player_age)

/datum/job/proc/config_check()
	return 1

/datum/job/proc/map_check()
	return TRUE


/datum/outfit/job
	name = "Standard Gear"

	var/jobtype = null

	uniform = /obj/item/clothing/under/color/grey
	id = /obj/item/card/id
	ears = /obj/item/device/radio/headset
	pda_slot = /obj/item/device/pda
	back = /obj/item/storage/backpack
	shoes = /obj/item/clothing/shoes/sneakers/black

	var/backpack = /obj/item/storage/backpack
	var/satchel  = /obj/item/storage/backpack/satchel
	var/duffelbag = /obj/item/storage/backpack/duffelbag
	var/courierbag = /obj/item/storage/backpack/messenger
	var/box = /obj/item/storage/box/survival

/datum/outfit/job/pre_equip(mob/living/carbon/human/H, visualsOnly = FALSE)
	switch(H.backbag)
		if(GBACKPACK)
			back = /obj/item/storage/backpack //Grey backpack
		if(GSATCHEL)
			back = /obj/item/storage/backpack/satchel //Grey satchel
		if(GDUFFELBAG)
			back = /obj/item/storage/backpack/duffelbag //Grey Duffel bag
		if(LSATCHEL)
			back = /obj/item/storage/backpack/satchel/leather //Leather Satchel
		if(GCOURIERBAG)
			back = /obj/item/storage/backpack/satchel
		if(DSATCHEL)
			back = satchel //Department satchel
		if(DDUFFELBAG)
			back = duffelbag //Department duffel bag
		if(DCOURIERBAG) //Department courier bag
			back = courierbag
		else
			back = backpack //Department backpack

	if(box)
		if(!backpack_contents)
			backpack_contents = list()
		backpack_contents.Insert(1, box) // Box always takes a first slot in backpack
		backpack_contents[box] = 1

/datum/outfit/job/post_equip(mob/living/carbon/human/H, visualsOnly = FALSE)
	if(visualsOnly)
		return

	var/datum/job/J = SSjob.GetJobType(jobtype)
	if(!J)
		J = SSjob.GetJob(H.job)

	var/obj/item/card/id/C = H.wear_id
	if(istype(C))
		C.access = J.get_access()
		C.registered_name = H.real_name
		C.assignment = J.title
		C.update_label()
		H.sec_hud_set_ID()

	var/obj/item/device/pda/PDA = H.wear_pda
	if(istype(PDA))
		PDA.owner = H.real_name
		PDA.ownjob = J.title
		PDA.update_label()
