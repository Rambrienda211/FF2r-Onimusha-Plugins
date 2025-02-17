/*
    "rage_gravity_wave"									// Ability name can use suffixes
    {
        "slot"                  "0"                     // Ability slot
        
        "duration"         		"5.0"                   // Duration
        "damage"                "50.0"                  // Damage dealt to players
        "radius"                "500.0"                 // Radius of the gravity wave
        "force"                 "750.0"                 // Knockback force
        "slow_multiplier"       "0.50"                  // Movement speed multiplier during slow

        "plugin_name"           "ff2r_gravity_wave"
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

#define PLUGIN_NAME 		"Freak Fortress 2 Rewrite: Gravity Wave"
#define PLUGIN_AUTHOR 		"Onimusha and Demo Samedi"
#define PLUGIN_DESC 		"Gravity wave ability for FF2R"

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

float GW_Duration[MAXTF2PLAYERS];
float GW_Damage[MAXTF2PLAYERS];
float GW_Radius[MAXTF2PLAYERS];
float GW_Force[MAXTF2PLAYERS];
float GW_SlowMultiplier[MAXTF2PLAYERS];

public void OnPluginStart()
{    
    PrecacheSound("weapons/physcannon/energy_sing_explosion2.wav");
    PrecacheModel("materials/sprites/strider_blackball.vmt");
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names
		return;
	
	if(!StrContains(ability, "rage_gravity_wave", false))
	{
		Ability_GravityWave(clientIdx, ability, cfg);
	}
}

public void Ability_GravityWave(int clientIdx, const char[] ability_name, AbilityData ability)
{
	GW_Duration[clientIdx] = ability.GetFloat("duration", 5.0);
	GW_Damage[clientIdx] = ability.GetFloat("damage", 50.0);
	GW_Radius[clientIdx] = ability.GetFloat("radius", 500.0);
	GW_Force[clientIdx] = ability.GetFloat("force", 750.0);
	GW_SlowMultiplier[clientIdx] = ability.GetFloat("slow_multiplier", 0.50);
	
	CreateGravityWave(clientIdx);
}

public void CreateGravityWave(int clientIdx)
{
    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);

    // Play sound effect
    EmitSoundToAll("weapons/physcannon/energy_sing_explosion2.wav", clientIdx);

    // Create particle effect
    TE_SetupBeamRingPoint(bossPos, 10.0, GW_Radius[clientIdx], PrecacheModel("materials/sprites/strider_blackball.vmt"), 0, 0, 10, 10.0, 10.0, 5.0, {255, 255, 255, 255}, 10, 0);
    TE_SendToAll();

    // Affect players in radius
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            float distance = GetVectorDistance(bossPos, playerPos);

            if (distance <= GW_Radius[clientIdx])
            {
                // Apply damage
                SDKHooks_TakeDamage(i, clientIdx, clientIdx, GW_Damage[clientIdx], DMG_BLAST);

                // Apply knockback
                float direction[3];
                SubtractVectors(playerPos, bossPos, direction);
                NormalizeVector(direction, direction);
                ScaleVector(direction, GW_Force[clientIdx]);
                TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, direction);

                // Apply slow effect
                TF2_AddCondition(i, TFCond_Slowed, GW_Duration[clientIdx]);
                TF2Attrib_SetByName(i, "move speed bonus", GW_SlowMultiplier[clientIdx]);
            }
        }
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