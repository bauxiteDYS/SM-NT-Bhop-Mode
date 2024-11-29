# SM-NT-Bhop-Mode
Sourcemod plugin for Neotokyo that adds a bhop competition/test/training mode. It's meant to allow players to get a time from start to finish of a particular course, this could be for testing purposes, for competing with other players or for practicing bhopping, the settings are meant to be the same as a standard competitive game so that any movements can be replicated in real gameplay.  

**Bhop game mode for neotokyo:**  
- Go (bhop!?) from one trigger to the other to get a print of your time, compete with other players to be faster!

**Commands:**  
- `!topscores` to get a print in console of the current best all-time class records for the current server, and the top scores for that session, `0.0` if no record is set. All-time scores give a steamid, whereas top session scores give the name of the client as it was when they achieved that score.
- `!myscores` to get your scores in console, `0.0` if no record is set.
- `!reset` to teleport back to spawn and reset your hop, can be used at any time.
- `!setspawn` to set a new location for your reset teleport, just move to any location that is on the ground and not close to / in the start/finish lines and while not hopping and use the command.
- `kill`, `retry` (in console) or switch to spectator and back (!s, !n) to change class, as the map should be in warmup mode.
- 
**Info:**  
- If you have a bad start, you can hop back over the start line or use `sm_reset` (you can bind it to a key), which resets your time and gives you full aux. Times only count from when the plugin prints the "Timer" countdown in the center of the screen.
- Health dropping to 50 is a sign that your time is being recorded, in addition to a timer and speedometer appearing in the centre of your screen.  

**Instructions for Server Operators:**  
- Add plugin and _bhop maps to the server, whenever they are voted the plugin should activate otherwise it does nothing
- Might be incompatible with some plugins, unknown which at the moment, but unlikely.
- Latest maps included in `compiled_maps` folder.
- Records demos (if STV is enabled) to the game directory (cvars and customisation to come later).
 
**Instructions for Mappers:**  
- Add `info_player_defender` entities where you want the players to spawn, they can only play on NSF so 32 defender spawns will be needed, just in case the server is completely full, although it isn't recommended to play this mode at such high player counts.
- Example maps for both types of trigger setup included in the `map_vmfs` folder.

**For normal course (Players bhop from start to finish, in one direction):**  
- Create two `trigger_multiple` entities on a map set to `ctg`, between which the players will race, each trigger should be 32 units depth.
- Call the triggers: `bhop_trigger_start` and `bhop_trigger_finish`, players will only be able to complete the course from start to finish triggers.
- Add a third `trigger_multiple` (one entity but two seperate brushes), called `bhop_trigger_bhoparea` touching the other two triggers on the **inside** of the course (where players race), make sure the trigger is essentially the same shape and height as the starting line triggers, the depth should be 64 units (to be on the safe side). To make this trigger easier, duplicate both the other triggers and move them towards the inside of the course, then increase their depth if neccessary, the starting triggers will be 32 units deep.
- Add one more `trigger_multiple` (one entity but two seperate brushes), called `bhop_trigger_startarea` touching the other two triggers on the **outside** of the course (where players **don't** race), make sure the trigger is essentially the same shape and height as the starting line triggers, the depth should be 64 units (to be on the safe side). To make this trigger easier, duplicate both the other triggers and move them towards the inside of the course, then double their depth, the starting triggers will be 32 units deep.
- Include `_bhop` in the map name.  
      
**For circular course (Start and finish line are the same):**    
- Create one `trigger_multiple` entity on a map set to `ctg`, should be 32 units depth.
- Call the trigger: `bhop_trigger_one`, players will race around in one direction in a circular manner.
- Add a second `trigger_multiple`, called `bhop_trigger_bhoparea` touching the start trigger, make sure the trigger is essentially the same shape and height as the starting line triggers, the depth should be 64 units (to be on the safe side). To make this trigger easier, duplicate the start trigger and then increase their depth if neccessary, usually the starting triggers will be 32 units deep.
- Add one more `trigger_multiple` called `bhop_trigger_startarea` touching the start trigger, make sure the trigger is essentially the same shape and height as the starting trigger, the depth should be 64 units. Players will race in the direction of the startarea to the bhoparea.
- Include `_bhop` in the map name.
