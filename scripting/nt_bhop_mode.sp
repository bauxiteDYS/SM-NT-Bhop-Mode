#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

static char g_className[][] = {
	"Unknown",
	"Recon",
	"Assault",
	"Support"
};

Database hDB;
ConVar g_cvarTeamBalance;
static char g_mapName[32];
float g_topScore[3+1]; // retrieve from database maybe or leave as session only
float g_allTimes[NEO_MAXPLAYERS+1][3+1];
float g_time[NEO_MAXPLAYERS+1];
float g_newTime[NEO_MAXPLAYERS+1];
float g_oldTime[NEO_MAXPLAYERS+1];
float g_spawnOrigin[NEO_MAXPLAYERS+1][3];
bool g_touchedStart[NEO_MAXPLAYERS+1];
bool g_touchedFinish[NEO_MAXPLAYERS+1];
bool g_inBhopArea[NEO_MAXPLAYERS+1];
bool g_inStartArea[NEO_MAXPLAYERS+1];
bool g_hopping[NEO_MAXPLAYERS+1];
bool g_bhopMap;
bool g_circularCourse;
bool g_lateLoad;
int g_triggerOne;
int g_triggerStart;
int g_triggerFinish;
int g_triggerBhopArea;
int g_triggerStartArea;

int FindEntityByTargetname(const char[] classname, const char[] targetname)
{
	int ent = -1;
	char buffer[64];
	
	while ((ent = FindEntityByClassname(ent, classname)) != -1)
	{
		GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));

		if (StrEqual(buffer, targetname))
		{
			return ent;
		}
	}

	return -1;
}

public Plugin myinfo = {
	name = "Bhop Game Mode",
	description = "Test how fast you can bhop, and compete with others!",
	author = "bauxite",
	version = "0.5.3",
	url = "https://github.com/bauxiteDYS/SM-NT-Bhop-Mode",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	if(g_lateLoad)
	{
		OnMapInit();
		// doesn't seem like you need to also call mapstart or cfgs, as they are called again on plugin load
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}

public void OnMapInit()
{
	static bool hooked;
	GetCurrentMap(g_mapName, sizeof(g_mapName));
	
	if(StrContains(g_mapName, "_bhop", false) != -1)
	{
		g_bhopMap = true;
	}
	else
	{
		g_bhopMap = false;
		
		if(hooked)
		{
			UnhookEvent("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post);
			UnhookEvent("player_death", Event_PlayerDeathPost, EventHookMode_Post);
			UnhookEvent("game_round_start", Event_RoundStartPost, EventHookMode_Post);
			RemoveCommandListener(OnTeam, "jointeam");
			hooked = false;
		}
	}
	
	if(!g_bhopMap)
	{
		return;
	}
	
	if(hooked)
	{
		return;
	}
	
	if(!HookEventEx("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post))
	{
		SetFailState("[BHOP] Error: Failed to hook");
	}
	
	if(!HookEventEx("player_death", Event_PlayerDeathPost, EventHookMode_Post))
	{
		SetFailState("[BHOP] Error: Failed to hook");
	}
	
	if(!HookEventEx("game_round_start", Event_RoundStartPost, EventHookMode_Post))
	{
		SetFailState("[BHOP] Error: Failed to hook");
	}
	
	if(!AddCommandListener(OnTeam, "jointeam"))
	{
		SetFailState("[BHOP] Error: Failed to hook");
	}
	
	RegConsoleCmd("sm_myscores", Cmd_ClientScores);
	RegConsoleCmd("sm_topscores", Cmd_TopScores);
	RegConsoleCmd("sm_reset", Cmd_Reset);
	
	hooked = true;
}

public void OnMapStart()
{
	if(!g_bhopMap)
	{
		return;
	}
	
	HookTriggers();
	
	for(int client = 1; client <= MaxClients; client++)
	{
		FullResetClient(client);
		g_inBhopArea[client] = false;
	}
	
	StoreToAddress(view_as<Address>(0x2245552c), 0, NumberType_Int8);
}

public void OnConfigsExecuted()
{
	if(!g_bhopMap)
	{
		return;
	}
	
	g_cvarTeamBalance = FindConVar("neottb_enable");
	if(g_cvarTeamBalance != null)
	{
		g_cvarTeamBalance.SetInt(0);
		PrintToServer("[BHOP] Disabling team balancing");
	}
	else
	{
		PrintToServer("[BHOP] Team balancer plugin not found");
	}
	
	DB_init();
}

public void OnMapEnd()
{
	if(!g_bhopMap)
	{
		return;
	}
	
	for(int i = 0; i <= 3; i++)
	{
		g_topScore[i] = 0.0;
		
		for(int c = 0; c <= NEO_MAXPLAYERS; c++)
		{
			g_allTimes[c][i] = 0.0;
		}
	}
	
	StoreToAddress(view_as<Address>(0x2245552c), '-', NumberType_Int8);
}

public Action Cmd_Reset(int client, int args)
{
	if(!g_bhopMap)
	{
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(client) || client <= 0 || client > MaxClients || args > 0)
	{
		return Plugin_Handled;
	}
	
	TeleportMe(client);
	
	int class = GetPlayerClass(client);
	ResetClient(client, class);
	
	return Plugin_Handled;
}

//spawn at player_info or something if lateload or failed to get spawn somehow
// delay teleport by 0.1s?
void TeleportMe(int client) 
{
	static float noSpeed[] = {0.0, 0.0, 0.0};
	TeleportEntity(client, g_spawnOrigin[client], NULL_VECTOR, noSpeed);
}

public Action Cmd_ClientScores(int client, int args)
{
	if(!g_bhopMap)
	{
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(client) || client <= 0 || client > MaxClients || args > 0)
	{
		return Plugin_Handled;
	}

	RequestFrame(DB_retrieveScore, client);
	return Plugin_Handled;
}

public Action Cmd_TopScores(int client, int args)
{
	if(!IsClientInGame(client) || client < 0 || client > MaxClients || args > 0)
	{
		return Plugin_Handled;
	}
	
	RequestFrame(DB_retrieveTopScore);
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if(!g_bhopMap)
	{
		return;
	}
	
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

public void OnClientDisconnect_Post(int client)
{
	if(!g_bhopMap)
	{
		return;
	}
	
	FullResetClient(client);
	
	g_inBhopArea[client] = false;
	
	for(int c = 1; c <= 3; c++)
	{
		g_allTimes[client][c] = 0.0;
	}
}

public Action OnTeam(int client, const char[] command, int argc)
{
	if(argc != 1 || !IsClientInGame(client) || !g_bhopMap)
	{
		return Plugin_Continue;
	}
	
	int iTeam = GetCmdArgInt(1);
	if(iTeam == TEAM_JINRAI || iTeam == TEAM_NONE)
	{
		FakeClientCommandEx(client, "jointeam 3");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void Event_RoundStartPost(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bhopMap)
	{
		return;
	}
	
	HookTriggers();
	
	for(int client = 1; client <= MaxClients; client++)
	{
		FullResetClient(client);
		g_inBhopArea[client] = false;
	}
}

void HookTriggers()
{

	g_triggerBhopArea = FindEntityByTargetname("trigger_multiple", "bhop_trigger_bhoparea");
	g_triggerStartArea = FindEntityByTargetname("trigger_multiple", "bhop_trigger_startarea");
	
	g_triggerOne = FindEntityByTargetname("trigger_multiple", "bhop_trigger_one");
	
	g_triggerStart = FindEntityByTargetname("trigger_multiple", "bhop_trigger_start");
	g_triggerFinish = FindEntityByTargetname("trigger_multiple", "bhop_trigger_finish");
	
	if(g_triggerOne != -1)
	{
		HookSingleEntityOutput(g_triggerOne, "OnStartTouch", Trigger_OnStartTouchOne);
		HookSingleEntityOutput(g_triggerOne, "OnEndTouch", Trigger_OnEndTouchOne);
		g_circularCourse = true;
	}
	else if(g_triggerStart != -1 && g_triggerFinish != -1)
	{
		HookSingleEntityOutput(g_triggerStart, "OnEndTouch", Trigger_OnEndTouchStart);
		HookSingleEntityOutput(g_triggerFinish, "OnEndTouch", Trigger_OnEndTouchFinish);
		g_circularCourse = false;
	}
	else
	{
		PrintToChatAll("[BHOP] Error: Plugin has failed");
		SetFailState("[BHOP] Error: Triggers were not found");
	}
	
	if(g_triggerBhopArea != -1)
	{
		HookSingleEntityOutput(g_triggerBhopArea, "OnStartTouch", Trigger_OnStartTouchBhopArea);
		HookSingleEntityOutput(g_triggerBhopArea, "OnEndTouch", Trigger_OnEndTouchBhopArea);
	}
	else
	{
		PrintToChatAll("[BHOP] Error: Plugin has failed");
		SetFailState("[BHOP] Error: Triggers were not found");
	}
	
	if(g_triggerStartArea != -1)
	{
		HookSingleEntityOutput(g_triggerStartArea, "OnStartTouch", Trigger_OnStartTouchStartArea);
		HookSingleEntityOutput(g_triggerStartArea, "OnEndTouch", Trigger_OnEndTouchStartArea);
	}
	else
	{
		PrintToChatAll("[BHOP] Error: Plugin has failed");
		SetFailState("[BHOP] Error: Triggers were not found");
	}
}

public void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{	
	if(!g_bhopMap)
	{
		return;
	}
	
	int userid = event.GetInt("userid");
	
	RequestFrame(SetupPlayer, userid);
}

void SetupPlayer(int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client == 0 || !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_NSF)
	{
		return;
	}
	
	PrintToChat(client, "[BHOP] This is a bhop map, your timings will be calculated from one line to the other");
	PrintToChat(client, "[BHOP] If you touch the same line twice from outside the bhop area you are reset");
	PrintToChat(client, "[BHOP] Commands: !topscores, !myscores, !reset");
	
	SetEntityFlags(client, GetEntityFlags(client) | FL_GODMODE);
	
	g_inBhopArea[client] = false;
	
	GetClientAbsOrigin(client, g_spawnOrigin[client]);
	
	CreateTimer(1.0, StripWeps, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action StripWeps(Handle timer, int userid) // GIVE knives to non-sup
{
	int client = GetClientOfUserId(userid);
	
	if(client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	int wep;
	int pistol;
	
	pistol = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", 1);
	
	if(pistol > 0 && IsValidEdict(pistol))
	{
		int owner = GetEntPropEnt(pistol, Prop_Data, "m_hOwnerEntity");

		if (client == owner)
		{
			SetEntProp(pistol, Prop_Send, "bAimed", false);
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", pistol);
		}
	}
	
	for(int i = 0; i <= 4; i++)
	{
		if(i == 1)
		{
			continue;
		}
		
		wep = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		
		if(wep > 0 && IsValidEdict(wep))
		{
			RemovePlayerItem(client, wep);
			RemoveEdict(wep);
		}
	}
	
	return Plugin_Stop;
}

public void Event_PlayerDeathPost(Event event, const char[] name, bool dontBroadcast)
{	
	if(!g_bhopMap)
	{
		return;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client <= 0 || client > MaxClients)
	{
		return;
	}
	
	FullResetClient(client);
	g_inBhopArea[client] = false;
}

public Action OnWeaponDrop(int client, int weapon)
{
	if(!g_bhopMap)
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

void Trigger_OnStartTouchBhopArea(const char[] output, int caller, int activator, float delay)
{
	g_inBhopArea[activator] = true;
}

void Trigger_OnEndTouchBhopArea(const char[] output, int caller, int activator, float delay)
{
	g_inBhopArea[activator] = false;
}

void Trigger_OnStartTouchStartArea(const char[] output, int caller, int activator, float delay)
{
	g_inStartArea[activator] = true;
}

void Trigger_OnEndTouchStartArea(const char[] output, int caller, int activator, float delay)
{
	g_inStartArea[activator] = false;
}

void Trigger_OnStartTouchOne(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		FullResetClient(activator);
	}
	
	if(g_hopping[activator] && g_inBhopArea[activator])
	{
		ResetClient(activator, class);
		return;
	}
	
	if(g_hopping[activator] && g_inStartArea[activator])
	{
		CheckTime(activator, class);
		return;
	}
}

void Trigger_OnEndTouchOne(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		FullResetClient(activator);
	}

	if(!g_hopping[activator] && g_inBhopArea[activator])
	{
		StartHop(activator);
		return;
	}
}

void Trigger_OnEndTouchStart(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		FullResetClient(activator);
	}
	
	if(!g_touchedStart[activator] && !g_touchedFinish[activator] && g_inBhopArea[activator])
	{
		g_touchedStart[activator] = true;
		StartHop(activator);
		return;
	}
	else if(g_touchedFinish[activator])
	{
		PrintToChat(activator, "[BHOP] Error: Something went wrong");
		return;
	}
	
	if (g_touchedStart[activator] && g_inStartArea[activator])
	{
		ResetClient(activator, class);
		return;
	}
}

void Trigger_OnEndTouchFinish(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		FullResetClient(activator);
	}
	
	g_touchedFinish[activator] = true;
	
	if(!g_touchedStart[activator])
	{
		ResetClient(activator, class);
		PrintToChat(activator, "[BHOP] Start your bhop from the start line!");
		return;
	}
	else if(g_touchedStart[activator])
	{
		CheckTime(activator, class);
	}	
}

void StartHop(int client)
{
	g_hopping[client] = true;
	g_oldTime[client] = GetGameTime();
	
	SetEntityHealth(client, 50);
	
	if(g_circularCourse)
	{
		PrintToChat(client, "[BHOP] Start hopping!");
		PrintCenterText(client, "Go! Go! Go!");
	}
	else
	{
		PrintToChat(client, "[BHOP] Start hopping to the finish line!");
		PrintCenterText(client, "Go! Go! Go!");
	}
}

void CheckTime(int client, int class)
{
	g_newTime[client] = GetGameTime();
	g_time[client] = g_newTime[client] - g_oldTime[client];
	PrintToChat(client, "[BHOP] Your time: %f", g_time[client]);
	ResetClient(client, class);
	if(g_time[client] < g_topScore[class] || g_topScore[class] == 0.0) //use floatcompare?
	{
		g_topScore[class] = g_time[client];
		PrintToChatAll("[BHOP] New %s record this session by %N!: %f", g_className[class], client, g_time[client]);
		PrintToConsoleAll("[BHOP] New %s record this session by %N!: %f", g_className[class], client, g_time[client]);
	}
	if(g_time[client] < g_allTimes[client][class] || g_allTimes[client][class] == 0.0)
	{
		g_allTimes[client][class] = g_time[client];
		DB_insertScore(client, class);
		PrintToChat(client,"[BHOP] You got your best time for the current session yet on %s", g_className[class]);
	}
}

// need to look at how resets are handled, and maybe make it simpler / better
// don't teleport for circular map

void ResetClient(int client, int class, bool same=false)
{
	g_hopping[client] = false;
	
	if(!g_circularCourse)
	{
		g_touchedStart[client] = false;
		g_touchedFinish[client] = false;
	}
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetEntityHealth(client, 100);
		
		if(!g_circularCourse)
		{
			TeleportMe(client);
		}
	}
	
	if(IsClientInGame(client) && class != CLASS_SUPPORT)
	{
		SetPlayerAUX(client, 100.0);
	}
	
	if(same)
	{
		PrintToChat(client, "[BHOP] You touched the same line twice, you have been reset!");
	}
	else
	{
		PrintToChat(client, "[BHOP] You have been reset");
	}
}

void FullResetClient(int client)
{
	g_time[client] = 0.0;
	g_newTime[client] = 0.0;
	g_oldTime[client] = 0.0;
	g_hopping[client] = false;
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetEntityHealth(client, 100);
		
		if(!g_circularCourse)
		{
			TeleportMe(client);
		}
	}
	
	if(!g_circularCourse)
	{
		g_touchedStart[client] = false;
		g_touchedFinish[client] = false;
	}
}

void DB_init()
{
	char error[255];
	hDB = SQLite_UseDatabase("nt_bhop_plugin_database", error, sizeof(error));

	if(hDB == INVALID_HANDLE)
	{
		SetFailState("[BHOP] SQL error: %s", error);
	}
	
	Transaction txn;
	txn = SQL_CreateTransaction();
	
	char query[512];
	
	hDB.Format(query, sizeof(query), 
	"\
	CREATE TABLE IF NOT EXISTS nt_bhop_scores \
	(\
	steamID	TEXT NOT NULL, \
	mapName	TEXT NOT NULL, \
	reconTime REAL NOT NULL DEFAULT 0.0, \
	assaultTime REAL NOT NULL DEFAULT 0.0, \
	supportTime REAL NOT NULL DEFAULT 0.0, \
	PRIMARY KEY(steamID, mapName) \
	);\
	");
	
	hDB.Query(DB_fast_callback, "VACUUM", _, DBPrio_High);
	
	txn.AddQuery(query);
	
	hDB.Execute(txn, TxnSuccess_Init, TxnFailure_Init);
}

void TxnSuccess_Init(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    PrintToServer("[BHOP] SQL Database init succesful");
}

void TxnFailure_Init(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    SetFailState("[BHOP] SQL Error Database init failure: [%d] %s", failIndex, error);
}

void DB_insertScore(int client, int class) // only insert 1 record at a time perhaps
{	
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char steamID[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

	float reconTime = g_allTimes[client][CLASS_RECON];
	float assaultTime = g_allTimes[client][CLASS_ASSAULT];
	float supportTime = g_allTimes[client][CLASS_SUPPORT];
	
	char query[1664];
	
	hDB.Format(query, sizeof(query), 
	"\
	INSERT INTO nt_bhop_scores(steamID, mapName, reconTime, assaultTime, supportTime) \
	VALUES ('%s', '%s', %f, %f, %f) \
	ON CONFLICT(steamID, mapName) \
	DO UPDATE SET \
	reconTime = CASE \
	WHEN excluded.reconTime > 0.0 AND (nt_bhop_scores.reconTime = 0.0 OR excluded.reconTime < nt_bhop_scores.reconTime) \
	THEN excluded.reconTime \
	ELSE nt_bhop_scores.reconTime \
	END,\
	assaultTime = CASE \
	WHEN excluded.assaultTime > 0.0 AND (nt_bhop_scores.assaultTime = 0.0 OR excluded.assaultTime < nt_bhop_scores.assaultTime) \
	THEN excluded.assaultTime \
	ELSE nt_bhop_scores.assaultTime \
	END, \
	supportTime = CASE \
	WHEN excluded.supportTime > 0.0 AND (nt_bhop_scores.supportTime = 0.0 OR excluded.supportTime < nt_bhop_scores.supportTime) \
	THEN excluded.supportTime \
	ELSE nt_bhop_scores.supportTime \
	END;\
	",
	steamID, mapName, reconTime, assaultTime, supportTime);
	
	hDB.Query(DB_fast_callback, query, _, DBPrio_Normal);
}

void DB_fast_callback(Database db, DBResultSet results, const char[] error, any data)
{
    if (!db || !results || error[0])
    {
        LogError("[BHOP] SQL Error: %s", error);
        return;
    }
	else
	{
		PrintToServer("[BHOP] Some SQL thing was succesful");
	}
}

void DB_retrieveScore(int client)
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char steamID[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	char query[512];
	
	hDB.Format(query, sizeof(query), 
	"\
	SELECT reconTime, assaultTime, supportTime \
	FROM nt_bhop_scores \
	WHERE steamID = '%s' \
	AND mapName = '%s';\
	",
	steamID, mapName);
	
	int userid = GetClientUserId(client);
	
	hDB.Query(DB_results_callback, query, userid, DBPrio_Normal);
}

void DB_results_callback(Database db, DBResultSet results, const char[] error, int userid)
{
	if (!db || !results || error[0])
	{
		LogError("[BHOP] SQL Error: %s", error);
		return;
	}

	if (SQL_GetRowCount(results) == 0)
	{
		return;
	}
	
	if (!SQL_FetchRow(results))
	{
		return;
	}
	
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || client > MaxClients)
	{
		return;
	}
	
	float reconTime = SQL_FetchFloat(results, 0);
	float assaultTime = SQL_FetchFloat(results, 1);
	float supportTime = SQL_FetchFloat(results, 2);

	PrintToConsole(client, "[BHOP] Your Recon top score for %s: %f", g_mapName, reconTime);
	PrintToConsole(client, "[BHOP] Your Assault top score for %s: %f", g_mapName, assaultTime);
	PrintToConsole(client, "[BHOP] Your Support top score for %s: %f", g_mapName, supportTime);
}

void DB_retrieveTopScore()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char query[1664];
	
	hDB.Format(query, sizeof(query), 
	"\
	SELECT steamID, MIN(reconTime) \
	FROM nt_bhop_scores \
	WHERE mapName = '%s' AND reconTime > 0.0 \
	UNION ALL \
	SELECT steamID, MIN(assaultTime) \
	FROM nt_bhop_scores \
	WHERE mapName = '%s' AND assaultTime > 0.0 \
	UNION ALL \
	SELECT steamID, MIN(supportTime) \
	FROM nt_bhop_scores \
	WHERE mapName = '%s' AND supportTime > 0.0; \
	",
	mapName, mapName, mapName);
	
	hDB.Query(DB_top_callback, query, _, DBPrio_Normal);
}

void DB_top_callback(Database db, DBResultSet results, const char[] error, int userid)
{
	if (!db || !results || error[0])
	{
		LogError("[BHOP] SQL Error: %s", error);
		return;
	}
	
	int rowCount = SQL_GetRowCount(results);
	//PrintToServer("row count %d", rowCount);
	
	if (rowCount == 0)
	{
		return;
	}
	
	if (!SQL_FetchRow(results))
	{
		return;
	}

	char steamID[65];
	float time;
	
	SQL_FetchString(results, 0, steamID, sizeof(steamID));
	time = SQL_FetchFloat(results, 1);
	PrintToConsoleAll("Top Recon: %s Time: %f", steamID, time);
	
	if (!SQL_FetchRow(results))
	{
		return;
	}
	
	SQL_FetchString(results, 0, steamID, sizeof(steamID));
	time = SQL_FetchFloat(results, 1);
	PrintToConsoleAll("Top Assault: %s Time: %f", steamID, time);
	
	if (!SQL_FetchRow(results))
	{
		return;
	}
	
	SQL_FetchString(results, 0, steamID, sizeof(steamID));
	time = SQL_FetchFloat(results, 1);
	PrintToConsoleAll("Top Support: %s Time: %f", steamID, time);
}
