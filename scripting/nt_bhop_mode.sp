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

float g_topScore[3+1];
float g_time[NEO_MAXPLAYERS+1];
float g_newTime[NEO_MAXPLAYERS+1];
float g_oldTime[NEO_MAXPLAYERS+1];
bool g_touchedOne[NEO_MAXPLAYERS+1];
bool g_touchedTwo[NEO_MAXPLAYERS+1];
bool g_bhopMap;
bool g_lateLoad;
int g_triggerOne;
int g_triggerTwo;

public Plugin myinfo = {
	name = "Bhop Game Mode",
	description = "Test how fast you can bhop and compete with others!",
	author = "bauxite",
	version = "0.1.1",
	url = "",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoad = late;
	return APLRes_Success;
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

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeathPost, EventHookMode_Post);
	HookEvent("game_round_start", Event_RoundStartPost, EventHookMode_Post);
	AddCommandListener(OnTeam, "jointeam");
	RegConsoleCmd("sm_bhoprecords", Cmd_BhopScores);
	
	if(g_lateLoad)
	{
		OnMapInit();
		OnMapStart();
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}

public Action Cmd_BhopScores(int client, int args)
{
	if(!IsClientInGame(client) || client <= 0 || client > MaxClients || args > 0)
	{
		return Plugin_Handled;
	}

	RequestFrame(PrintRecords, client);
	return Plugin_Handled;
}

void PrintRecords(int client)
{
	PrintToConsole(client, "[BHOP] Recon record: %f", g_topScore[CLASS_RECON]);
	PrintToConsole(client, "[BHOP] Assault record: %f", g_topScore[CLASS_ASSAULT]);
	PrintToConsole(client, "[BHOP] Support record: %f", g_topScore[CLASS_SUPPORT]);
}

public void OnClientPutInServer(int client)
{
	if(!g_bhopMap)
	{
		return;
	}
	
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	
	if(!g_lateLoad)
	{
		FullResetClient(client);
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

public void OnMapInit()
{
	char mapName[32];
	GetCurrentMap(mapName, sizeof(mapName));
	
	if(StrContains(mapName, "_bhop", false) != -1)
	{
		g_bhopMap = true;
	}
	else
	{
		g_bhopMap = false;
	}
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
	}
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
	}
}

void HookTriggers()
{
	g_triggerOne = FindEntityByTargetname("trigger_multiple", "bhop_trigger_one");
	g_triggerTwo = FindEntityByTargetname("trigger_multiple", "bhop_trigger_two");
	
	if(g_triggerOne == -1 || g_triggerTwo == -1)
	{
		PrintToChatAll("[BHOP] Error: Plugin has failed");
		SetFailState("[BHOP] Error: Triggers were not found");
	}
	
	HookSingleEntityOutput(g_triggerOne, "OnStartTouch", Trigger_OnStartTouchOne);
	HookSingleEntityOutput(g_triggerTwo, "OnStartTouch", Trigger_OnStartTouchTwo);
}

public void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{	
	if(!g_bhopMap)
	{
		return;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	PrintToChat(client, "[BHOP] This is a bhop map, your timings will be calculated from one trigger to the other");
	PrintToChat(client, "[BHOP] If you touch the same trigger twice, you are reset");
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
}

public Action OnWeaponDrop(int client, int weapon)
{
	if(!g_bhopMap)
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

void Trigger_OnStartTouchOne(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		FullResetClient(activator);
	}
	
	if(g_touchedOne[activator])
	{
		ResetClient(activator, class, true);
		return;
	}
	
	if(!g_touchedTwo[activator])
	{
		g_touchedOne[activator] = true;
		StartHop(activator);
		return;
	}
	else
	{
		CheckTime(activator, class);
	}
}

void Trigger_OnStartTouchTwo(const char[] output, int caller, int activator, float delay)
{
	int class = GetPlayerClass(activator);
	
	if(class < 1 || class > 3)
	{
		PrintToChat(activator, "[BHOP] Error: Failed to get class, you were reset");
		FullResetClient(activator);
	}
	
	if(g_touchedTwo[activator])
	{
		ResetClient(activator, class, true);
		return;
	}
	
	if(!g_touchedOne[activator])
	{
		g_touchedTwo[activator] = true;
		StartHop(activator);
		return;
	}
	else
	{
		CheckTime(activator, class);
	}	
}

void StartHop(int client)
{
	g_oldTime[client] = GetGameTime();
	PrintToChat(client, "[BHOP] Start hopping to the other trigger!");
}

void CheckTime(int client, int class)
{
	g_newTime[client] = GetGameTime();
	g_time[client] = g_newTime[client] - g_oldTime[client];
	PrintToChat(client, "[BHOP] Your time: %f", g_time[client]);
	ResetClient(client, class);
	if(g_time[client] < g_topScore[class] || g_topScore[class] == 0.0)
	{
		g_topScore[class] = g_time[client];
		PrintToChatAll("[BHOP] New %s record by %N!: %f", g_className[class], client, g_time[client]);
		PrintToConsoleAll("[BHOP] New %s record by %N!: %f", g_className[class], client, g_time[client]);
	}
}

void ResetClient(int client, int class, bool same=false)
{
	g_touchedOne[client] = false;
	g_touchedTwo[client] = false;
	if(class != CLASS_SUPPORT)
	{
		SetPlayerAUX(client, 100.0);
	}
	
	if(same)
	{
		PrintToChat(client, "[BHOP] You touched the same trigger twice, you have been reset!");
	}
}

void FullResetClient(int client)
{
	g_time[client] = 0.0;
	g_newTime[client] = 0.0;
	g_oldTime[client] = 0.0;
	g_touchedOne[client] = false;
	g_touchedTwo[client] = false;
}
