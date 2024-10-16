# SM-NT-Bhop-Mode
Sourcemod plugin for Neotokyo that adds a bhop test mode  

**Experimental** Bhop game mode for neotokyo:  
- Go (bhop!?) from one trigger to the other to get a print of your time, compete with other players to be faster!
- Use the command `!topscores` to get a print in console of the current class records for the current server, `0.0` if no record is set.
- Use the command `!myscores` to get your scores in console.
- Use `kill` or `retry` in console to change class, as the map should be in warmup mode.
- If you have a bad start, you can hop back over the start line, which resets your time and gives you full aux. Times only count from when the plugin prints "start hopping".
- Health dropping to 50 is a sign that your time is being recorded.

**Instructions for Server Operators:**  
- Add plugin and _bhop maps to the server, whenever they are voted the plugin should activate otherwise it does nothing
- Might be incompatible with some plugins, unknown which at the moment, but unlikely.
 
**Instructions for Mappers:**  

**For normal course (Players bhop from start to finish, in one direction):**  
- Create two `trigger_multiple` entities on a map set to `ctg`, between which the players will race, each trigger should be at least 32 units depth.
- Call the triggers: `bhop_trigger_start` and `bhop_trigger_finish`, players will only be able to complete the course from start to finish triggers.
- Add a third `trigger_multiple` (one entity but two seperate brushes), called `bhop_trigger_bhoparea` touching the other two triggers on the **inside** of the course (where players race), make sure the trigger is essentially the same shape and height as the starting line triggers, the depth should be 64 units (to be on the safe side). To make this trigger easier, duplicate both the other triggers and move them towards the inside of the course, then increase their depth if neccessary, usually the starting triggers will be 32 units deep.
- Add one more `trigger_multiple` (one entity but two seperate brushes), called `bhop_trigger_startarea` touching the other two triggers on the **outside** of the course (where players **don't** race), make sure the trigger is essentially the same shape and height as the starting line triggers, the depth should be 64 units (to be on the safe side). To make this trigger easier, duplicate both the other triggers and move them towards the inside of the course, then increase their depth if neccessary, usually the starting triggers will be 32 units deep.
- Include `_bhop` in the map name.  
      
**For circular course (Start and finish line are the same):**    
- Create one `trigger_multiple` entity on a map set to `ctg`, should be at least 32 units depth.
- Call the trigger: `bhop_trigger_one, players will race around in one direction in a circular manner.
- Add a second `trigger_multiple`, called `bhop_trigger_bhoparea` touching the start trigger, make sure the trigger is essentially the same shape and height as the starting line triggers, the depth should be 64 units (to be on the safe side). To make this trigger easier, duplicate the start trigger and then increase their depth if neccessary, usually the starting triggers will be 32 units deep.
- Add one more `trigger_multiple` called `bhop_trigger_startarea` touching the start trigger, make sure the trigger is essentially the same shape and height as the starting trigger, the depth should be 64 units (to be on the safe side). Players will race in the direction of the startarea to the bhoparea.
- Include `_bhop` in the map name.
