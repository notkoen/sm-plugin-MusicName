#pragma newdecls required
#pragma semicolon 1

#include <clientprefs>
#include <multicolors>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

public Plugin myinfo =
{
	name = "Music Names",
	author = "koen",
	description = "Displays the name of the current song in chat",
	version = "0.9",
	url = "https://github.com/notkoen"
};

char g_sCurrentSong[256];
char g_sCurrentMap[PLATFORM_MAX_PATH];
bool g_bConfigLoaded = false;
bool g_bDisplay[MAXPLAYERS+1] = {true, ...};
Cookie g_cDisplayStyle;
StringMap g_songNames;
StringMap g_printedAlready;

public void OnPluginStart()
{
	RegConsoleCmd("sm_np", Command_NowPlaying, "Display the name of the current song");
	RegConsoleCmd("sm_nowplaying", Command_NowPlaying, "Display the name of the current song");

	RegConsoleCmd("sm_togglenp", Command_ToggleNP, "Toggle music name display in chat");

	RegAdminCmd("sm_reload_musicname", Command_ReloadMusicnames, ADMFLAG_CONFIG, "Reloads music name config");

	HookEvent("round_start", OnRoundStart, EventHookMode_Pre);

	AddAmbientSoundHook(Hook_AmbientSound);

	g_cDisplayStyle = new Cookie("display_musicnames", "Display music names cookie", CookieAccess_Private);
	SetCookieMenuItem(CookiesMenu, 0, "Music Names");

	LoadTranslations("MusicName.phrases");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	g_songNames = new StringMap();
	g_printedAlready = new StringMap();
	GetCurrentMap(g_sCurrentMap, PLATFORM_MAX_PATH);
	LoadConfig();
}

public void OnPluginEnd()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		char buffer[2];
		buffer = g_bDisplay[client] ? "1" : "0";
		g_cDisplayStyle.Set(client, buffer);
	}

	delete g_songNames;
	delete g_printedAlready;
	RemoveAmbientSoundHook(Hook_AmbientSound);
}

public void OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	LoadConfig();
}

public void OnMapEnd()
{
	delete g_songNames;
	delete g_printedAlready;
	g_songNames = new StringMap();
	g_printedAlready = new StringMap();
}

public void OnClientDisconnected(int client)
{
	g_bDisplay[client] = true;
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;

	char buffer[2];
	g_cDisplayStyle.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
		g_cDisplayStyle.Set(client, "1");
	else
		g_bDisplay[client] = view_as<bool>(StringToInt(buffer));
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_sCurrentSong = "";
	g_printedAlready.Clear();
	if (g_bConfigLoaded)
		CreateTimer(5.0, Timer_OnRoundStartPost);
}

public Action Timer_OnRoundStartPost(Handle timer)
{
	CPrintToChatAll("%t %t", "Chat Prefix", "Map Supported");
	return Plugin_Stop;
}

public void CookiesMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
		FormatEx(buffer, maxlen, "Display Music Names: %s", g_bDisplay[client] ? "On" : "Off");

	if (actions == CookieMenuAction_SelectOption)
	{
		g_bDisplay[client] = !g_bDisplay[client];
		g_cDisplayStyle.Set(client, g_bDisplay[client] ? "1" : "0");

		if (g_bDisplay[client])
			CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Enabled");
		else
			CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Disabled");
		ShowCookieMenu(client);
	}
}

public Action Command_NowPlaying(int client, int args)
{
	if (!g_bConfigLoaded)
	{
		CPrintToChat(client, "%t %t", "Chat Prefix", "No Config");
		return Plugin_Handled;
	}

	if (g_sCurrentSong[0] == '\0')
	{
		CPrintToChat(client, "%t %t", "Chat Prefix", "No Name");
		return Plugin_Handled;
	}

	CPrintToChat(client, "%t %t", "Chat Prefix", "Now Playing", g_sCurrentSong);
	return Plugin_Handled;
}

public Action Command_ToggleNP(int client, int args)
{
	g_bDisplay[client] = !g_bDisplay[client];
	g_cDisplayStyle.Set(client, g_bDisplay[client] ? "1" : "0");

	if (g_bDisplay[client])
		CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Enabled");
	else
		CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Disabled");
	return Plugin_Handled;
}

public Action Command_ReloadMusicnames(int client, int args)
{
	LoadConfig();
	CPrintToChat(client, "%t %t", "Chat Prefix", "Reload Config");
	return Plugin_Handled;
}

public void LoadConfig()
{
	g_bConfigLoaded = false;

	g_songNames.Clear();
	g_printedAlready.Clear();

	char g_sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, g_sConfig, sizeof(g_sConfig), "configs/musicname/%s.cfg", g_sCurrentMap);

	KeyValues kv = new KeyValues("music");
	if (!kv.ImportFromFile(g_sConfig))
	{
		delete kv;
		return;
	}

	if (!kv.GotoFirstSubKey(false))
	{
		delete kv;
		LogError("[MusicNames] Invalid config formatting for %s", g_sCurrentMap);
		return;
	}

	do
	{
		char sKey[128];
		char sValue[128];

		kv.GetSectionName(sKey, sizeof(sKey));
		kv.GetString(NULL_STRING, sValue, sizeof(sValue));
		g_songNames.SetString(sKey, sValue);
	}
	while (kv.GotoNextKey(false));

	delete kv;
	g_bConfigLoaded = true;

	return;
}

public Action Hook_AmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	if (!g_bConfigLoaded)
	{
		return Plugin_Continue;
	}

	if (volume == 0.0)
	{
		return Plugin_Continue;
	}

	char sFileName[PLATFORM_MAX_PATH], sBuffer[PLATFORM_MAX_PATH];
	strcopy(sBuffer, sizeof(sBuffer), sample);
	ReplaceString(sBuffer, sizeof(sBuffer), "\\", "/");

	int lastSlash = FindCharInString(sBuffer, '/', true);
	strcopy(sFileName, sizeof(sFileName), sBuffer);
	if (lastSlash != -1)
	{
		strcopy(sFileName, sizeof(sFileName), sBuffer);
		sBuffer[lastSlash+1] = '\0';
		ReplaceString(sFileName, sizeof(sFileName), sBuffer, "");
	}

	int len = strlen(sFileName);
	for (int i = 0; i < len; i++)
	{
		sFileName[i] = CharToLower(sFileName[i]);
	}

	bool bPrinted;
	if (g_songNames.GetString(sFileName, sBuffer, sizeof(sBuffer)) && !g_printedAlready.GetValue(sFileName, bPrinted))
	{
		g_printedAlready.SetValue(sFileName, true);
		g_sCurrentSong = sBuffer;
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || IsFakeClient(client))
				continue;

			if (!g_bDisplay[client])
				continue;

			CPrintToChat(client, "%t %t", "Chat Prefix", "Now Playing", g_sCurrentSong);
		}

		DataPack hSongData = new DataPack();
		hSongData.WriteString(sFileName);
		RequestFrame(ClearPrintedAlready, hSongData);
	}
	return Plugin_Continue;
}

public void ClearPrintedAlready(DataPack hSongData)
{
	char sFileName[PLATFORM_MAX_PATH];
	hSongData.Reset();
	hSongData.ReadString(sFileName, sizeof(sFileName));
	delete hSongData;
	g_printedAlready.Remove(sFileName);
}
