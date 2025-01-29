/*

"zerofuse_switch"
{
    "slot"            "0" // Passive ability slot

    "balanced_speed"   "400.0" // Base speed for the Balanced state (overrides config's "maxspeed" value), between 100-520
    "protection_speed" "320.0" // Base speed for the Protection state, between 100-520
    "wrath_speed"      "450.0" // Base speed for the Wrath state, between 100-520
    "rage_speed"       "520.0" // Speed at which Zerofuse moves during Raging Rampage (wrath rage), between 100-520
    
    "regen_time"       "30.0" // Time, in seconds, Zerofuse regenerates HP during Demonic Manipulation
    "regen_hp"         "200"  // HP to regenerate per second during Demonic Manipulation
    "hack_ratio"       "0.25" // Proportion of living RED team players to hack when Demonic Manipulation is activated (0.0-1.0)
    
    "stun_time"        "7.0"  // Stun time for Mass Hysteria
    "uber_time"        "10.0" // Uber time for Mass Hysteria
    "rage_duration"    "34.0" // Duration, in seconds, for Raging Rampage (default 34s to match sound length)
    
    "mode_cooldown"    "30.0" // Cooldown time for mode-switch
    "rage_cooldown"    "90"   // Raging Rampage cooldown time
    "manip_cooldown"   "90"   // Demonic Manipulation cooldown time
    "hysteria_cooldown" "60"  // Mass Hysteria cooldown time
    
    "plugin_name"      "ff2r_modeswitch"
}
*/


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2r>  // Upewnij się, że masz ten plik nagłówkowy

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Zerofuse Mode Switch"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "Zerofuse's mode switching ability for FF2R"
#define PLUGIN_VERSION "1.0"

#define MAXTF2PLAYERS 36

int g_iCurrentState[MAXTF2PLAYERS];
bool g_bOnCooldown[MAXTF2PLAYERS];
float g_fModeSwitchCooldown[MAXTF2PLAYERS];
float g_fRagingRampageCooldown[MAXTF2PLAYERS];
float g_fDemonicManipulationCooldown[MAXTF2PLAYERS];
float g_fMassHysteriaCooldown[MAXTF2PLAYERS];


float g_fBalancedSpeed;
float g_fProtectionSpeed;
float g_fWrathSpeed;
float g_fRageSpeed;
float g_fRegenTime;
int g_iRegenHP;
float g_fHackRatio;
float g_fStunTime;
float g_fUberTime;
float g_fRageDuration;
float g_fModeCooldown;
float g_fRageCooldown;
float g_fManipCooldown;
float g_fHysteriaCooldown;

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
};

public void OnPluginStart()
{
    HookEvent("arena_round_start", Event_RoundStart);
}

public void OnMapStart()
{
    // Load config values
    LoadConfig();
}

void LoadConfig()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/freak_fortress_2/zerofuse_switch.cfg");

    if (!FileExists(path))
    {
        SetFailState("Unable to load config file: %s", path);
    }

    KeyValues kv = new KeyValues("zerofuse_switch");
    if (!kv.ImportFromFile(path))
    {
        SetFailState("Failed to parse config file: %s", path);
    }

    // Read config values
    g_fBalancedSpeed = kv.GetFloat("balanced_speed", 400.0);
    g_fProtectionSpeed = kv.GetFloat("protection_speed", 320.0);
    g_fWrathSpeed = kv.GetFloat("wrath_speed", 450.0);
    g_fRageSpeed = kv.GetFloat("rage_speed", 520.0);
    g_fRegenTime = kv.GetFloat("regen_time", 30.0);
    g_iRegenHP = kv.GetNum("regen_hp", 200);
    g_fHackRatio = kv.GetFloat("hack_ratio", 0.25);
    g_fStunTime = kv.GetFloat("stun_time", 7.0);
    g_fUberTime = kv.GetFloat("uber_time", 10.0);
    g_fRageDuration = kv.GetFloat("rage_duration", 34.0);
    g_fModeCooldown = kv.GetFloat("mode_cooldown", 30.0);
    g_fRageCooldown = kv.GetFloat("rage_cooldown", 90.0);
    g_fManipCooldown = kv.GetFloat("manip_cooldown", 90.0);
    g_fHysteriaCooldown = kv.GetFloat("hysteria_cooldown", 60.0);

    delete kv;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client) && FF2R_GetBossIndex(client) != -1)
        {
            if (FF2R_HasAbility(client, this_plugin_name, "zerofuse_switch"))
            {
                g_iCurrentState[client] = 0; // Balanced state
                g_bOnCooldown[client] = false;
                g_fModeSwitchCooldown[client] = 0.0;
                g_fRagingRampageCooldown[client] = 0.0;
                g_fDemonicManipulationCooldown[client] = 0.0;
                g_fMassHysteriaCooldown[client] = 0.0;

                SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
                CreateTimer(5.0, Timer_DisplayMenu, client, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
            }
        }
    }
}

public Action Timer_DisplayMenu(Handle timer, int client)
{
    if (IsValidClient(client) && IsPlayerAlive(client) && FF2R_GetBossIndex(client) != -1)
    {
        DisplayModeSwitchMenu(client);
    }
    return Plugin_Continue;
}

void DisplayModeSwitchMenu(int client)
{
    Menu menu = new Menu(MenuHandler_ModeSwitch);
    menu.SetTitle("Use your demonic essence to change your form (%.1fs Cooldown):", g_fModeCooldown);
    menu.AddItem("wrath", "Wrath");
    menu.AddItem("protection", "Protection");
    menu.AddItem("balance", "Balance (No cooldown required)");
    menu.ExitButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ModeSwitch(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param, info, sizeof(info));

        if (StrEqual(info, "wrath"))
        {
            SwitchToWrath(client);
        }
        else if (StrEqual(info, "protection"))
        {
            SwitchToProtection(client);
        }
        else if (StrEqual(info, "balance"))
        {
            SwitchToBalance(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void SwitchToWrath(int client)
{
    if (g_bOnCooldown[client] || g_iCurrentState[client] == 1)
    {
        PrintToChat(client, "[Zerofuse] You cannot currently switch to this mode.");
        return;
    }

    g_iCurrentState[client] = 1;
    g_bOnCooldown[client] = true;
    g_fModeSwitchCooldown[client] = GetGameTime() + g_fModeCooldown;

    SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_fWrathSpeed);
    TF2_AddCondition(client, TFCond_SpeedBuffAlly, 999.0);

    PrintToChatAll("[Zerofuse] Zerofuse has entered a state of wrath!");
    CreateTimer(g_fModeCooldown, Timer_ResetCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
}

void SwitchToProtection(int client)
{
    if (g_bOnCooldown[client] || g_iCurrentState[client] == 2)
    {
        PrintToChat(client, "[Zerofuse] You cannot currently switch to this mode.");
        return;
    }

    g_iCurrentState[client] = 2;
    g_bOnCooldown[client] = true;
    g_fModeSwitchCooldown[client] = GetGameTime() + g_fModeCooldown;

    SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_fProtectionSpeed);
    TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);

    PrintToChatAll("[Zerofuse] Zerofuse has entered a defensive state!");
    CreateTimer(g_fModeCooldown, Timer_ResetCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
}

void SwitchToBalance(int client)
{
    if (g_iCurrentState[client] == 0)
    {
        PrintToChat(client, "[Zerofuse] You are already in a balanced state.");
        return;
    }

    g_iCurrentState[client] = 0;
    SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_fBalancedSpeed);
    TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);

    PrintToChatAll("[Orange] Zerofuse has entered a state of balance.");
}

public Action Timer_ResetCooldown(Handle timer, int client)
{
    g_bOnCooldown[client] = false;
    return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    if (victim > 0 && victim <= MaxClients && damagecustom == TF_CUSTOM_BACKSTAB)
    {
        if (victim == attacker && g_iCurrentState[victim] == 1)
        {
            TF2_AddCondition(attacker, TFCond_MarkedForDeath, g_fStunTime);
            TF2_IgnitePlayer(attacker, victim, g_fStunTime);
        }
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
    if (client <= 0 || client > MaxClients)
        return false;

    if (!IsClientInGame(client) || !IsClientConnected(client))
        return false;

    if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
        return false;

    if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
        return false;

    return true;
}