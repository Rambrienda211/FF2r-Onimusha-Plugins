/*
"arrow_change"
{
    "slot"           "0"
    "classname"      "tf_weapon_compound_bow"
    "attributes"     "2 ; 3.0 ; 6 ; 0.5 ; 37 ; 0.0"
    "poison_arrow"   "true"
    "fire_arrow"     "true"
    "slow_arrow"     "false"
    "rocket_arrow"   "false"
    "clip"           "1"
    "ammo"           "2"
    "index"          "1005"

    "plugin_name"    "ff2r_cbs_arrows"
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
#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Custom Arrows"
#define PLUGIN_AUTHOR  "Onimusha (Ulepszony przez Pomocnika)"
#define PLUGIN_DESC    "Custom arrow types with visual effects for FF2R"
#define MAJOR_REVISION "1"
#define MINOR_REVISION "1"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION
#define PLUGIN_URL ""

#define MAXTF2PLAYERS 36

// Globalne zmienne
bool g_bPoisonArrow[MAXTF2PLAYERS];
bool g_bFireArrow[MAXTF2PLAYERS];
bool g_bSlowArrow[MAXTF2PLAYERS];
bool g_bRocketArrow[MAXTF2PLAYERS];
int g_iClip[MAXTF2PLAYERS];
int g_iAmmo[MAXTF2PLAYERS];
int g_iIndex[MAXTF2PLAYERS];

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
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void OnClientPutInServer(int clientIdx)
{
    g_bPoisonArrow[clientIdx] = false;
    g_bFireArrow[clientIdx] = false;
    g_bSlowArrow[clientIdx] = false;
    g_bRocketArrow[clientIdx] = false;
    g_iClip[clientIdx] = 1;
    g_iAmmo[clientIdx] = 2;
    g_iIndex[clientIdx] = 1005; // Default Huntsman index
}

public Action FF2R_OnPickupDroppedWeapon(int client, int weapon)
{
    // Equip the boss with the Huntsman
    int bow = SpawnWeapon(client, "tf_weapon_compound_bow", 1005, 101, 5, "2 ; 3.0 ; 6 ; 0.5 ; 37 ; 0.0");
    if (IsValidEntity(bow))
    {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", bow);
    }
    return Plugin_Continue;
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
    if (!cfg.IsMyPlugin())    
        return;

    // Obsługa arrow_change
    if (StrEqual(ability, "arrow_change"))
    {
        Ability_ArrowChange(clientIdx, ability, cfg);
    }

    // Obsługa boss_rage
    if (StrEqual(ability, "boss_rage"))
    {
        HandleBossRage(clientIdx);
    }
}

public void HandleBossRage(int clientIdx)
{
    // Sprawdź, czy boss już ma łuk
    int weapon = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
    if (!IsValidEntity(weapon))
    {
        // Jeśli nie ma, twó utwórz nowy łuk
        SpawnBossBow(clientIdx);
    }
}

stock void SpawnBossBow(int clientIdx)
{
    // Tworzymy łuk Huntsmana dla bossa
    int bow = CreateEntityByName("tf_weapon_compound_bow");
    if (!IsValidEntity(bow))
    {
        LogError("[FF2R] Nie udało się utworzyć łuku dla bossa!");
        return;
    }

    // Ustawiamy właściwości łuku
    SetEntProp(bow, Prop_Send, "m_iItemDefinitionIndex", 1005); // Index Huntsmana
    SetEntProp(bow, Prop_Send, "m_bInitialized", 1);
    SetEntProp(bow, Prop_Send, "m_iEntityLevel", 101); // Poziom przedmiotu
    SetEntProp(bow, Prop_Send, "m_iEntityQuality", 5); // Jakość
    SetEntProp(bow, Prop_Send, "m_iClip1", 1); // Rozmiar magazynka

    // Dodajemy atrybuty (opcjonalnie)
    TF2Items_SetAttribute(bow, 0, 2, 3.0); // Przykład atrybutu
    TF2Items_SetAttribute(bow, 1, 6, 0.5); // Przykład atrybutu
    TF2Items_SetAttribute(bow, 2, 37, 0.0); // Przykład atrybutu

    DispatchSpawn(bow);

    // Ekwipujemy bossa
    EquipPlayerWeapon(clientIdx, bow);
    SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", bow);

    // Informacja w konsoli
    PrintToServer("[FF2R] Boss %d otrzymał łuk Huntsmana!", clientIdx);
}

public void Ability_ArrowChange(int clientIdx, const char[] ability_name, AbilityData ability)
{
    g_bPoisonArrow[clientIdx] = ability.GetBool("poison_arrow", false);
    g_bFireArrow[clientIdx] = ability.GetBool("fire_arrow", false);
    g_bSlowArrow[clientIdx] = ability.GetBool("slow_arrow", false);
    g_bRocketArrow[clientIdx] = ability.GetBool("rocket_arrow", false);
    g_iClip[clientIdx] = ability.GetInt("clip", 1);
    g_iAmmo[clientIdx] = ability.GetInt("ammo", 2);
    g_iIndex[clientIdx] = ability.GetInt("index", 1005); // Default Huntsman index

    int weapon = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
    if (IsValidEntity(weapon))
    {
        char classname[64];
        GetEntityClassname(weapon, classname, sizeof(classname));
        if (StrEqual(classname, "tf_weapon_compound_bow"))
        {
            SetEntProp(weapon, Prop_Send, "m_iClip1", g_iClip[clientIdx]);
            SetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", g_iAmmo[clientIdx]);
            SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_iIndex[clientIdx]);
        }
    }

    SDKHook(clientIdx, SDKHook_PreThink, ArrowChange_PreThink);
}

public void ArrowChange_PreThink(int clientIdx)
{
    if (!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx))
    {
        SDKUnhook(clientIdx, SDKHook_PreThink, ArrowChange_PreThink);
        return;
    }

    int weapon = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
    if (IsValidEntity(weapon))
    {
        char classname[64];
        GetEntityClassname(weapon, classname, sizeof(classname));
        if (StrEqual(classname, "tf_weapon_compound_bow") && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == g_iIndex[clientIdx])
        {
            ApplyArrowEffects(clientIdx);
        }
    }
}

public void ApplyArrowEffects(int clientIdx)
{
    if (g_bPoisonArrow[clientIdx])
    {
        SDKTools_EmitSound(clientIdx, "Player.Poisoned"); // Dźwięk trucizny
        CreateParticleEffect(clientIdx, "jarate_hit"); // Efekt wizualny trucizny
    }

    if (g_bFireArrow[clientIdx])
    {
        SDKTools_EmitSound(clientIdx, "Weapon_FlameThrower.Ignite"); // Dźwięk ognia
        CreateParticleEffect(clientIdx, "burning_embers"); // Efekt wizualny ognia
    }

    if (g_bSlowArrow[clientIdx])
    {
        SDKTools_EmitSound(clientIdx, "Player.Slowed"); // Dźwięk spowolnienia
        CreateParticleEffect(clientIdx, "slow_effect"); // Efekt wizualny spowolnienia
    }

    if (g_bRocketArrow[clientIdx])
    {
        SDKTools_EmitSound(clientIdx, "Weapon_RocketLauncher.Shoot"); // Dźwięk rakiety
        CreateParticleEffect(clientIdx, "rocket_trail"); // Efekt wizualny rakiety
    }
}

public void CreateParticleEffect(int clientIdx, const char[] effectName)
{
    float pos[3];
    GetClientEyePosition(clientIdx, pos);
    SDKTools_CreateParticleEffect(effectName, pos[0], pos[1], pos[2]);
}

public Action OnRocketTouch(int entity, int other)
{
    int clientIdx = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if (IsValidClient(other) && GetClientTeam(clientIdx) != GetClientTeam(other))
    {
        SDKHooks_TakeDamage(other, clientIdx, clientIdx, 300.0, DMG_BLAST, entity);

        // Dźwięk wybuchu
        SDKTools_EmitSound(entity, "Weapon_RocketLauncher.Explode");

        // Efekt wybuchu
        float pos[3];
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
        SDKTools_CreateParticleEffect("rocket_explosion", pos[0], pos[1], pos[2]);
    }

    RemoveEntity(entity);
    return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int clientIdx = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(clientIdx))
    {
        g_bPoisonArrow[clientIdx] = false;
        g_bFireArrow[clientIdx] = false;
        g_bSlowArrow[clientIdx] = false;
        g_bRocketArrow[clientIdx] = false;
    }
}

public void FF2R_OnBossRemoved(int clientIdx)
{
    SDKUnhook(clientIdx, SDKHook_PreThink, ArrowChange_PreThink);
    g_bPoisonArrow[clientIdx] = false;
    g_bFireArrow[clientIdx] = false;
    g_bSlowArrow[clientIdx] = false;
    g_bRocketArrow[clientIdx] = false;
}

stock bool IsValidClient(int clientIdx, bool replaycheck=true)
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

stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, char[] att)
{
    int weapon = CreateEntityByName(name);
    if (!IsValidEntity(weapon))
        return -1;

    SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", index);
    SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
    SetEntProp(weapon, Prop_Send, "m_iEntityLevel", level);
    SetEntProp(weapon, Prop_Send, "m_iEntityQuality", qual);
    SetEntProp(weapon, Prop_Send, "m_iClip1", 1);

    if (strlen(att) > 0)
    {
        char attr[128];
        int count = SplitString(att, ";", attr, sizeof(attr));
        for (int i = 0; i < count; i += 3)
        {
            int defindex = StringToFloat(attr[i]);
            float value = StringToFloat(attr[i + 1]);
            TF2Items_SetAttribute(weapon, i / 3, defindex, value);
        }
    }

    DispatchSpawn(weapon);
    EquipPlayerWeapon(client, weapon);
    return weapon;
}