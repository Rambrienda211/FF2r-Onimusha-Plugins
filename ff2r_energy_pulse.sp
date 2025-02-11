/*

    "energy_pulse"
    {
        "slot"           "1"                     // Slot zdolności
        "duration"       "0"                     // Czas trwania (nie dotyczy tego pluginu)
        "cooldown"       "15.0"                  // Cooldown między impulsami
        "radius"         "500.0"                 // Promień fali energii
        "damage"         "50.0"                  // Obrażenia od fali energii
        "force"          "1000.0"                // Siła odrzutu
        
        "plugin_name"    "ff2r_energy_pulse"
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

// Definicje pluginu
#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Energy Pulse"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "Energy Pulse ability for FF2R"
#define MAJOR_REVISION "1"
#define MINOR_REVISION "0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION
#define PLUGIN_URL ""

#define MAXTF2PLAYERS 36

// Globalne zmienne
float EP_Cooldown[MAXTF2PLAYERS];
float EP_Radius[MAXTF2PLAYERS];
float EP_Damage[MAXTF2PLAYERS];
float EP_Force[MAXTF2PLAYERS];
float EP_LastUseTime[MAXTF2PLAYERS];
bool EP_IsActive[MAXTF2PLAYERS];

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
    // Precache efektów cząsteczkowych
    PrecacheParticleSystem("energy_pulse");
}

public void OnClientPutInServer(int clientIdx)
{
    EP_IsActive[clientIdx] = false;
    EP_LastUseTime[clientIdx] = 0.0;
}

public void OnPluginEnd()
{
    for (int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
    {
        SDKUnhook(clientIdx, SDKHook_PreThink, EnergyPulse_PreThink);
    }
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
    if (!cfg.IsMyPlugin())    
        return;

    if (StrEqual(ability, "energy_pulse"))
    {
        Ability_EnergyPulse(clientIdx, ability, cfg);
    }
}

public void Ability_EnergyPulse(int clientIdx, const char[] ability_name, AbilityData ability)
{
    EP_Cooldown[clientIdx] = ability.GetFloat("cooldown", 15.0);
    EP_Radius[clientIdx] = ability.GetFloat("radius", 500.0);
    EP_Damage[clientIdx] = ability.GetFloat("damage", 50.0);
    EP_Force[clientIdx] = ability.GetFloat("force", 1000.0);

    if (GetGameTime() - EP_LastUseTime[clientIdx] < EP_Cooldown[clientIdx])
    {
        PrintToChat(clientIdx, "\x07FF2000Cooldown jeszcze trwa!");
        return;
    }

    EP_LastUseTime[clientIdx] = GetGameTime();
    EP_IsActive[clientIdx] = true;

    PerformEnergyPulse(clientIdx);
}

public void PerformEnergyPulse(int clientIdx)
{
    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);

    // Emituj dźwięk fali energii
    EmitSoundToAll("Boss.EnergyPulse", clientIdx);

    // Wyświetl efekt cząsteczkowy
    TE_SetupParticleEffect("energy_pulse", bossPos);
    TE_SendToAll();

    // Zadaj obrażenia i odrzuć graczy w promieniu
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) == GetClientTeam(clientIdx))
            continue;

        float playerPos[3];
        GetClientAbsOrigin(i, playerPos);

        float distance = GetDistanceFloat(bossPos, playerPos);
        if (distance <= EP_Radius[clientIdx])
        {
            ApplyPulseEffects(clientIdx, i, bossPos, playerPos);
        }
    }
}

public void ApplyPulseEffects(int bossIdx, int playerIdx, const float bossPos[3], const float playerPos[3])
{
    // Zadaj obrażenia
    SDKHooks_TakeDamage(playerIdx, bossIdx, bossIdx, EP_Damage[bossIdx], DMG_BLAST);

    // Oblicz wektor odrzutu
    float direction[3];
    SubtractVectors(playerPos, bossPos, direction);
    NormalizeVector(direction);
    ScaleVector(direction, EP_Force[bossIdx]);

    // Zastosuj odrzut
    SetClientVelocity(playerIdx, direction);
}

public bool IsValidClient(int clientIdx, bool replaycheck=true)
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