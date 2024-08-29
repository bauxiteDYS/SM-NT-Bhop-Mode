# SM-NT-Bhop-Mode
Sourcemod plugin for Neotokyo that adds a bhop test mode  

**Experimental** Bhop game mode for neotokyo:  
- Join NSF team.
- Go (bhop!?) from one trigger to the other to get a print of your time, compete with other players to be faster!
- Use the command `!bhoprecords` to get a print in console of the current class records, `0.0` if no record is set. Records are wiped on server restart or plugin unload.
- Use `kill` or `retry` in console to change class, as the map should be in warmup mode.
- Remember to change weapons to pistol or knife for speed, as you should not be able to drop your weapons.
- If you have a bad start, you can touch the trigger again where you started, touching the same trigger twice resets your time and gives you full aux. Times only count from when the plugin prints "start hopping".

**Instructions for Server Operators:**  
- Bhop plugin does not play nicely with the autobalance plugin yet, or perhaps other unknown plugins, otherwise it should be fine to use with any compatible map. 
 
**Instructions for Mappers:**
- All you need to create a map for this mode at the moment are two `trigger_multiple` entities on a map set to `ctg`, between which the players will race.
- Call the triggers: `bhop_trigger_one` and `bhop_trigger_two`.
- Include `_bhop` in the map name.

