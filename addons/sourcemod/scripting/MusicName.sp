#pragma newdecls required
#pragma semicolon 1

#include <clientprefs>
#include <multicolors>
#include <sdktools>

public Plugin myinfo =
{
    name = "Music Names",
    author = "koen, .Rushaway",
    description = "Display the name of music in chat",
    version = "1.3",
};

char g_sCurrentSong[256];

bool g_bConfigLoaded = false;
bool g_bDisplay[MAXPLAYERS+1] = {true, ...};
bool g_bLate = false;

Cookie g_cDisplayStyle;

StringMap g_songNames;
StringMap g_fLastPlayedTime;

ConVar g_hCVar_CooldownTime;
ConVar g_hCVar_Message;

public void OnPluginStart()
{
    RegConsoleCmd("sm_np",               Command_NowPlaying, "Display the name of the current song");
    RegConsoleCmd("sm_nowplaying",       Command_NowPlaying, "Display the name of the current song");
    RegConsoleCmd("sm_songname",         Command_NowPlaying, "Display the name of the current song");

    RegConsoleCmd("sm_togglenp",         Command_ToggleNP,   "Toggle music name display in chat");
    RegConsoleCmd("sm_togglenowplaying", Command_ToggleNP,   "Toggle music name display in chat");

    RegConsoleCmd("sm_mn_dump",          Command_DumpMusic,  "Print all song names to console");

    RegAdminCmd("sm_mn_reload", Command_ReloadMusicnames, ADMFLAG_CONFIG, "Reloads music name config");

    HookEvent("round_start", OnRoundStart, EventHookMode_Pre);

    AddAmbientSoundHook(Hook_AmbientSound);

    LoadTranslations("MusicName.phrases");

    g_hCVar_CooldownTime = CreateConVar("sm_musicname_cooldown", "5.0", "Cooldown in seconds before the same song can be announced again", _, true, 1.0);
    g_hCVar_Message      = CreateConVar("sm_musicname_message",  "1",   "Whether to display config message at round start", _, true, 0.0, true, 1.0);
    AutoExecConfig(true);

    g_songNames = new StringMap();
    g_fLastPlayedTime = new StringMap();
    LoadConfig();

    g_cDisplayStyle = new Cookie("display_musicnames", "Display music names cookie", CookieAccess_Private);
    SetCookieMenuItem(CookiesMenu, 0, "Music Names");

    if (!g_bLate)
        return;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;

        if (!AreClientCookiesCached(client))
        {
            g_bDisplay[client] = true;
            continue;
        }

        OnClientCookiesCached(client);
    }
}

//----------------------------------------------------------------------------------------------------
// Purpose: Late load check
//----------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLate = late;
    return APLRes_Success;
}

//----------------------------------------------------------------------------------------------------
// Purpose: SourceMod event hooks
//----------------------------------------------------------------------------------------------------
public void OnPluginEnd()
{
    delete g_songNames;
    delete g_fLastPlayedTime;
    RemoveAmbientSoundHook(Hook_AmbientSound);
}

public void OnMapStart()
{
    LoadConfig();

    if (g_songNames != null)
        delete g_songNames;
    
    if (g_fLastPlayedTime != null)
        delete g_fLastPlayedTime;

    g_songNames = new StringMap();
    g_fLastPlayedTime = new StringMap();
}

public void OnMapEnd()
{
    delete g_songNames;
    delete g_fLastPlayedTime;
}

public void OnClientDisconnected(int client)
{
    g_bDisplay[client] = true;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Cookie functions
//----------------------------------------------------------------------------------------------------
public void OnClientCookiesCached(int client)
{
    char buffer[2];
    g_cDisplayStyle.Get(client, buffer, sizeof(buffer));

    if (buffer[0] == '\0')
        g_cDisplayStyle.Set(client, "1");
    else
        g_bDisplay[client] = view_as<bool>(StringToInt(buffer));
}

public void CookiesMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
    if (actions == CookieMenuAction_DisplayOption)
        FormatEx(buffer, maxlen, "Display Music Names: %s", g_bDisplay[client] ? "On" : "Off");

    if (actions == CookieMenuAction_SelectOption) {
        ToggleFeature(client);
        ShowCookieMenu(client);
    }
}

//----------------------------------------------------------------------------------------------------
// Purpose: Round start event hook
//----------------------------------------------------------------------------------------------------
public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    g_sCurrentSong = "";
    delete g_fLastPlayedTime;
    g_fLastPlayedTime = new StringMap();

    // Print map supported message
    if (g_bConfigLoaded && g_hCVar_Message.BoolValue)
        CreateTimer(5.0, Timer_OnRoundStartPost, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_OnRoundStartPost(Handle timer)
{
    CPrintToChatAll("%t %t", "Chat Prefix", "Map Supported");
    return Plugin_Stop;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Now playing command callback
//----------------------------------------------------------------------------------------------------
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

//----------------------------------------------------------------------------------------------------
// Purpose: Toggle auto display music command callback
//----------------------------------------------------------------------------------------------------
public Action Command_ToggleNP(int client, int args)
{
    ToggleFeature(client);
    return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Dump music name command callback
//----------------------------------------------------------------------------------------------------
public Action Command_DumpMusic(int client, int args)
{
    if (!g_bConfigLoaded)
    {
        CPrintToChat(client, "%t %t", "Chat Prefix", "No Config");
        return Plugin_Handled;
    }

    CPrintToChat(client, "%t %t", "Chat Prefix", "Check Console for Output");
    PrintToConsole(client, "-------------- Music Names --------------");

    StringMapSnapshot snap = g_songNames.Snapshot();
    int len = snap.Length;
    char szBuffer[256], szSongName[256];

    for (int i = 0; i < len; i++)
    {
        snap.GetKey(i, szBuffer, sizeof(szBuffer));
        g_songNames.GetString(szBuffer, szSongName, sizeof(szSongName));
        PrintToConsole(client, "%i. %s", i + 1, szSongName);
    }

    delete snap;

    PrintToConsole(client, "-----------------------------------------");
    return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Reload config command callback
//----------------------------------------------------------------------------------------------------
public Action Command_ReloadMusicnames(int client, int args)
{
    LoadConfig();

    if (g_bConfigLoaded)
        CPrintToChat(client, "%t %t", "Chat Prefix", "Reload Config");
    else
        CPrintToChat(client, "%t %t", "Chat Prefix", "Reload Failed");

    return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Sound hook callback
//----------------------------------------------------------------------------------------------------
public Action Hook_AmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
    if (!g_bConfigLoaded)
        return Plugin_Continue;

    // Mappers might use "volume 0" to stop music, which triggers sound hook
    // So check if this is the input
    if (volume == 0.0)
        return Plugin_Continue;

    char sFileName[PLATFORM_MAX_PATH];
    GetFileFromPath(sample, sFileName, sizeof(sFileName));
    StringToLowerCase(sFileName);

    char sBuffer[PLATFORM_MAX_PATH];
    if (g_songNames.GetString(sFileName, sBuffer, sizeof(sBuffer)))
    {
        // Mappers might also use "volume" input to fade music out, which also triggers sound hook
        // So check if detected song is same as current song
        if (strcmp(sBuffer, g_sCurrentSong, false) == 0)
            return Plugin_Continue;

        float currentTime = GetGameTime();
        float lastPlayed;

        // Check if the song was played recently
        if (g_fLastPlayedTime.GetValue(sFileName, lastPlayed) && (currentTime - lastPlayed) < g_hCVar_CooldownTime.FloatValue)
            return Plugin_Continue;

        // Update the timestamp
        g_fLastPlayedTime.SetValue(sFileName, currentTime);
        g_sCurrentSong = sBuffer;

        // Announce the song to players
        for (int client = 1; client <= MaxClients; client++)
        {
            if (!IsClientInGame(client) || IsFakeClient(client) || !g_bDisplay[client])
                continue;

            if (g_sCurrentSong[0] != '\0')
                CPrintToChat(client, "%t %t", "Chat Prefix", "Now Playing", g_sCurrentSong);
        }
    }

    return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose: Loads song config
//----------------------------------------------------------------------------------------------------
stock void LoadConfig()
{
    g_bConfigLoaded = false;

    delete g_fLastPlayedTime;
    delete g_songNames;
    g_fLastPlayedTime = new StringMap();
    g_songNames = new StringMap();

    char g_sCurrentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    StringToLowerCase(g_sCurrentMap);

    char g_sConfigPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, g_sConfigPath, sizeof(g_sConfigPath), "configs/musicname/%s.cfg", g_sCurrentMap);

    KeyValues kv = new KeyValues("music");
    if (!kv.ImportFromFile(g_sConfigPath))
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

//----------------------------------------------------------------------------------------------------
// Purpose: Get file name from file path
//----------------------------------------------------------------------------------------------------
stock void GetFileFromPath(const char[] path, char[] buffer, int maxlen)
{
    char normalizedPath[PLATFORM_MAX_PATH];
    strcopy(normalizedPath, sizeof(normalizedPath), path);
    ReplaceString(normalizedPath, sizeof(normalizedPath), "\\", "/");

    int lastSlash = FindCharInString(normalizedPath, '/', true);
    if (lastSlash != -1)
        strcopy(buffer, maxlen, normalizedPath[lastSlash+1]);
    else
        strcopy(buffer, maxlen, normalizedPath);
}

//----------------------------------------------------------------------------------------------------
// Purpose: Convert string to lowercase
//----------------------------------------------------------------------------------------------------
stock void StringToLowerCase(char[] input)
{
    int i = 0, x;
    while ((x = input[i]) != '\0')
    {
        if ('A' <= x <= 'Z')
            input[i] += ('a' - 'A');
        i++;
    }
}

//----------------------------------------------------------------------------------------------------
// Purpose: Toggle feature
//----------------------------------------------------------------------------------------------------
stock void ToggleFeature(int client)
{
    g_bDisplay[client] = !g_bDisplay[client];
    g_cDisplayStyle.Set(client, g_bDisplay[client] ? "1" : "0");

    if (g_bDisplay[client])
        CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Enabled");
    else
        CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Disabled");
}