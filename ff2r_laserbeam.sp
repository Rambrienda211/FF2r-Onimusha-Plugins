/*
    "rage_laserbeam"    // Ability name can use suffixes
    {
        "slot"                  "0"                     // Ability slot
        "tickrate"              "1"                     // Tickrate (don't change this)
        "delay"                 "0.0"                   // Delay before shooting the beam
        "duration"              "1.0"                   // Duration in seconds
        "max_distance"          "1000.0"                // Max distance in hammer units (HU)
        "beam_radius"           "4.0"                   // Beam radius in hammer units
        "beam_x"                "2.0"                   // Beam X position
        "beam_z"                "2.0"                   // Beam Z position
        "beam_y"                "17.5"                  // Beam Y position
        "beam_color_r"          "255"                   // Beam RED color
        "beam_color_g"          "125"                   // Beam GREEN color
        "beam_color_b"          "80"                    // Beam BLUE color
        "beam_alpha"            "125"                   // Beam ALPHA value (0 = invis, 255 = fully visible)
        "exp_range"             "100.0"                 // Explosion range
        "min_damage"            "5.0"                   // Minimum damage that the laser can deal
        "max_damage"            "5.0"                   // Maximum damage that the laser can deal
        "min_building_damage"   "10.0"                  // Minimum damage to buildings
        "max_building_damage"   "20.0"                  // Maximum damage to buildings
        
        "plugin_name"           "ff2r_laserbeam"
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

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Laser Beam"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "Laser beam ability for FF2R"

#define MAJOR_REVISION "1"
#define MINOR_REVISION "0"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL ""

#define MAXTF2PLAYERS 36
#define INACTIVE 100000000.0

float LB_TickRate[MAXTF2PLAYERS];
float LB_Delay[MAXTF2PLAYERS];
float LB_Duration[MAXTF2PLAYERS];
float LB_MaxDistance[MAXTF2PLAYERS];
float LB_BeamRadius[MAXTF2PLAYERS];
float LB_BeamX[MAXTF2PLAYERS];
float LB_BeamZ[MAXTF2PLAYERS];
float LB_BeamY[MAXTF2PLAYERS];
int LB_BeamColorR[MAXTF2PLAYERS];
int LB_BeamColorG[MAXTF2PLAYERS];
int LB_BeamColorB[MAXTF2PLAYERS];
int LB_BeamAlpha[MAXTF2PLAYERS];
float LB_ExpRange[MAXTF2PLAYERS];
float LB_MinDamage[MAXTF2PLAYERS];
float LB_MaxDamage[MAXTF2PLAYERS];
float LB_MinBuildingDamage[MAXTF2PLAYERS];
float LB_MaxBuildingDamage[MAXTF2PLAYERS];

float LB_StartTime[MAXTF2PLAYERS];
bool LB_IsActive[MAXTF2PLAYERS];

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
    // Precache the laser beam sprite
    PrecacheModel("sprites/laser.vmt");
}

public void OnClientPutInServer(int clientIdx)
{
    LB_IsActive[clientIdx] = false;
}

public void OnPluginEnd()
{
    for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
    {
        SDKUnhook(clientIdx, SDKHook_PreThink, LaserBeam_PreThink);
    }
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
    if(!cfg.IsMyPlugin())    
        return;
    
    if(!StrContains(ability, "rage_laserbeam", false))
    {
        Ability_LaserBeam(clientIdx, ability, cfg);
    }
}

public void Ability_LaserBeam(int clientIdx, const char[] ability_name, AbilityData ability)
{
    LB_TickRate[clientIdx] = ability.GetFloat("tickrate", 1.0);
    LB_Delay[clientIdx] = ability.GetFloat("delay", 0.0);
    LB_Duration[clientIdx] = ability.GetFloat("duration", 1.0);
    LB_MaxDistance[clientIdx] = ability.GetFloat("max_distance", 1000.0);
    LB_BeamRadius[clientIdx] = ability.GetFloat("beam_radius", 4.0);
    LB_BeamX[clientIdx] = ability.GetFloat("beam_x", 2.0);
    LB_BeamZ[clientIdx] = ability.GetFloat("beam_z", 2.0);
    LB_BeamY[clientIdx] = ability.GetFloat("beam_y", 17.5);
    LB_BeamColorR[clientIdx] = ability.GetInt("beam_color_r", 255);
    LB_BeamColorG[clientIdx] = ability.GetInt("beam_color_g", 125);
    LB_BeamColorB[clientIdx] = ability.GetInt("beam_color_b", 80);
    LB_BeamAlpha[clientIdx] = ability.GetInt("beam_alpha", 125);
    LB_ExpRange[clientIdx] = ability.GetFloat("exp_range", 100.0);
    LB_MinDamage[clientIdx] = ability.GetFloat("min_damage", 5.0);
    LB_MaxDamage[clientIdx] = ability.GetFloat("max_damage", 5.0);
    LB_MinBuildingDamage[clientIdx] = ability.GetFloat("min_building_damage", 10.0);
    LB_MaxBuildingDamage[clientIdx] = ability.GetFloat("max_building_damage", 20.0);

    LB_StartTime[clientIdx] = GetGameTime() + LB_Delay[clientIdx];
    LB_IsActive[clientIdx] = true;
    SDKHook(clientIdx, SDKHook_PreThink, LaserBeam_PreThink);
}

public void LaserBeam_PreThink(int clientIdx)
{
    if (!LB_IsActive[clientIdx] || !IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx))
    {
        SDKUnhook(clientIdx, SDKHook_PreThink, LaserBeam_PreThink);
        LB_IsActive[clientIdx] = false;
        return;
    }

    float currentTime = GetGameTime();
    if (currentTime < LB_StartTime[clientIdx])
        return;

    if (currentTime >= LB_StartTime[clientIdx] + LB_Duration[clientIdx])
    {
        SDKUnhook(clientIdx, SDKHook_PreThink, LaserBeam_PreThink);
        LB_IsActive[clientIdx] = false;
        return;
    }

    
    float beamStart[3], beamEnd[3];
    GetClientEyePosition(clientIdx, beamStart);
    GetClientEyeAngles(clientIdx, beamEnd);

    
    beamStart[0] += LB_BeamX[clientIdx];
    beamStart[1] += LB_BeamY[clientIdx];
    beamStart[2] += LB_BeamZ[clientIdx];

    
    float direction[3];
    GetAngleVectors(beamEnd, direction, NULL_VECTOR, NULL_VECTOR);
    beamEnd[0] = beamStart[0] + (direction[0] * LB_MaxDistance[clientIdx]);
    beamEnd[1] = beamStart[1] + (direction[1] * LB_MaxDistance[clientIdx]);
    beamEnd[2] = beamStart[2] + (direction[2] * LB_MaxDistance[clientIdx]);

   
    int colors[4];
    colors[0] = LB_BeamColorR[clientIdx];
    colors[1] = LB_BeamColorG[clientIdx];
    colors[2] = LB_BeamColorB[clientIdx];
    colors[3] = LB_BeamAlpha[clientIdx];
    TE_SetupBeamPoints(beamStart, beamEnd, PrecacheModel("sprites/laser.vmt"), 0, 0, 0, LB_TickRate[clientIdx], LB_BeamRadius[clientIdx], LB_BeamRadius[clientIdx], 0, 0.0, colors, 0);
    TE_SendToAll();

    // Damage entities in the beam's path
    Handle trace = TR_TraceRayFilterEx(beamStart, beamEnd, MASK_SHOT, RayType_EndPoint, TraceFilterIgnoreSelf, clientIdx);
    if (TR_DidHit(trace))
    {
        int hitEntity = TR_GetEntityIndex(trace);
        if (IsValidClient(hitEntity) || IsValidEntity(hitEntity))
        {
            float damage = GetRandomFloat(LB_MinDamage[clientIdx], LB_MaxDamage[clientIdx]);
            if (IsValidClient(hitEntity) && GetClientTeam(hitEntity) != GetClientTeam(clientIdx))
            {
                SDKHooks_TakeDamage(hitEntity, clientIdx, clientIdx, damage, DMG_ENERGYBEAM);
            }
            else if (IsValidBuilding(hitEntity))
            {
                damage = GetRandomFloat(LB_MinBuildingDamage[clientIdx], LB_MaxBuildingDamage[clientIdx]);
                SDKHooks_TakeDamage(hitEntity, clientIdx, clientIdx, damage, DMG_ENERGYBEAM);
            }
        }
    }
    delete trace;
}

public bool TraceFilterIgnoreSelf(int entity, int contentsMask, int clientIdx)
{
    return entity != clientIdx;
}

public bool IsValidBuilding(int entity)
{
    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrContains(classname, "obj_") == 0;
}

public void FF2R_OnBossRemoved(int clientIdx)
{
    SDKUnhook(clientIdx, SDKHook_PreThink, LaserBeam_PreThink);
    LB_IsActive[clientIdx] = false;
}

stock bool IsValidClient(int clientIdx, bool replaycheck=true)
{
    if(clientIdx <= 0 || clientIdx > MaxClients)
        return false;

    if(!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
        return false;

    if(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
        return false;

    if(replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
        return false;

    return true;
}

