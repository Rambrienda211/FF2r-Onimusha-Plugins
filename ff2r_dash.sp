/*
"special_new_dash"
{
    "slot"           "0"
    "maxdist"        "9999.0"
    "initial"        "8.0"
    "buttonmode"     "11"
    "charges"        "1"
    "stack"          "3"
    "cooldown"       "6.0"
    "hud_x"          "-1.0"
    "hud_y"          "0.75"
    "strings"        "New Dash: [%s][%d/%d]"
    //Test
    "plugin_name"    "ff2r_dash"
}
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: New Dash"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "New Dash Mechanic for FF2R"

#define MAJOR_REVISION "1"
#define MINOR_REVISION "0"
#define STABLE_REVISION "1"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL ""

#define MAXTF2PLAYERS 36

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL,
};

Handle HudDash;
float TP_Cooldown[MAXTF2PLAYERS];
bool TP_InUse[MAXTF2PLAYERS];
bool TP_Enabled[MAXTF2PLAYERS];
int TP_Charges[MAXTF2PLAYERS];
int TP_MaxCharges[MAXTF2PLAYERS];
float TP_HudX[MAXTF2PLAYERS];
float TP_HudY[MAXTF2PLAYERS];
char TP_HudText[MAXTF2PLAYERS][256];
int TP_ButtonMode[MAXTF2PLAYERS];

public void OnPluginStart()
{
    HudDash = CreateHudSynchronizer();
    PrintToServer("FF2R Dash Plugin v%s Loaded!", PLUGIN_VERSION);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);

    ResetAllDashData();
}

public void OnPluginEnd()
{
    ResetAllDashData();
}

public void ResetAllDashData()
{
    for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
    {
        TP_InUse[clientIdx] = false;
        TP_Enabled[clientIdx] = false;
        TP_Charges[clientIdx] = 0;
        TP_MaxCharges[clientIdx] = 0;
        TP_Cooldown[clientIdx] = 0.0;
        TP_HudX[clientIdx] = -1.0;
        TP_HudY[clientIdx] = 0.75;
        TP_ButtonMode[clientIdx] = 11;
        Format(TP_HudText[clientIdx], sizeof(TP_HudText[]), "New Dash: [%s][%d/%d]");
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int clientIdx = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(clientIdx))
    {
        LoadDashConfig(clientIdx);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int clientIdx = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(clientIdx))
    {
        TP_Enabled[clientIdx] = false;
    }
}

public void LoadDashConfig(int clientIdx)
{
    if (!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx))
        return;

    BossData bossData = FF2R_GetBossData(clientIdx);

    if (bossData == null)
        return;

    AbilityData dash = bossData.GetAbility("special_new_dash");

    if (dash == null || !dash.IsMyPlugin())
    {
        TP_Enabled[clientIdx] = false;
        return;
    }

    TP_Charges[clientIdx] = dash.GetInt("charges", 1);
    TP_MaxCharges[clientIdx] = dash.GetInt("stack", 3);
    TP_Cooldown[clientIdx] = GetGameTime() + dash.GetFloat("initial", 8.0);
    TP_HudX[clientIdx] = dash.GetFloat("hud_x", -1.0);
    TP_HudY[clientIdx] = dash.GetFloat("hud_y", 0.75);
    TP_ButtonMode[clientIdx] = dash.GetInt("buttonmode", 11);
    dash.GetString("strings", TP_HudText[clientIdx], sizeof(TP_HudText[]), "New Dash: [%s][%d/%d]");

    TP_Enabled[clientIdx] = true;
}

public void FF2R_OnBossRemoved(int clientIdx)
{
    if (!IsValidClient(clientIdx))
        return;

    TP_Cooldown[clientIdx] = GetGameTime();
    TP_Enabled[clientIdx] = false;
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{
    if (!setup || FF2R_GetGamemodeType() != 2 || !IsValidClient(clientIdx))
        return;

    if (cfg == null)
        return;

    AbilityData dash = cfg.GetAbility("special_new_dash");

    if (dash != null && dash.IsMyPlugin())
    {
        TP_Enabled[clientIdx] = true;
        TP_Cooldown[clientIdx] = GetGameTime() + dash.GetFloat("initial", 8.0);
    }
}

public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx) || !TP_Enabled[clientIdx])
        return Plugin_Continue;

    BossData bossData = FF2R_GetBossData(clientIdx);
    AbilityData dash = bossData.GetAbility("special_new_dash");

    if (dash == null || !dash.GetBool("enabled", true))
        return Plugin_Continue;

    float gameTime = GetGameTime();
    int charges = TP_Charges[clientIdx];
    int maxCharges = TP_MaxCharges[clientIdx];
    int buttonMode = TP_ButtonMode[clientIdx];

    if (!(buttons & IN_SCORE))
    {
        float hud_x = TP_HudX[clientIdx];
        float hud_y = TP_HudY[clientIdx];

        char hudText[256];
        Format(hudText, sizeof(hudText), TP_HudText[clientIdx], charges, maxCharges);

        char duration[32];
        if (charges >= maxCharges)
        {
            Format(duration, sizeof(duration), "MAX");
            SetHudTextParams(hud_x, hud_y, 0.1, 255, 255, 255, 255);
        }
        else
        {
            Format(duration, sizeof(duration), "%.1f", TP_Cooldown[clientIdx] - gameTime);
            SetHudTextParams(hud_x, hud_y, 0.1, 255, (charges > 0) ? 255 : 64, (charges > 0) ? 255 : 64, 255);
        }

        ShowSyncHudText(clientIdx, HudDash, hudText, duration, charges, maxCharges);
    }

    if (charges < maxCharges && TP_Cooldown[clientIdx] <= gameTime)
    {
        TP_Charges[clientIdx]++;
        TP_Cooldown[clientIdx] = gameTime + dash.GetFloat("cooldown", 6.0);
    }

    if ((buttons & ReturnButtonMode(buttonMode)) && charges > 0 && !TP_InUse[clientIdx])
    {
        TP_Charges[clientIdx]--;
        TP_InUse[clientIdx] = true;

        CreateTimer(0.5, ResetTPUse, clientIdx);
    }

    return Plugin_Continue;
}

public Action ResetTPUse(Handle timer, int clientIdx)
{
    if (IsValidClient(clientIdx))
        TP_InUse[clientIdx] = false;

    return Plugin_Stop;
}

stock int ReturnButtonMode(int mode)
{
    switch (mode)
    {
        case 0: return IN_ATTACK;
        case 1: return IN_JUMP;
        case 2: return IN_DUCK;
        case 3: return IN_FORWARD;
        case 4: return IN_BACK;
        case 5: return IN_USE;
        case 6: return IN_CANCEL;
        case 7: return IN_LEFT;
        case 8: return IN_RIGHT;
        case 9: return IN_MOVELEFT;
        case 10: return IN_MOVERIGHT;
        case 11: return IN_ATTACK2;
        case 12: return IN_RUN;
        case 13: return IN_RELOAD;
        case 14: return IN_ALT1;
        case 15: return IN_ALT2;
        case 16: return IN_SCORE;
        case 17: return IN_SPEED;
        case 18: return IN_WALK;
        case 19: return IN_ZOOM;
        case 20: return IN_WEAPON1;
        case 21: return IN_WEAPON2;
        case 22: return IN_BULLRUSH;
        case 23: return IN_GRENADE1;
        case 24: return IN_GRENADE2;
        case 25: return IN_ATTACK3;
        default: return IN_RELOAD;
    }
}

stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
