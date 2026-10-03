class_name Story
extends RefCounted
## Everything people say. The history, the radio, Dale, and Xyla.
##
## 2031: the Xhuul arrive over Las Vegas on a Tuesday, promising cures, cold
## fusion and free Wi-Fi forever, plus a 4,000-page terms of service nobody
## reads. Clause 9,112 says they're allowed to "get to know" Earth's fauna.
## They get to know ALL of it. Within a year every barn, zoo and safari park
## on Earth is a crime scene, and the first hybrids are born.
## 2034: Earl Puckett of Grand Island, Nebraska, live-streams it. Congress
## declares war in eleven minutes, the only thing it ever agreed on.
## Operation Freedom Moo. Three years later, out of everything else, America
## launches the nukes. The Xhuul have shields. Earth doesn't.
## 2037: Earth surrenders. The Xhuul keep it as a nature reserve. For the
## hybrids. 2067: you, your grandpa's farm, Dale, and a planet nobody would
## recognise. The Xhuul pay a fortune for hybrid horns. The ghouls and the
## Burnt want what's left of you. Keep the farm alive.

## The intro, shot by shot: [scene, caption, seconds].
const INTRO := [
	["arrival", "EARTH  ·  2031", 3.0],
	["arrival", "On a Tuesday in 2031, they came.", 4.5],
	["arrival", "Eleven thousand ships. Over Las Vegas, which in fairness was already pretty weird.", 5.5],
	["podium", "They called themselves the Xhuul. They said they came in peace.", 5.0],
	["podium", "They promised cures. Cold fusion. Free Wi-Fi, forever.", 5.0],
	["podium", "And a terms of service four thousand pages long. Nobody read it.", 5.0],
	["farm", "Clause 9,112 gave them the right to \"get to know\" Earth's wildlife.", 5.5],
	["farm", "They didn't come for our science. They came for our cows.", 5.0],
	["farm", "And our pigs. And our deer. And some things at the zoo we don't talk about.", 6.0],
	["farm", "Turns out the most advanced species in the galaxy... were perverts.", 5.5],
	["war", "2034. A farmer in Nebraska live-streamed it.", 4.5],
	["war", "Congress declared war in eleven minutes. The only thing they ever agreed on.", 5.5],
	["war", "OPERATION FREEDOM MOO", 3.5],
	["nukes", "We threw everything we had at them.", 4.0],
	["nukes", "Then we threw the things we'd promised never to throw.", 4.5],
	["nukes", "Their ships had shields. Earth didn't.", 5.0],
	["wasteland", "2037. Earth surrendered. The Xhuul kept the planet. As a nature reserve.", 6.0],
	["wasteland", "For the hybrids.", 3.5],
	["valley", "2067.", 3.0],
	["valley", "Thirty years on, nobody would recognise the place. Ghouls in the ash. Burnt Xhuul in the craters. And the hybrids, everywhere.", 7.0],
	["valley", "The Xhuul pay a fortune for hybrid horns. Don't ask what they do with them.", 5.5],
	["farm2", "You've got your grandpa's farm, your grandpa's rifle, and Dale.", 5.0],
	["farm2", "Hunt. Sell the horns to the people who ended the world. Keep the farm standing.", 6.0],
	["title", "", 5.0],
]

## Commissioner Blorvak Nine-Mouths, of the Xhuul Horn Exchange, on the
## radio: [message, the goal it sets].
const RADIO := [
	["Greetings, small farm human! Commissioner Blorvak Nine-Mouths, Xhuul Horn Exchange, speaking with my business mouth. You hunt hybrids, we buy horns. Hides too, for the upholstery. There are Moorhorns grazing south of your hovel. Do the needful.", "Hunt a Moorhorn in the fields and sell it at your trade radio"],
	["Exquisite! The Exchange is moist with delight. Some advice: the hearts. We, ah, rearranged things. No two hybrids keep the heart in the same place. One clean shot keeps a hide pristine. Now buy a better gun; your grandfather's is embarrassing us both.", "Reach rank 2 and buy the Ranch .308"],
	["The Stagwraiths of the dead forest hear everything. Crouch. Keep the wind in your face. Their antlers grow crystal, and crystal sells. Also, unrelated: your farm. Ghouls are drifting toward it. Probably nothing.", "Take a Stagwraith in the western forest"],
	["You have a reputation now! Tuskmaws in the eastern badlands charge, Tigraths stalk the forest, and the Ursagore... the Ursagore is cranky. Build up the farm. More turrets. The Exchange sells turrets. What a coincidence.", "Reach rank 4"],
	["Ramspires on the northern ridges: the spiral every Xhuul wants over the bed. Don't ask. Also, a person of interest has gone missing from Exchange custody. Tall. Glowing. Insubordinate. If she turns up on your farm, the Exchange would like her back. Or a discount. Whichever.", "Mount a Ramspire spiral on your trophy wall"],
	["Why are more ghouls coming to your farm, you ask? Mmm. Hard to say. Certainly nothing to do with the horns. Keep mounting them! Mount everything! Mammothar out on the fields, Rhinox in the scrub. Lovely, lovely horns.", "Reach rank 6, then go to the crash basin"],
	["The Ironcrown. Two hearts. Horns like a bridge. It walks the crash basin round our old flagship, and the Exchange will pay anything for its crown. Anything, small farm human. Find both hearts.", "Hunt the Ironcrown in the crash basin"],
	["You did it. The Exchange is... moved. Several of my mouths are weeping. Keep hunting. Keep mounting. The ghouls will keep coming; the horns sing to them, you see. Oh, did I not mention? Ha! Good luck with the farm.", "Fill the wall. Every species, every class."],
]

## Dale's lines, by moment. {species}, {dist}, {dir} get filled in.
const DALE := {
	"start": ["Mornin'. Grandpa Joe's rifle still shoots straight, which is more'n I can say for the Xhuul.", "Coffee's chicory and regret. Let's go shoot somethin' with too many eyes."],
	"spot": ["{species}, {dist} metres, {dir}. Ugly as sin.", "There. {species}, {dir}, about {dist}. Easy now.", "Got a {species} {dir}. {dist} metres. Don't spook it.", "Look {dir}. {species}. I'd marry them horns.", "{species}, {dist} out, {dir}. Wind's... somethin'. You figure it."],
	"heart": ["HEART! Right in the ticker, wherever the hell they keep it now!", "Clean as a whistle. Grandpa'd be proud. Then he'd ask what that thing was.", "One shot! That's a pristine hide, partner.", "Dropped like my credit score in '33."],
	"kill": ["Down it goes. Messy, but it counts.", "Well, it ain't movin'. Let's go see what we got.", "That one'll need some stitchin' before we sell the hide."],
	"miss": ["Missed it by a mile. A metric mile.", "You shoot like a Xhuul diplomat. That ain't a compliment.", "Breathe, then squeeze. Breathe, THEN squeeze.", "That round's gonna land in Canada. What's left of it."],
	"wounded": ["It's hit! Follow the blood. Glows like a lava lamp.", "Wounded. Don't let it suffer, it's already had a weird life.", "Blood trail! Them glowy drops, follow 'em."],
	"ghoul": ["GHOUL! Shoot it in the head, it's the only bit still workin'!", "Ghoul at your six! Nope, my six. Everybody's six!", "Here comes Kevin from the old feed store. Sorry, Kevin."],
	"burnt": ["A Burnt! Xhuul soldier left over from the war. Four arms, zero manners.", "Burnt Xhuul! Them glowin' ones hit hard!"],
	"raid": ["Ghouls headin' for the farm! The turrets'll hold... probably!", "Somethin's drawin' 'em to us. I don't like it.", "Raid! Get back to the farm or say goodbye to the barn!"],
	"night": ["Night's when the Howlers come out. Stay close.", "Can't see a thing. Except them eyes. Them eyes I can see."],
	"rank": ["Look at you, gettin' famous with the aliens. Mama'd be confused.", "They're payin' us in Xhuul scrip. It smells like lavender and lies."],
	"idle": ["Did I ever tell you about the moon? It's a hologram. Xhuul put it up in '35.", "My cousin married a Moorhorn. Long story. Short marriage.", "Thirty years since the bombs and I still miss pizza.", "The Xhuul invented free Wi-Fi and then nuked the routers. Classic.", "If you listen real careful you can hear the horns hum at night. Gives me the creeps.", "You know what I'd do with a million scrip? Buy a second pair of pants."],
	"xyla": ["Don't look now, but the alien lady's been starin' at you all mornin'.", "She fixed my truck with a glowin' rock and a kiss on the hood. I got questions.", "Xyla says the ghouls can hear the horns. So that's why my sleep's been garbage."],
	"harvest": ["Careful with them horns, that's our rent.", "Hide's comin' off nice. Smells like a burnt penny.", "Skin it, sell it, buy turrets. The circle of life."],
}

## Xyla, who escaped the Horn Exchange and turned up at your farm. Her
## lines run in order as you talk to her, a little more each day.
const XYLA := [
	"Hello, farmer. I am Xyla. I was an appraiser for the Horn Exchange, until I saw what the horns are for. I need somewhere to hide. Your barn smells like a dying star. I love it.",
	"The horns sing. You cannot hear it, but the ghouls can, and the Burnt. Every horn on your wall calls them closer. Blorvak knows. The Exchange uses hunters like you as bait to clear the wasteland.",
	"I can build you things the Exchange would never sell you. Tesla towers. A shield dome. Look at the workbench in the barn, I have improved it. You are welcome.",
	"On my world we do not have sunsets. Just the eternal purple. This orange... this I could watch with you. For research.",
	"Dale asked me if Xhuul can eat chili. I said yes. I was wrong. Do not let him cook again.",
	"You shot that Ramspire through a heart I helped hide. I should be offended. Instead I am... impressed. Do not tell Dale.",
	"The Ironcrown's two hearts were a mistake in the lab. My mistake. I was very young. Please end it gently.",
	"I am not going back. Whatever Blorvak offers. This farm is the first place in the galaxy that ever felt like mine. Like ours.",
]


static func line(key: String, vars: Dictionary = {}) -> String:
	var opts: Array = DALE.get(key, [""])
	var t: String = opts[randi() % opts.size()]
	for k in vars.keys():
		t = t.replace("{%s}" % k, str(vars[k]))
	return t
