#pragma newdecls required
#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <utilshelper>

public Plugin myinfo = {
    name = "Music Names",
    author = "koen, .Rushaway",
    description = "Displays the name of the current song in chat",
    version = "1.2.0",
    url = "https://github.com/notkoen"
};

char g_sCurrentSong[256];
char g_sCurrentMap[PLATFORM_MAX_PATH];

bool g_bConfigLoaded = false;
bool g_bDisplay[MAXPLAYERS+1] = {true, ...};

StringMap g_songNames;
StringMap g_fLastPlayedTime;

float g_fCooldownTime = 30.0;
ConVar g_cvCooldownTime;

public void OnPluginStart() {
    RegConsoleCmd("sm_np", Command_NowPlaying, "Display the name of the current song");
    RegConsoleCmd("sm_nowplaying", Command_NowPlaying, "Display the name of the current song");
    RegConsoleCmd("sm_togglenp", Command_ToggleNP, "Toggle music name display in chat");

    RegAdminCmd("sm_reload_musicname", Command_ReloadMusicnames, ADMFLAG_CONFIG, "Reloads music name config");

    HookEvent("round_start", OnRoundStart, EventHookMode_Pre);

    AddAmbientSoundHook(Hook_AmbientSound);

    LoadTranslations("MusicName.phrases");

    g_cvCooldownTime = CreateConVar("sm_musicname_cooldown", "5.0", "Cooldown in seconds before the same song can be announced again", _, true, 1.0);
    g_cvCooldownTime.AddChangeHook(OnCooldownChanged);
    g_fCooldownTime = g_cvCooldownTime.FloatValue;

    AutoExecConfig(true);

    g_songNames = new StringMap();
    g_fLastPlayedTime = new StringMap();
    GetCurrentMap(g_sCurrentMap, PLATFORM_MAX_PATH);
    LoadConfig();
}

public void OnCooldownChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_fCooldownTime = g_cvCooldownTime.FloatValue;
}

public void OnPluginEnd() {
    delete g_songNames;
    delete g_fLastPlayedTime;
    RemoveAmbientSoundHook(Hook_AmbientSound);
}

public void OnMapStart() {
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    LoadConfig();
    g_fLastPlayedTime.Clear();
}

public void OnMapEnd() {
    delete g_songNames;
    delete g_fLastPlayedTime;
    g_songNames = new StringMap();
    g_fLastPlayedTime = new StringMap();
}

public void OnClientDisconnected(int client) {
    g_bDisplay[client] = true;
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    g_sCurrentSong = "";
    g_fLastPlayedTime.Clear();

    // Print map supported message
    if (g_bConfigLoaded)
        CreateTimer(5.0, Timer_OnRoundStartPost, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_OnRoundStartPost(Handle timer) {
    CPrintToChatAll("%t %t", "Chat Prefix", "Map Supported");
    return Plugin_Stop;
}

public Action Command_NowPlaying(int client, int args) {
    if (!g_bConfigLoaded) {
        CPrintToChat(client, "%t %t", "Chat Prefix", "No Config");
        return Plugin_Handled;
    }

    if (g_sCurrentSong[0] == '\0') {
        CPrintToChat(client, "%t %t", "Chat Prefix", "No Name");
        return Plugin_Handled;
    }

    CPrintToChat(client, "%t %t", "Chat Prefix", "Now Playing", g_sCurrentSong);
    return Plugin_Handled;
}

public Action Command_ToggleNP(int client, int args) {
    g_bDisplay[client] = !g_bDisplay[client];

    if (g_bDisplay[client])
        CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Enabled");
    else
        CPrintToChat(client, "%t %t", "Chat Prefix", "Display Status", "Disabled");

    return Plugin_Handled;
}

public Action Command_ReloadMusicnames(int client, int args) {
    LoadConfig();
    CPrintToChat(client, "%t %t", "Chat Prefix", "Reload Config");
    return Plugin_Handled;
}

public void LoadConfig()
{
    g_bConfigLoaded = false;
    g_songNames.Clear();

    char g_sConfig[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, g_sConfig, sizeof(g_sConfig), "configs/musicname/%s.cfg", g_sCurrentMap);

    KeyValues kv = new KeyValues("music");
    if (!kv.ImportFromFile(g_sConfig)) {
        delete kv;
        return;
    }

    if (!kv.GotoFirstSubKey(false)) {
        delete kv;
        LogError("[MusicNames] Invalid config formatting for %s", g_sCurrentMap);
        return;
    }

    do {
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

void GetFileFromPath(const char[] path, char[] buffer, int maxlen)
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

public Action Hook_AmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
    if (!g_bConfigLoaded)
        return Plugin_Continue;

    // Mappers might use "volume 0" to stop music from playing
    // This triggers ambient sound hook
    // So let's check if this is the input first
    if (volume == 0.0)
        return Plugin_Continue;

    char sFileName[PLATFORM_MAX_PATH];
    GetFileFromPath(sample, sFileName, sizeof(sFileName));
    StringToLowerCase(sFileName);

    char sBuffer[PLATFORM_MAX_PATH];
    if (g_songNames.GetString(sFileName, sBuffer, sizeof(sBuffer))) {
        // Mappers might also use "volume" input to fade music out
        // This will trigger the sound hook as well
        // So let's check if detected song is same as current song
        if (strcmp(sBuffer, g_sCurrentSong, false) == 0)
            return Plugin_Continue;

        float currentTime = GetGameTime();
        float lastPlayed;

        // Check if the song was played recently
        if (g_fLastPlayedTime.GetValue(sFileName, lastPlayed) && (currentTime - lastPlayed) < g_fCooldownTime)
            return Plugin_Continue;

        // Update the timestamp
        g_fLastPlayedTime.SetValue(sFileName, currentTime);
        g_sCurrentSong = sBuffer;

        // Announce the song to players
        for (int client = 1; client <= MaxClients; client++)
        {
            if (!IsClientInGame(client) || IsFakeClient(client))
                continue;

            if (!g_bDisplay[client])
                continue;

            CPrintToChat(client, "%t %t", "Chat Prefix", "Now Playing", g_sCurrentSong);
        }
    }

    return Plugin_Continue;
}
