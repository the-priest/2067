extends UIPanel
## How to hunt.


func panel_title() -> String:
	return "FIELD GUIDE"


func build() -> void:
	var v := scroll()
	var lines := [
		["CONTROLS", ""],
		["WASD move · Shift sprint · Ctrl/Z crouch · Space jump", ""],
		["Right mouse aim / scope · Left mouse fire · R reload · Wheel zoom (variable scopes)", ""],
		["Shift while scoped: hold your breath and steady the crosshair", ""],
		["B binoculars · 1-6 guns · E use / hold to harvest · F flashlight", ""],
		["M map · J journal · F1 this guide · Esc pause", ""],
		["Gear when you own it: Q caller · V scent mask · C phase cloak · G drone · T thermal (scoped)", ""],
		["HUNTING", ""],
		["Every hybrid's heart is in a different place. Hit it and the animal runs a few seconds and drops: a clean kill, a whole hide, double XP for one shot.", "t"],
		["Lungs: it runs far and bleeds hard. Gut: a long slow trail. Follow the blood; hybrid blood glows, and with the Bio-Tracker it shines.", "t"],
		["Brain or spine drops it where it stands. Plasma kills anything but cooks the hide.", "t"],
		["They see movement, hear footsteps (crouch!) and smell you when the wind blows from you to them. The wind gauge shows which way it blows.", "t"],
		["Hold E over a carcass to take the hide and the horns. Your pack only holds so much: sell or mount at the trade radio on your porch.", "t"],
		["Tuskmaws charge. Crownelk charge at night. Howler packs hunt you after dark. The Ironcrown...", "t"],
		["GETTING BETTER", ""],
		["Kills, contracts and mounted trophies raise your rank. Rank unlocks the Exchange's better guns and Xhuul gear: heart scanners, thermal optics, a phase cloak, a recon drone, the coil rifle, the plasma lance and the rail gun.", "t"],
		["Salvage the crashed escape pods around the valley for scrip once a day. Sleep in your bed to save.", "t"],
	]
	for l in lines:
		if l[1] == "":
			v.add_child(UIStyle.label(l[0], 20 if l[0] == l[0].to_upper() else 17, UIStyle.RUST if l[0] == l[0].to_upper() else UIStyle.BONE, UIStyle.title() if l[0] == l[0].to_upper() else UIStyle.body()))
		else:
			var lb := UIStyle.label(l[0], 16, UIStyle.BONE, UIStyle.body())
			lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lb.custom_minimum_size = Vector2(900, 0)
			v.add_child(lb)
