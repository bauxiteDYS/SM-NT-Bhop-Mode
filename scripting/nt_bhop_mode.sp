#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG false

static char g_mapName[64];
static char g_className[][] = {
	"Unknown",
	"Recon",
	"Assault",
	"Support"
};

Database hDB;
ConVar g_cvarTeamBalance;
float g_topScore[3+1]; // retrieve from database maybe or leave as session only
float g_allTimes[NEO_MAXPLAYERS+1][3+1];
float g_time[NEO_MAXPLAYERS+1];
float g_newTime[NEO_MAXPLAYERS+1];
float g_oldTime[NEO_MAXPLAYERS+1];
float g_spawnOrigin[NEO_MAXPLAYERS+1][3];
float g_defenderOrigin[3];
float g_vel[3];
float g_speed;
float g_hopTimer;
bool g_portingClient[NEO_MAXPLAYERS+1];
bool g_touchedStart[NEO_MAXPLAYERS+1];
bool g_touchedFinish[NEO_MAXPLAYERS+1];
bool g_inBhopArea[NEO_MAXPLAYERS+1];
bool g_inStartArea[NEO_MAXPLAYERS+1];
bool g_hopping[NEO_MAXPLAYERS+1];
bool g_bhopMap;
bool g_lateLoad;
bool g_stvRecording;
bool g_strippingWep[NEO_MAXPLAYERS+1];
//bool g_clientRecording[NEO_MAXPLAYERS+1];
int g_triggerOne;
int g_triggerStart;
int g_triggerFinish;
int g_triggerBhopArea;
int g_triggerStartArea;

public Plugin myinfo = {
	name = "Bhop Game Mode",
	description = "Test how fast you can bhop, and compete with others!",
	author = "bauxite",
	version = "0.6.6",
	url = "https://github.com/bauxiteDYS/SM-NT-Bhop-Mode",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	#if DEBUG
	RegConsoleCmd("sm_bhop", DebugBhop);
	#endif
	//hook sv_cheats and airaccel etc
	if(g_lateLoad)
	{
		OnMapInit(); // doesn't seem like you need to also call mapstart or cfgs, as they are called again on plugin load
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}

#if DEBUG
public Action DebugBhop(int client, int args)
{
	for(int c = 1; c <= MaxClients; c++)
	{
		if(IsClientConnected(c) && IsFakeClient(c))
		{
			ChangeClientTeam(c, 3);
		}
	}
	
	GameRules_SetPropFloat("m_fRoundTimeLeft", 59940.00);
	
	return Plugin_Handled;
}
#endif

public void OnClientPutInServer(int client)
{
	if(!g_bhopMap)
	{
		return;
	}
	
	if(IsFakeClient(client))
	{
		return;
	}
	
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	
	//RecordClientDemo(client);
	
	if(!g_stvRecording)
	{
		ToggleSTV();
	}
}

public void OnClientDisconnect_Post(int client)
{
	if(GetClientCount() <= 1 && g_stvRecording)
	{
		ToggleSTV();
	}
	
	ResetClient(client, _, true, true);
	g_strippingWep[client] = false;
	//g_clientRecording[client] = false;
	
	for(int c = 1; c <= 3; c++)
	{
		g_allTimes[client][c] = 0.0;
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
	
	if(!HookEventEx("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post)
	|| !HookEventEx("player_death", Event_PlayerDeathPost, EventHookMode_Post)
	|| !HookEventEx("game_round_start", Event_RoundStartPost, EventHookMode_Post)
	|| !AddCommandListener(OnTeam, "jointeam"))
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
	StoreToAddress(view_as<Address>(0x2245552c), 0, NumberType_Int8); // Thanks rain!
	
	CreateTimer(0.1, SpeedoMeter, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action SpeedoMeter(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!g_hopping[i]) // || !IsClientInGame(i))
		{
			continue;
		}
		
		GetEntPropVector(i, Prop_Data, "m_vecVelocity", g_vel);
		g_speed = SquareRoot(g_vel[0] * g_vel[0] + g_vel[1] * g_vel[1]);
		g_hopTimer = GetGameTime() - g_oldTime[i];
		PrintCenterText(i, "%07.3f s : Timer\n%07.3f u/s : Speed", g_hopTimer, g_speed); 
		// brief flicker every 15s due to the game printing the (now empty) "no players on the other team" message unless round time is changed
	}
	
	return Plugin_Continue;
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
	
	for(int client = 1; client <= MaxClients; client++)
	{
		ResetClient(client, _, true, true);
		//g_clientRecording[client] = false;
	}
	
	StoreToAddress(view_as<Address>(0x2245552c), '-', NumberType_Int8);
	g_stvRecording = false;
}

void ToggleSTV()
{
	if(g_stvRecording)
	{
		ServerCommand("tv_stoprecord");
		g_stvRecording = false;
	}
	else
	{
		char timestamp[16];
		FormatTime(timestamp, sizeof(timestamp), "%Y%m%d-%H%M");
		
		char demoName[PLATFORM_MAX_PATH];
		Format(demoName, sizeof(demoName), "%s_%s", g_mapName, timestamp);
		
		ServerCommand("tv_stoprecord");
		ServerCommand("tv_record \"%s\"", demoName);
		g_stvRecording = true;
	}
}

void RecordClientDemo(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	
	char timestamp[16];
	FormatTime(timestamp, sizeof(timestamp), "%Y%m%d-%H%M");
	
	char demoName[PLATFORM_MAX_PATH];
	Format(demoName, sizeof(demoName), "%s_%s", g_mapName, timestamp);
	
	ClientCommand(client, "stop");
	ClientCommand(client, "record %s", demoName); //is this right
	//g_clientRecording[client] = true;
}

public void OnConfigsExecuted()
{
	static bool BalanceChangeHook;
	
	if(!g_bhopMap)
	{
		if(BalanceChangeHook)
		{
			g_cvarTeamBalance.RemoveChangeHook(CvarChanged_TeamBalance);
			BalanceChangeHook = false;
		}
		
		return;
	}
	
	g_cvarTeamBalance = FindConVar("neottb_enable");
	
	if(g_cvarTeamBalance != null)
	{
		g_cvarTeamBalance.SetInt(0);
		
		if(!BalanceChangeHook)
		{
			g_cvarTeamBalance.AddChangeHook(CvarChanged_TeamBalance);
			BalanceChangeHook = true;
		}
		
		PrintToServer("[BHOP] Disabling team balancing");
	}
	else
	{
		PrintToServer("[BHOP] Team balancer plugin not found");
	}
	
	DB_init();
}

public void CvarChanged_TeamBalance(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(!g_bhopMap)
	{
		return;
	}
	
	if(g_cvarTeamBalance.IntValue != 0)
	{
		g_cvarTeamBalance.SetInt(0);
	}
}

void ResetClient(int client, int class = CLASS_NONE, bool pos = false, bool port = false)
{
	g_hopping[client] = false;
	g_newTime[client] = 0.0;
	g_oldTime[client] = 0.0;
	
	g_touchedStart[client] = false;
	g_touchedFinish[client] = false;
	
	if(pos)
	{
		g_inBhopArea[client] = false;
		g_inStartArea[client] = false;
	}
	
	if(port || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		g_portingClient[client] = false;
		// if port was started then it will reset in the timer, when there is no chance of port happening
		return;
	}
	
	SetEntityHealth(client, 100);
	
	if(class > CLASS_NONE)
	{
		if(class != CLASS_SUPPORT)
		{
			SetPlayerAUX(client, 100.0);
		}
	
		//PrintToChat(client, "[BHOP] You have been reset");
	}
}

void TeleportMe(int client) 
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	if(!g_portingClient[client])
	{
		g_portingClient[client] = true;
		PrintCenterText(client, "Teleporting to spawn");
		int userid = GetClientUserId(client);
		CreateTimer(0.3, TeleportMeTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TeleportMeTimer(Handle timer, int userid)
{
	static float noSpeed[] = {0.0, 0.0, 0.0};
	int client = GetClientOfUserId(userid);
	
	if(client <= 0 || !IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	
	int class = 0;
	
	if(IsPlayerAlive(client))
	{
		if(g_spawnOrigin[client][0] == 0.0 && g_spawnOrigin[client][1] == 0.0 && g_spawnOrigin[client][2] == 0.0)
		{
			AddVectors(g_spawnOrigin[client], g_defenderOrigin, g_spawnOrigin[client]);
		}
		#if DEBUG
		else if(GetVectorDistance(g_spawnOrigin[client], g_defenderOrigin) > 512)
		{ // if you spawn too far away or on the wrong team/side of the map
			g_spawnOrigin[client][0] = g_defenderOrigin[0];
			g_spawnOrigin[client][1] = g_defenderOrigin[1];
			g_spawnOrigin[client][2] = g_defenderOrigin[2];
		}
		#endif
		TeleportEntity(client, g_spawnOrigin[client], NULL_VECTOR, noSpeed);
		class = GetPlayerClass(client);
	}
	
	ResetClient(client, class, true, true);
	
	return Plugin_Stop;
}

public Action Cmd_Reset(int client, int args)
{
	if(!g_bhopMap)
	{
		return Plugin_Handled;
	}
	
	if(client <= 0 || client > MaxClients || args > 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	int class = GetPlayerClass(client);
	ResetClient(client, class, true);
	TeleportMe(client);
	return Plugin_Handled;
}

public Action Cmd_ClientScores(int client, int args)
{
	if(!g_bhopMap)
	{
		return Plugin_Handled;
	}
	
	if(client <= 0 || client > MaxClients || args > 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	RequestFrame(DB_retrieveScore, client);
	PrintToChat(client, "[BHOP] Check console for your scores");
	return Plugin_Handled;
}

public Action Cmd_TopScores(int client, int args)
{
	if(!g_bhopMap)
	{
		return Plugin_Handled;
	}
	
	if(client <= 0 || client > MaxClients || args > 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	RequestFrame(DB_retrieveTopScore);
	PrintToChat(client, "[BHOP] Check console for top scores");
	return Plugin_Handled;
}

public Action OnTeam(int client, const char[] command, int argc)
{
	if(!g_bhopMap)
	{
		return Plugin_Handled;
	}
	
	if(argc != 1 || !IsClientInGame(client))
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
		ResetClient(client, _, true, true);
	}
}

void HookTriggers()
{
	g_triggerBhopArea = FindEntityByTargetname("trigger_multiple", "bhop_trigger_bhoparea");
	g_triggerStartArea = FindEntityByTargetname("trigger_multiple", "bhop_trigger_startarea");
	
	g_triggerOne = FindEntityByTargetname("trigger_multiple", "bhop_trigger_one");
	
	g_triggerStart = FindEntityByTargetname("trigger_multiple", "bhop_trigger_start");
	g_triggerFinish = FindEntityByTargetname("trigger_multiple", "bhop_trigger_finish");
	
	int defenderSpawn = FindEntityByClassname(-1, "info_player_defender");
	
	if(defenderSpawn != -1)
	{
		GetEntPropVector(defenderSpawn, Prop_Data, "m_vecAbsOrigin", g_defenderOrigin);
	}
	else
	{
		SetFailState("[BHOP] Error: Defender spawn not found!!!");
	}
	
	if(g_triggerOne != -1)
	{
		HookSingleEntityOutput(g_triggerOne, "OnStartTouch", Trigger_OnStartTouchOne);
		HookSingleEntityOutput(g_triggerOne, "OnEndTouch", Trigger_OnEndTouchOne);
	}
	else if(g_triggerStart != -1 && g_triggerFinish != -1)
	{
		HookSingleEntityOutput(g_triggerStart, "OnEndTouch", Trigger_OnEndTouchStart);
		HookSingleEntityOutput(g_triggerFinish, "OnEndTouch", Trigger_OnEndTouchFinish);
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
	
	ResetClient(client, _, true, true);
}

public void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{	
	if(!g_bhopMap)
	{
		return;
	}
	
	GameRules_SetPropFloat("m_fRoundTimeLeft", 1199.00); // put this somewhere else?
	
	int userid = event.GetInt("userid");
	
	RequestFrame(SetupPlayer, userid);
}

void SetupPlayer(int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	PrintToChat(client, "[BHOP] This is a bhop map, your timings will be calculated from one line to the other");
	PrintToChat(client, "[BHOP] Commands: !topscores, !myscores, !reset");
	
	SetEntityFlags(client, GetEntityFlags(client) | FL_GODMODE);
	GetClientAbsOrigin(client, g_spawnOrigin[client]);
	
	if(!g_strippingWep[client])
	{
		g_strippingWep[client] = true;
		CreateTimer(0.75, StripWeps, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action StripWeps(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if(client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	StripPlayerWeapons(client, false);
	
	int class = GetPlayerClass(client);
	int wepKnife = GivePlayerItem(client, "weapon_knife"); 
	
	if(wepKnife != -1)
	{
		AcceptEntityInput(wepKnife, "use", client, client);
	}

	if(class == CLASS_RECON)
	{
		GivePlayerItem(client, "weapon_milso");
	}
	else if(class == CLASS_ASSAULT)
	{
		GivePlayerItem(client, "weapon_tachi");
	}
	else if (class == CLASS_SUPPORT)
	{
		GivePlayerItem(client, "weapon_kyla");
	}
	
	g_strippingWep[client] = false;
	return Plugin_Stop;
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
		ResetClient(activator, _, true);
		TeleportMe(activator);
		return;
	}
	
	if(g_hopping[activator] && g_inBhopArea[activator])
	{
		ResetClient(activator, class, true);
		TeleportMe(activator);
		return;
	}
	
	if(g_hopping[activator] && g_inStartArea[activator])
	{
		CheckTime(activator, class, false);
		return;
	}
}

void Trigger_OnEndTouchOne(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		ResetClient(activator,_, true);
		TeleportMe(activator);
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
		ResetClient(activator, _, true);
		TeleportMe(activator);
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
		ResetClient(activator, class, true);
		TeleportMe(activator);
		return;
	}
}

void Trigger_OnEndTouchFinish(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		ResetClient(activator, _, true);
		TeleportMe(activator);
		return;
	}
	
	g_touchedFinish[activator] = true;
	
	if(!g_touchedStart[activator])
	{
		ResetClient(activator, class);
		TeleportMe(activator);
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
	
	PrintToChat(client, "[BHOP] Start hopping!");
	PrintCenterText(client, "Go! Go! Go!");

}

void CheckTime(int client, int class, bool teleport = true)
{
	g_newTime[client] = GetGameTime();
	g_time[client] = g_newTime[client] - g_oldTime[client];
	PrintToChat(client, "[BHOP] Your time: %f", g_time[client]);
	
	ResetClient(client, class, true);
	
	if(teleport)
	{
		TeleportMe(client);
	}
	
	if(g_time[client] < g_topScore[class] || g_topScore[class] == 0.0) //use floatcompare?
	{
		g_topScore[class] = g_time[client];
		PrintToChatAll("[BHOP] New %s record this session by %N!: %f", g_className[class], client, g_time[client]);
		PrintToConsoleAll("[BHOP] New %s record this session by %N!: %f", g_className[class], client, g_time[client]);
	}
	
	if(g_time[client] < g_allTimes[client][class] || g_allTimes[client][class] == 0.0)
	{
		float improvement = g_allTimes[client][class] - g_time[client];
		g_allTimes[client][class] = g_time[client];
		DB_insertScore(client, class);
		PrintToChat(client,"[BHOP] You got your best time for the current session yet on %s", g_className[class]);
		
		if(improvement > 0.0)
		{
			PrintToChat(client,"[BHOP] An improvement of %.3f seconds", improvement);
		}
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
	reconStamp TEXT NOT NULL DEFAULT 0, \
	assaultTime REAL NOT NULL DEFAULT 0.0, \
	assaultStamp TEXT NOT NULL DEFAULT 0, \
	supportTime REAL NOT NULL DEFAULT 0.0, \
	supportStamp TEXT NOT NULL DEFAULT 0, \
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

void DB_insertScore(int client, int class)
{	
	char steamID[32];
	
	if(!GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		PrintToChat(client, "[BHOP] Error getting your SteamID, your time was not saved!");
		PrintToServer("[BHOP] Error getting SteamID during score insert");
		return;
	}
	
	char className[8];
	
	if(class == 1)
	{
		strcopy(className, sizeof(className), "recon");
	}
	else if(class == 2)
	{
		strcopy(className, sizeof(className), "assault");
	}
	else if(class == 3)
	{
		strcopy(className, sizeof(className), "support");
	}
	
	float classTime = g_allTimes[client][class];

	char classStamp[16];
	FormatTime(classStamp, sizeof(classStamp), "%Y%m%d%H%M%S", GetTime());
	
	char query[1360];
	
	char classQuery[] = 	
	"\
	INSERT INTO nt_bhop_scores(steamID, mapName, <class>Time, <class>Stamp) \
	VALUES ('%s', '%s', %f, %s) \
	ON CONFLICT(steamID, mapName) \
	DO UPDATE SET \
	<class>Time = CASE \
	WHEN excluded.<class>Time > 0.0 AND (nt_bhop_scores.<class>Time = 0.0 OR excluded.<class>Time < nt_bhop_scores.<class>Time) \
	THEN excluded.<class>Time \
	ELSE nt_bhop_scores.<class>Time \
	END,\
	<class>Stamp = CASE \
	WHEN excluded.<class>Time > 0.0 AND (nt_bhop_scores.<class>Time = 0.0 OR excluded.<class>Time < nt_bhop_scores.assaultTime) \
	THEN excluded.<class>Stamp \
	ELSE nt_bhop_scores.<class>Stamp \
	END;\
	";
	
	#if DEBUG
	PrintToServer("[BHOP] Debug time: %s", classStamp);
	#endif
	
	ReplaceString(classQuery, sizeof(classQuery), "<class>", className, true);
	
	hDB.Format(query, sizeof(query), classQuery, steamID, g_mapName, classTime, classStamp);
	
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
	char steamID[32];
	
	if(!GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID)))
	{
		PrintToChat(client, "[BHOP] Error getting your SteamID, could not retrieve your score!");
		PrintToServer("[BHOP] Error getting SteamID during score retrieval");
		return;
	}
	
	char query[512];
	
	hDB.Format(query, sizeof(query), 
	"\
	SELECT reconTime, assaultTime, supportTime \
	FROM nt_bhop_scores \
	WHERE steamID = '%s' \
	AND mapName = '%s';\
	",
	steamID, g_mapName);
	
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

	if (SQL_GetRowCount(results) == 0 || !SQL_FetchRow(results))
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
	PrintToConsoleAll("[BHOP] Your best scores for %s:", g_mapName);
	PrintToConsole(client, "[BHOP] Recon: %f", reconTime);
	PrintToConsole(client, "[BHOP] Assault: %f", assaultTime);
	PrintToConsole(client, "[BHOP] Support: %f", supportTime);
}

void DB_retrieveTopScore()
{
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
	g_mapName, g_mapName, g_mapName);
	
	hDB.Query(DB_top_callback, query, _, DBPrio_Normal);
}

void DB_top_callback(Database db, DBResultSet results, const char[] error, int userid)
{
	if (!db || !results || error[0])
	{
		LogError("[BHOP] SQL Error: %s", error);
		return;
	}
	
	int rowCount = SQL_GetRowCount(results); //PrintToServer("row count %d", rowCount);
	
	if(rowCount == 0 || !SQL_FetchRow(results))
	{
		return;
	}
	
	char steamID[65];
	float time;
	
	PrintToConsoleAll("[BHOP] Top scores for %s:", g_mapName);
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
