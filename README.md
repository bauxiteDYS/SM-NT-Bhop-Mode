# SM-NT-Bhop-Mode
Sourcemod plugin for Neotokyo that adds a bhop test mode  

**Experimental** Bhop game mode for neotokyo:  
- Go (bhop!?) from one trigger to the other to get a print of your time, compete with other players to be faster!
- Use the command `!topscores` to get a print in console of the current class records for the current server, `0.0` if no record is set.
- Use `kill` or `retry` in console to change class, as the map should be in warmup mode.
- If you have a bad start, you can touch the trigger again where you started, touching the same trigger twice resets your time and gives you full aux. Times only count from when the plugin prints "start hopping".
- Health dropping to 50 is a sign that your time is being recorded.

**Instructions for Server Operators:**  
- Add plugin and _bhop maps to the server, whenever they are voted the plugin should activate otherwise it does nothing
- Might be incompatible with some plugins, unknown which at the moment.
 
**Instructions for Mappers:**
- All you need to create a map for this mode at the moment are two `trigger_multiple` entities on a map set to `ctg`, between which the players will race.
- Call the triggers: `bhop_trigger_one` and `bhop_trigger_two` for symmetrical maps as players can run the course either way and the timing will be the same.
- Call the triggers: `bhop_trigger_start` and `bhop_trigger_finish` for asymmeterical maps, players will only be able to complete the course from start to finish triggers, perhaps implement teleports so they can reach the start quickly again.
- Add a third `trigger_multiple` (one entity but two seperate brushes), called `bhop_trigger_bhoparea` touching the other two triggers on the **inside** of the course (where players race), make sure the trigger is essentially the same shape and height as the starting line triggers, the depth should be 64 units (to be on the safe side). To make this trigger easier, duplicate both the other triggers and move them towards the inside of the course, then increase their depth if neccessary, usually the starting triggers will be 32 units deep.
- Include `_bhop` in the map name.

