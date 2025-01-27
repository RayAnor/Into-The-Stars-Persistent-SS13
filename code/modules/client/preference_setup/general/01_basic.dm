datum/preferences
	var/real_name						//our character's name
	var/be_random_name = 0				//whether we are a random name every round
	var/gender = MALE					//gender of character (well duh)
	var/age = 30						//age of character
	var/spawnpoint = "Default" 			//where this character will spawn (0-2).
	var/metadata = ""

/datum/category_item/player_setup_item/general/basic
	name = "Basic"
	sort_order = 1

/datum/category_item/player_setup_item/general/basic/load_character(var/savefile/S)
	from_file(S["real_name"],pref.real_name)
	from_file(S["name_is_always_random"],pref.be_random_name)
	from_file(S["gender"],pref.gender)
	from_file(S["age"],pref.age)
	from_file(S["spawnpoint"],pref.spawnpoint)
	from_file(S["OOC_Notes"],pref.metadata)

/datum/category_item/player_setup_item/general/basic/save_character(var/savefile/S)
	to_file(S["real_name"],pref.real_name)
	to_file(S["name_is_always_random"],pref.be_random_name)
	to_file(S["gender"],pref.gender)
	to_file(S["age"],pref.age)
	to_file(S["spawnpoint"],pref.spawnpoint)
	to_file(S["OOC_Notes"],pref.metadata)

/datum/category_item/player_setup_item/general/basic/sanitize_character()
	var/datum/species/S = all_species[pref.species ? pref.species : SPECIES_HUMAN]
	if(!S) S = all_species[SPECIES_HUMAN]
	pref.age                = sanitize_integer(pref.age, S.min_age, S.max_age, initial(pref.age))
	pref.gender             = sanitize_inlist(pref.gender, S.genders, pick(S.genders))
	pref.real_name          = sanitize_name(pref.real_name, pref.species)
	pref.spawnpoint         = sanitize_inlist(pref.spawnpoint, spawntypes(), initial(pref.spawnpoint))
	pref.be_random_name     = 0

/datum/category_item/player_setup_item/general/basic/proc/has_flag(var/datum/species/mob_species, var/flag)
	return mob_species && (mob_species.appearance_flags & flag)

/datum/category_item/player_setup_item/general/basic/content()
	var/datum/species/mob_species = all_species[pref.species]
	. = list()
	. += "* = Required Field<br><br>"
	. += "<b>*Full Name:</b> "
	if(has_flag(mob_species, IS_VATGROWN))
		. += "<a href='?src=\ref[src];random_name=1'>Random Name</A><br>"
	else
		. += "<a href='?src=\ref[src];rename=1'><b>[pref.real_name ? pref.real_name : "Unset*"]</b></a><br>"
//	. += "<a href='?src=\ref[src];always_random_name=1'>Always Random Name: [pref.be_random_name ? "Yes" : "No"]</a>"
	. += "<br>"
	. += "<b>Gender:</b> <a href='?src=\ref[src];gender=1'><b>[gender2text(pref.gender)]</b></a><br>"
	. += "<b>Age:</b> <a href='?src=\ref[src];age=1'>[pref.age]</a><br>"
//	. += "<b>Spawn Point</b>: <a href='?src=\ref[src];spawnpoint=1'>[pref.spawnpoint]</a><br>"
	if(config.allow_Metadata)
		. += "<b>OOC Notes:</b> <a href='?src=\ref[src];metadata=1'> Edit </a><br>"
	. = jointext(.,null)

/datum/category_item/player_setup_item/general/basic/OnTopic(var/href,var/list/href_list, var/mob/user)
	var/datum/species/S = all_species[pref.species]
	if(href_list["rename"])
		var/raw_name = input(user, "Choose your character's name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if(new_name)
				if(Retrieve_Record(new_name))
					to_chat(user, "<span class='warning'>Invalid name. This character already exists.</span>")
					return TOPIC_NOACTION
				pref.real_name = new_name
				return TOPIC_REFRESH
			else
				to_chat(user, "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>")
				return TOPIC_NOACTION

	else if(href_list["random_name"])
		pref.real_name = random_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if(href_list["always_random_name"])
		pref.be_random_name = 0
		return TOPIC_REFRESH

	else if(href_list["gender"])
		var/new_gender = input(user, "Choose your character's gender:", "Character Preference", pref.gender) as null|anything in S.genders
		if(new_gender && CanUseTopic(user))
			pref.gender = new_gender
		if(1)//S & HAS_UNDERWEAR)
			pref.all_underwear.Cut()
			for(var/datum/category_group/underwear/WRC in GLOB.underwear.categories)
				if(WRC.name == "Underwear, top")
					if(pref.gender == FEMALE)
						pref.all_underwear[WRC.name] = "Bra"
					else
						pref.all_underwear[WRC.name] = "None"
					continue
				if(WRC.name == "Underwear, top")
					if(pref.gender == FEMALE)
						pref.all_underwear[WRC.name] = "Panties"
					else
						pref.all_underwear[WRC.name] = "Boxers"
					continue
				if(WRC.name == "Undershirt")
					pref.all_underwear[WRC.name] = "Shirt"
					continue

		return TOPIC_REFRESH_UPDATE_PREVIEW

	else if(href_list["age"])
		var/new_age = input(user, "Choose your character's age:\n([S.min_age]-[S.max_age])", "Character Preference", pref.age) as num
		if(new_age && CanUseTopic(user))
			pref.age = max(min(round(text2num(new_age)), S.max_age), S.min_age)
			return TOPIC_REFRESH

	else if(href_list["spawnpoint"])
		var/list/spawnkeys = list()
		for(var/spawntype in spawntypes())
			spawnkeys += spawntype
		var/choice = input(user, "Where would you like to spawn when late-joining?") as null|anything in spawnkeys
		if(!choice || !spawntypes()[choice] || !CanUseTopic(user))	return TOPIC_NOACTION
		pref.spawnpoint = choice
		return TOPIC_REFRESH

	else if(href_list["metadata"])
		var/new_metadata = sanitize(input(user, "Enter any information you'd like others to see, such as Roleplay-preferences:", "Game Preference" , pref.metadata)) as message|null
		if(new_metadata && CanUseTopic(user))
			pref.metadata = new_metadata
			return TOPIC_REFRESH

	return ..()
