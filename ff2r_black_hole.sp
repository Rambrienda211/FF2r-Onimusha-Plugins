/*
	"rage_black_hole"									// Ability name can use suffixes
	{
    	"slot"                  "0"                     // Ability slot
    	
    	"duration"              "10.0"                  // Duration of the black hole
    	"damage"                "25.0"                  // Damage per tick
    	"radius"                "500.0"                 // Radius of the black hole
    	"force"                 "1000.0"                // Pull force

    	"plugin_name"           "ff2r_black_hole"
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

#define PLUGIN_NAME 		"Freak Fortress 2 Rewrite: Black Hole"
#define PLUGIN_AUTHOR 		"Onimusha and Demo Samedi"
#define PLUGIN_DESC 		"Black hole ability for FF2R"

#define MAJOR_REVISION 		"1"
#define MINOR_REVISION 		"0"
#define STABLE_REVISION 	"0"
#define PLUGIN_VERSION 		MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS		MAXPLAYERS+1
#define INACTIVE			100000000.0

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

float BH_Duration[MAXTF2PLAYERS];
float BH_Damage[MAXTF2PLAYERS];
float BH_Radius[MAXTF2PLAYERS];
float BH_Force[MAXTF2PLAYERS];

public void OnPluginStart()
{    
    PrecacheSound("ambient/atmosphere/terrain_rumble1.wav");
    PrecacheModel("materials/sprites/strider_blackball.vmt");
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names
		return;
	
	if(!StrContains(ability, "rage_black_hole", false))
	{
		Ability_BlackHole(clientIdx, ability, cfg);
	}
}

public void Ability_BlackHole(int clientIdx, const char[] ability_name, AbilityData ability)
{
	BH_Duration[clientIdx] = ability.GetFloat("duration", 10.0);
	BH_Damage[clientIdx] = ability.GetFloat("damage", 25.0);
	BH_Radius[clientIdx] = ability.GetFloat("radius", 500.0);
	BH_Force[clientIdx] = ability.GetFloat("force", 1000.0);

	float bossPos[3];
	GetClientAbsOrigin(clientIdx, bossPos);

	CreateBlackHole(bossPos, clientIdx);
}

public void CreateBlackHole(float pos[3], int clientIdx)
{
    // Play sound effect
    EmitSoundToAll("ambient/atmosphere/terrain_rumble1.wav", clientIdx);

    // Create particle effect
    TE_SetupBeamRingPoint(pos, 10.0, BH_Radius[clientIdx], PrecacheModel("materials/sprites/strider_blackball.vmt"), 0, 0, 10, 10.0, 10.0, 5.0, {0, 0, 0, 255}, 10, 0);
    TE_SendToAll();

    // Create timer to handle black hole effects
    CreateTimer(0.1, Timer_BlackHole, clientIdx, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_BlackHole(Handle timer, int clientIdx)
{
    static float time[MAXTF2PLAYERS];
    time[clientIdx] += 0.1;

    if (time[clientIdx] >= BH_Duration[clientIdx])
    {
        time[clientIdx] = 0.0;
        return Plugin_Stop;
    }

    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);

    // Affect players in radius
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            float distance = GetVectorDistance(bossPos, playerPos);

            if (distance <= BH_Radius[clientIdx])
            {
                // Apply damage
                SDKHooks_TakeDamage(i, clientIdx, clientIdx, BH_Damage[clientIdx], DMG_ENERGYBEAM);

                // Apply pull effect
                float direction[3];
                SubtractVectors(bossPos, playerPos, direction);
                NormalizeVector(direction, direction);
                ScaleVector(direction, BH_Force[clientIdx]);
                TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, direction);

                // Kill players who get too close
                if (distance <= 50.0)
                {
                    SDKHooks_TakeDamage(i, clientIdx, clientIdx, 9999.0, DMG_ENERGYBEAM);
                }
            }
        }
    }

    // Affect buildings in radius
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "obj_*")) != -1)
    {
        if (IsValidEntity(entity))
        {
            float entityPos[3];
            GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityPos);
            float distance = GetVectorDistance(bossPos, entityPos);

            if (distance <= BH_Radius[clientIdx])
            {
                // Apply damage
                SDKHooks_TakeDamage(entity, clientIdx, clientIdx, BH_Damage[clientIdx], DMG_ENERGYBEAM);

                // Apply pull effect
                float direction[3];
                SubtractVectors(bossPos, entityPos, direction);
                NormalizeVector(direction, direction);
                ScaleVector(direction, BH_Force[clientIdx]);
                TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, direction);

                // Destroy buildings that get too close
                if (distance <= 50.0)
                {
                    AcceptEntityInput(entity, "Kill");
                }
            }
        }
    }

    return Plugin_Continue;
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