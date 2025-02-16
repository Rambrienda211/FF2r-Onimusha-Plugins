/* 

	"rage_ability_menu"
    {
        "slot"                  "0"                     // Ability slot
        "mana_start"            "100.0"                // Starting mana
        "mana_max"              "100.0"                // Maximum mana
        "mana_regen"            "1.0"                  // Mana regeneration per tick
        "switch"                "3"                    // 3 = R switch ability
        "key"                   "2"                    // 2 = M3 use ability

        "menu_position"         "0"                    // Menu position (0: Center, 1: Top, 2: Bottom)
        "menu_color_r"          "255"                  // Menu text color (Red)
        "menu_color_g"          "0"                    // Menu text color (Green)
        "menu_color_b"          "0"                    // Menu text color (Blue)
        "menu_color_a"          "255"                  // Menu text color (Alpha)

        "ability_name_1"        "Fireball"             // Name of ability 1
        "ability_cost_1"        "30.0"                 // Cost of ability 1
        "ability_cooldown_1"    "10.0"                 // Cooldown of ability 1
        "global cooldown"	"30.0"	               // Like 'cooldown', but applies to all spells
	"low"		        "8"		               // Lowest ability slot to activate. If left blank, "high" is used
	"high"		        "8"		               // Highest ability slot to activate. If left blank, "low" is used

        "ability_name_2"        "Ice Blast"            // Name of ability 2
        "ability_cost_2"        "40.0"                 // Cost of ability 2
        "ability_cooldown_2"    "15.0"                 // Cooldown of ability 2
        "global cooldown"       "30.0"	               // Like 'cooldown', but applies to all spells
	"low"		        "8"		               // Lowest ability slot to activate. If left blank, "high" is used
	"high"		        "8"		               // Highest ability slot to activate. If left blank, "low" is used

        "ability_name_3"        "Lightning Strike"     // Name of ability 3
        "ability_cost_3"        "50.0"                 // Cost of ability 3
        "ability_cooldown_3"    "20.0"                 // Cooldown of ability 3
        "global cooldown"	"30.0"	               // Like 'cooldown', but applies to all spells
	"low"		        "8"		               // Lowest ability slot to activate. If left blank, "high" is used
	"high"		        "8"		               // Highest ability slot to activate. If left blank, "low" is used

        "plugin_name"           "ff2r_ability_menu"
    }

*/


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#undef REQUIRE_PLUGIN
#include <tf2attributes>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Ability Menu with Mana and Customization"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "Customizable ability menu with mana for FF2R"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL     ""

#define MAXTF2PLAYERS 36
#define MAX_ABILITIES 10

char AbilityNames[MAXTF2PLAYERS][MAX_ABILITIES][64];
float AbilityCost[MAXTF2PLAYERS][MAX_ABILITIES];
float AbilityCooldown[MAXTF2PLAYERS][MAX_ABILITIES];
float AbilityGlobalCooldown[MAXTF2PLAYERS];
int SelectedAbility[MAXTF2PLAYERS];

float Mana[MAXTF2PLAYERS];
float ManaRegen[MAXTF2PLAYERS];
float MaxMana[MAXTF2PLAYERS];

// Customization
int MenuPosition[MAXTF2PLAYERS]; // 0: Center, 1: Top, 2: Bottom
int MenuColor[MAXTF2PLAYERS][4]; // RGBA color

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL,
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_abilities", Command_Abilities);
    HookEvent("player_death", Event_PlayerDeath);
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
    if (!cfg.IsMyPlugin())    
        return;
    
    if (StrEqual(ability, "rage_ability_menu", false))
    {
        Ability_AbilityMenu(clientIdx, ability, cfg);
    }
}

public void Ability_AbilityMenu(int clientIdx, const char[] ability_name, AbilityData ability)
{
    // Load ability names and costs from config
    for (int i = 0; i < MAX_ABILITIES; i++)
    {
        char key[32];
        Format(key, sizeof(key), "ability_name_%d", i + 1);
        ability.GetString(key, AbilityNames[clientIdx][i], 64, "Ability");

        Format(key, sizeof(key), "ability_cost_%d", i + 1);
        AbilityCost[clientIdx][i] = ability.GetFloat(key, 50.0);

        Format(key, sizeof(key), "ability_cooldown_%d", i + 1);
        AbilityCooldown[clientIdx][i] = ability.GetFloat(key, 10.0);
    }

    // Load mana settings
    Mana[clientIdx] = ability.GetFloat("mana_start", 100.0);
    MaxMana[clientIdx] = ability.GetFloat("mana_max", 100.0);
    ManaRegen[clientIdx] = ability.GetFloat("mana_regen", 1.0);

    // Load menu customization
    MenuPosition[clientIdx] = ability.GetInt("menu_position", 0); // 0: Center, 1: Top, 2: Bottom
    MenuColor[clientIdx][0] = ability.GetInt("menu_color_r", 255); // Red
    MenuColor[clientIdx][1] = ability.GetInt("menu_color_g", 255); // Green
    MenuColor[clientIdx][2] = ability.GetInt("menu_color_b", 255); // Blue
    MenuColor[clientIdx][3] = ability.GetInt("menu_color_a", 255); // Alpha

    // Open menu
    OpenAbilityMenu(clientIdx);
}

public Action Command_Abilities(int client, int args)
{
    if (IsValidClient(client) && FF2R_GetBossIndex(client) != -1)
    {
        OpenAbilityMenu(client);
    }
    return Plugin_Handled;
}

public void OpenAbilityMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Abilities);

    // Set menu title with color
    char title[128];
    Format(title, sizeof(title), "\x07%02X%02X%02X%02XSelect Ability (Mana: %.1f/%.1f):", 
        MenuColor[client][0], MenuColor[client][1], MenuColor[client][2], MenuColor[client][3], 
        Mana[client], MaxMana[client]);
    menu.SetTitle(title);

    // Add abilities to menu
    for (int i = 0; i < MAX_ABILITIES; i++)
    {
        char display[128];
        Format(display, sizeof(display), "\x07%02X%02X%02X%02X%s (Cost: %.1f)", 
            MenuColor[client][0], MenuColor[client][1], MenuColor[client][2], MenuColor[client][3], 
            AbilityNames[client][i], AbilityCost[client][i]);
        menu.AddItem("", display);
    }

    // Set menu position
    switch (MenuPosition[client])
    {
        case 1: menu.Pagination = MENUPOS_TOP;
        case 2: menu.Pagination = MENUPOS_BOTTOM;
        default: menu.Pagination = MENUPOS_CENTER;
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Abilities(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        SelectedAbility[client] = param2;
        PrintToChat(client, "You selected: %s", AbilityNames[client][param2]);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (IsValidClient(client) && FF2R_GetBossIndex(client) != -1)
    {
        if (buttons & IN_RELOAD) // R key
        {
            OpenAbilityMenu(client);
            buttons &= ~IN_RELOAD; // Prevent reloading
        }

        if (buttons & IN_ATTACK2) // M3 key
        {
            UseSelectedAbility(client);
            buttons &= ~IN_ATTACK2; // Prevent secondary attack
        }

        // Regenerate mana
        if (Mana[client] < MaxMana[client])
        {
            Mana[client] += ManaRegen[client] * 0.1;
            if (Mana[client] > MaxMana[client])
            {
                Mana[client] = MaxMana[client];
            }
        }
    }
    return Plugin_Continue;
}

public void UseSelectedAbility(int client)
{
    int abilityIndex = SelectedAbility[client];
    if (abilityIndex < 0 || abilityIndex >= MAX_ABILITIES)
    {
        return;
    }

    if (AbilityCooldown[client][abilityIndex] > GetGameTime())
    {
        PrintToChat(client, "Ability is on cooldown!");
        return;
    }

    if (Mana[client] < AbilityCost[client][abilityIndex])
    {
        PrintToChat(client, "Not enough mana!");
        return;
    }

    // Use mana
    Mana[client] -= AbilityCost[client][abilityIndex];

    // Example abilities
    switch (abilityIndex)
    {
        case 0: Ability_Fireball(client);
        case 1: Ability_IceBlast(client);
        case 2: Ability_LightningStrike(client);
        // Add more abilities here
    }

    // Set cooldown
    AbilityCooldown[client][abilityIndex] = GetGameTime() + 10.0; // 10 seconds cooldown
}

public void Ability_Fireball(int client)
{
    float pos[3];
    GetClientEyePosition(client, pos);

    // Create fireball effect
    TE_SetupBeamRingPoint(pos, 10.0, 100.0, PrecacheModel("sprites/laser.vmt"), 0, 0, 10, 10.0, 10.0, 5.0, {255, 0, 0, 255}, 10, 0);
    TE_SendToAll();

    // Play sound
    EmitSoundToAll("ambient/fire/fire_big1.wav", client);

    // Damage nearby players
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            float distance = GetVectorDistance(pos, playerPos);

            if (distance <= 200.0)
            {
                SDKHooks_TakeDamage(i, client, client, 50.0, DMG_BURN);
            }
        }
    }
}

public void Ability_IceBlast(int client)
{
    float pos[3];
    GetClientEyePosition(client, pos);

    // Create ice blast effect
    TE_SetupBeamRingPoint(pos, 10.0, 100.0, PrecacheModel("sprites/laser.vmt"), 0, 0, 10, 10.0, 10.0, 5.0, {0, 0, 255, 255}, 10, 0);
    TE_SendToAll();

    // Play sound
    EmitSoundToAll("ambient/wind/wind_snippet1.wav", client);

    // Slow nearby players
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            float distance = GetVectorDistance(pos, playerPos);

            if (distance <= 200.0)
            {
                TF2_AddCondition(i, TFCond_Slowed, 5.0);
            }
        }
    }
}

public void Ability_LightningStrike(int client)
{
    float pos[3];
    GetClientEyePosition(client, pos);

    // Create lightning strike effect
    TE_SetupBeamPoints(pos, pos, PrecacheModel("sprites/lgtning.spr"), 0, 0, 0, 0.5, 10.0, 10.0, 0, 0.0, {255, 255, 255, 255}, 10);
    TE_SendToAll();

    // Play sound
    EmitSoundToAll("ambient/energy/zap1.wav", client);

    // Damage nearby players
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            float distance = GetVectorDistance(pos, playerPos);

            if (distance <= 200.0)
            {
                SDKHooks_TakeDamage(i, client, client, 75.0, DMG_SHOCK);
            }
        }
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client) && FF2R_GetBossIndex(client) != -1)
    {
        // Reset selected ability on death
        SelectedAbility[client] = 0;
    }
}

stock bool IsValidClient(int clientIdx, bool replaycheck = true)
{
    if (clientIdx <= 0 || clientIdx > MaxClients)
        return false;

    if (!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
        return false;

    if (GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
        return false;

    if (replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
        return false;

    return true;
}
