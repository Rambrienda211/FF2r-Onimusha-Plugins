/*

    "rage_spirit_portal"
    {
        "slot"                 "0"                     // Ability slot
        "ghost_count"          "5"                     // Number of ghosts
        "ghost_speed"          "400.0"                 // Speed of the ghosts
        "ghost_damage"         "15.0"                  // Damage dealt by the ghosts
        "ghost_duration"       "15.0"                  // Duration of the ghosts
        "portal_duration"      "10.0"                  // Duration of the portal

        "plugin_name"           "ff2r_spirit_portal"
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

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Ghost Ronin - Spirit Portal"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "Enhanced Spirit Portal ability for Ghost Ronin"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL     ""

#define MAXTF2PLAYERS 36
#define INACTIVE 100000000.0

float SP_GhostCount[MAXTF2PLAYERS];
float SP_GhostSpeed[MAXTF2PLAYERS];
float SP_GhostDamage[MAXTF2PLAYERS];
float SP_GhostDuration[MAXTF2PLAYERS];
float SP_PortalDuration[MAXTF2PLAYERS];

int SP_PortalRef[MAXTF2PLAYERS];
int SP_GhostsRef[MAXTF2PLAYERS][MAXTF2PLAYERS]; // Array to store ghost references

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
    PrecacheSound("ambient/atmosphere/cave_hit1.wav");
    PrecacheSound("ambient/energy/zap1.wav");
    PrecacheSound("ambient/energy/zap7.wav");
    PrecacheModel("models/player/ghost.mdl");
    PrecacheModel("models/props_medieval/wooden_loom.mdl"); // Model portalu
    PrecacheParticle("ghost_portal_effect"); // Efekt cząsteczkowy portalu
    PrecacheParticle("ghost_trail"); // Efekt cząsteczkowy śladu duchów
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
    if (!cfg.IsMyPlugin())    
        return;
    
    if (StrEqual(ability, "rage_spirit_portal", false))
    {
        Ability_SpiritPortal(clientIdx, ability, cfg);
    }
}

public void Ability_SpiritPortal(int clientIdx, const char[] ability_name, AbilityData ability)
{
    SP_GhostCount[clientIdx] = ability.GetFloat("ghost_count", 5.0);
    SP_GhostSpeed[clientIdx] = ability.GetFloat("ghost_speed", 400.0);
    SP_GhostDamage[clientIdx] = ability.GetFloat("ghost_damage", 15.0);
    SP_GhostDuration[clientIdx] = ability.GetFloat("ghost_duration", 15.0);
    SP_PortalDuration[clientIdx] = ability.GetFloat("portal_duration", 10.0);

    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);

    // Create portal
    int portal = CreateEntityByName("prop_dynamic_override");
    if (IsValidEntity(portal))
    {
        SetEntityModel(portal, "models/props_medieval/wooden_loom.mdl");
        DispatchSpawn(portal);
        TeleportEntity(portal, bossPos, NULL_VECTOR, NULL_VECTOR);

        // Attach particle effect to the portal
        AttachParticle(portal, "ghost_portal_effect", 0.0);

        // Play portal sound
        EmitSoundToAll("ambient/energy/zap1.wav", portal);

        // Store portal reference
        SP_PortalRef[clientIdx] = EntIndexToEntRef(portal);

        // Create timer to spawn ghosts
        CreateTimer(0.1, Timer_SpawnGhosts, clientIdx, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

        // Create timer to remove portal after duration
        CreateTimer(SP_PortalDuration[clientIdx], Timer_RemovePortal, clientIdx);
    }
}

public Action Timer_SpawnGhosts(Handle timer, int clientIdx)
{
    int portal = EntRefToEntIndex(SP_PortalRef[clientIdx]);
    if (!IsValidEntity(portal))
    {
        return Plugin_Stop;
    }

    float portalPos[3];
    GetEntPropVector(portal, Prop_Data, "m_vecOrigin", portalPos);

    for (int i = 0; i < SP_GhostCount[clientIdx]; i++)
    {
        CreateGhost(portalPos, clientIdx);
    }

    return Plugin_Continue;
}

public void CreateGhost(float pos[3], int clientIdx)
{
    int ghost = CreateEntityByName("tf_zombie");
    if (IsValidEntity(ghost))
    {
        DispatchSpawn(ghost);
        TeleportEntity(ghost, pos, NULL_VECTOR, NULL_VECTOR);

        // Set ghost properties
        SetEntityModel(ghost, "models/player/ghost.mdl");
        SetEntProp(ghost, Prop_Data, "m_iHealth", 100);
        SetEntProp(ghost, Prop_Data, "m_iMaxHealth", 100);
        SetEntProp(ghost, Prop_Data, "m_takedamage", 0);

        // Set ghost speed
        TF2Attrib_SetByName(ghost, "move speed bonus", SP_GhostSpeed[clientIdx] / 300.0);

        // Attach particle effect to the ghost
        AttachParticle(ghost, "ghost_trail", 0.0);

        // Store ghost reference
        SP_GhostsRef[clientIdx][ghost] = EntIndexToEntRef(ghost);

        // Create timer to handle ghost behavior
        CreateTimer(0.1, Timer_GhostBehavior, EntIndexToEntRef(ghost), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_GhostBehavior(Handle timer, int ref)
{
    int ghost = EntRefToEntIndex(ref);
    if (!IsValidEntity(ghost))
    {
        return Plugin_Stop;
    }

    float ghostPos[3];
    GetEntPropVector(ghost, Prop_Data, "m_vecOrigin", ghostPos);

    // Find nearest player
    int target = GetNearestPlayer(ghostPos, ghost);
    if (IsValidClient(target))
    {
        float targetPos[3];
        GetClientAbsOrigin(target, targetPos);

        // Move towards the target
        float direction[3];
        SubtractVectors(targetPos, ghostPos, direction);
        NormalizeVector(direction, direction);
        ScaleVector(direction, SP_GhostSpeed[clientIdx]);
        TeleportEntity(ghost, NULL_VECTOR, NULL_VECTOR, direction);

        // Damage the target
        float distance = GetVectorDistance(ghostPos, targetPos);
        if (distance <= 100.0)
        {
            SDKHooks_TakeDamage(target, ghost, ghost, SP_GhostDamage[clientIdx], DMG_SLASH);
            EmitSoundToAll("ambient/energy/zap7.wav", ghost);
        }
    }

    return Plugin_Continue;
}

public Action Timer_RemovePortal(Handle timer, int clientIdx)
{
    int portal = EntRefToEntIndex(SP_PortalRef[clientIdx]);
    if (IsValidEntity(portal))
    {
        AcceptEntityInput(portal, "Kill");
    }

    return Plugin_Stop;
}

public int GetNearestPlayer(float pos[3], int excludeEntity)
{
    int nearestPlayer = -1;
    float nearestDistance = INACTIVE;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && i != excludeEntity)
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            float distance = GetVectorDistance(pos, playerPos);

            if (distance < nearestDistance)
            {
                nearestPlayer = i;
                nearestDistance = distance;
            }
        }
    }

    return nearestPlayer;
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

stock void AttachParticle(int entity, const char[] particleName, float offset = 0.0)
{
    int particle = CreateEntityByName("info_particle_system");
    if (IsValidEntity(particle))
    {
        float pos[3];
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
        pos[2] += offset;
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);

        DispatchKeyValue(particle, "effect_name", particleName);
        DispatchSpawn(particle);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "Start");

        SetVariantString("!activator");
        AcceptEntityInput(particle, "SetParent", entity);
    }
}

stock void PrecacheParticle(const char[] particleName)
{
    int particle = CreateEntityByName("info_particle_system");
    if (IsValidEntity(particle))
    {
        DispatchKeyValue(particle, "effect_name", particleName);
        DispatchSpawn(particle);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "Start");
        AcceptEntityInput(particle, "Kill");
    }
}