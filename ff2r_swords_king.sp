/*

"sword_aura"
{
    "slot"                "0"         // Slot umiejętności
    "duration"            "10.0"      // Czas trwania umiejętności (w sekundach)
    "radius"              "100.0"     // Promień, w jakim miecze krążą wokół bossa
    "sword_speed"         "2.0"       // Prędkość obrotu mieczy wokół bossa
    "sword_count"         "5.0"         // Liczba mieczy
    "damage"              "10.0"      // Obrażenia zadawane przez każdy miecz
    "model"               "models/weapons/c_models/c_claidheamohmor.mdl"
    
    "plugin_name"         "ff2r_swords_king"
  
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

#define PLUGIN_NAME    "FF2R Sword Aura"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "Sword Aura ability for FF2R"
#define PLUGIN_VERSION "1.0.0"

#define MAXTF2PLAYERS	MAXPLAYERS+1
#define MAX_SWORDS 10 // Maksymalna liczba mieczy

// Zmienne przechowujące dane umiejętności
float g_flDuration[MAXPLAYERS + 1];
float g_flRadius[MAXPLAYERS + 1];
float g_flSwordSpeed[MAXPLAYERS + 1];
int g_iSwordCount[MAXPLAYERS + 1];
float g_flDamage[MAXPLAYERS + 1];
char g_szModel[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

// Zmienne do zarządzania mieczami
int g_iSwords[MAXPLAYERS + 1][MAX_SWORDS];
float g_flSwordAngles[MAXPLAYERS + 1][MAX_SWORDS];

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version = PLUGIN_VERSION,
    url = "https://github.com/TwojRepozytorium"
};

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
    if (!StrEqual(ability, "sword_aura"))
        return;

    g_flDuration[client] = cfg.GetFloat("duration", 10.0);
    g_flRadius[client] = cfg.GetFloat("radius", 100.0);
    g_flSwordSpeed[client] = cfg.GetFloat("sword_speed", 2.0);
    g_iSwordCount[client] = cfg.GetInt("sword_count", 5);
    g_flDamage[client] = cfg.GetFloat("damage", 10.0);
    cfg.GetString("model", g_szModel[client], sizeof(g_szModel[]), "models/weapons/c_models/c_claidheamohmor.mdl");

    if (g_iSwordCount[client] > MAX_SWORDS)
        g_iSwordCount[client] = MAX_SWORDS;

    CreateSwords(client);
    CreateTimer(0.05, Timer_ManageSwords, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // Częstszy timer dla płynności
    CreateTimer(g_flDuration[client], Timer_EndAbility, client);
}

public Action Timer_ManageSwords(Handle timer, int client)
{
    if (!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    float bossPos[3];
    GetClientAbsOrigin(client, bossPos);

    for (int i = 0; i < g_iSwordCount[client]; i++)
    {
        if (!IsValidEntity(g_iSwords[client][i]))
            continue;

        // Aktualizacja kąta obrotu miecza
        g_flSwordAngles[client][i] += g_flSwordSpeed[client];
        if (g_flSwordAngles[client][i] > 360.0)
            g_flSwordAngles[client][i] -= 360.0;

        // Obliczenie pozycji miecza
        float swordPos[3];
        swordPos[0] = bossPos[0] + g_flRadius[client] * Cosine(DegToRad(g_flSwordAngles[client][i]));
        swordPos[1] = bossPos[1] + g_flRadius[client] * Sine(DegToRad(g_flSwordAngles[client][i]));
        swordPos[2] = bossPos[2] + 50.0;

        // Ustawienie pozycji miecza
        TeleportEntity(g_iSwords[client][i], swordPos, NULL_VECTOR, NULL_VECTOR);

        // Skierowanie miecza w stronę najbliższego przeciwnika
        int target = FindClosestEnemy(client, swordPos);
        if (target != -1)
        {
            float targetPos[3];
            GetClientAbsOrigin(target, targetPos);

            float direction[3];
            SubtractVectors(targetPos, swordPos, direction);
            NormalizeVector(direction, direction);

            float angles[3];
            GetVectorAngles(direction, angles);

            TeleportEntity(g_iSwords[client][i], NULL_VECTOR, angles, NULL_VECTOR);
        }

        // Sprawdzenie kolizji
        CheckSwordCollision(client, g_iSwords[client][i]);
    }
    return Plugin_Continue;
}

public Action Timer_EndAbility(Handle timer, int client)
{
    if (IsClientValid(client))
        DestroySwords(client);
    return Plugin_Stop;
}

void CreateSwords(int client)
{
    PrecacheModel(g_szModel[client]);

    for (int i = 0; i < g_iSwordCount[client]; i++)
    {
        g_iSwords[client][i] = CreateEntityByName("prop_dynamic_override");
        if (g_iSwords[client][i] != -1)
        {
            SetEntityModel(g_iSwords[client][i], g_szModel[client]);
            DispatchSpawn(g_iSwords[client][i]);
            g_flSwordAngles[client][i] = 360.0 / g_iSwordCount[client] * i;
        }
        else
        {
            PrintToConsole(client, "Failed to create sword entity.");
        }
    }
}

void DestroySwords(int client)
{
    for (int i = 0; i < g_iSwordCount[client]; i++)
    {
        if (IsValidEntity(g_iSwords[client][i]))
        {
            RemoveEntity(g_iSwords[client][i]);
            g_iSwords[client][i] = -1;
        }
    }
}

void CheckSwordCollision(int client, int sword)
{
    float swordPos[3];
    GetEntPropVector(sword, Prop_Data, "m_vecOrigin", swordPos);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientValid(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);

            // Debug: Sprawdzamy odległość
            float distance = GetVectorDistance(swordPos, playerPos);
            if (distance <= 50.0)
            {
                // Debug: Wypisujemy odległość
                PrintToConsole(client, "Sword hit player %d at distance %.2f", i, distance);

                // Zadanie obrażeń
                float damage = g_flDamage[client];  // Pozostajemy przy typie float

                // Zadawanie obrażeń
                SDKHooks_TakeDamage(i, client, client, damage, DMG_SLASH);
            }
        }
    }
}

int FindClosestEnemy(int client, float swordPos[3])
{
    int closestTarget = -1;
    float closestDistance = -1.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientValid(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float targetPos[3];
            GetClientAbsOrigin(i, targetPos);

            float distance = GetVectorDistance(swordPos, targetPos);
            if (closestDistance == -1.0 || distance < closestDistance)
            {
                closestDistance = distance;
                closestTarget = i;
            }
        }
    }

    return closestTarget;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsClientValid(client))
        DestroySwords(client);
}

bool IsClientValid(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}