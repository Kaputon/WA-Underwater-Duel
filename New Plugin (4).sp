#pragma semicolon 1
#pragma tabsize 0

#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "0.00"
#define MAX_PLAYERS 32


public Plugin myinfo = {
	name = "Wrap Assassin Underwater Duel", 
	author = "Kaputon", 
	description = "N/A", 
	version = PLUGIN_VERSION, 
	url = ""
};

#define ROUNDS 3
#define WIN_SOUND "Passtime.Crowd.Cheer"
#define SOUND_START "Item.Materialize"

// x : (272, -267) , y: -1464, z: 81

int QUEUE[2];
int SCORE[2] = {0, 0};
bool RED_BLUE[2] = {false, false}; // Participants must be on opposing teams.
//
float MGE_POS1[3] = {98.8, -1464.0, 81.0};
float MGE_POS2[3] = {-98.8, -1464.0, 81.0};
//
float MGE_ANG1[3] = { 0.0, 180.0, 0.0 };
float MGE_ANG2[3] = {0.0, 360.0, 0.0};
float MGE_VEL[3] = {0.0, 0.0, 0.0};
//
char VALID_MELEE[] = "tf_weapon_bat_giftwrap";
bool GAME_READY = false;
bool ONGOING = false;
bool FIRST_TIMER = false;
//bool DEBUG_MODE = false;

public void OnPluginStart()
{
	PrintToServer("[SM] Underwater WA Plugin began.");
	RegConsoleCmd("duel", DuelLogic, "Begins the Duel Logic.");
	RegConsoleCmd("cpuduel", CPU_Duel, "Testing logic.");
}

public void OnMapStart()
{
	PrecacheScriptSound(SOUND_START);
	PrecacheScriptSound(WIN_SOUND);
}

public Action CPU_Duel(int client, int args)
{
	char NAME[32];
	for (int i = 1; i < 24; i++)
	{
		if (i != client)
		{
			GetClientName(i, NAME, sizeof(NAME));
			int TEAM = GetClientTeam(i);
			if(TEAM == 4)
			{
				RED_BLUE[0] = true;
			}
			if(TEAM == 3)
			{
				RED_BLUE[1] = true;
			}
			
			for (int a = 0; a < sizeof(QUEUE); a++)
			{
				if (QUEUE[a] == 0)
				{
					QUEUE[a] = i;
					PrintToChatAll("[SM] CPU Added to duel.");
					break;
				}
			}
			break;
		}
	}
	if (QFull())
	{
		GAME_READY = true;
	}
	return Plugin_Continue;
}

public Action DuelLogic(int client, int args)
{
	if (FIRST_TIMER == false)
	{
		FIRST_TIMER = true;
		CreateTimer(0.1, Timer_Setup, _, TIMER_REPEAT);
	}
	
	if (ONGOING)
	{
		ReplyToCommand(client, "[SM] There is currently an ongoing game, please wait until it is finished.");
		return Plugin_Stop;
	}
	
	if (!Is_WA_Scout(client)) // Check if the player is the valid class and weapon to play.
	{
		ReplyToCommand(client, "[SM] You must be Scout with the Wrap Assassin equipped to play.");
		return Plugin_Stop;
	}
	
	AddToQ(client);
	
	return Plugin_Handled;
}

bool Is_WA_Scout(int client) // <bool> : Check for valid class and weapon.
{
	char str_melee[32]; // Name of the invoking client's melee weapon.
	TFClassType cl_class = TF2_GetPlayerClass(client); // Class the invoking client is playing
	
	GetEdictClassname(GetPlayerWeaponSlot(client, TFWeaponSlot_Melee), str_melee, sizeof(str_melee)); // Get the STR of the player's melee and store it in str_melee
	
	if (cl_class == TFClass_Scout && StrEqual(str_melee, VALID_MELEE))
	{
		return true;
	}
	return false;
}

bool QFull() // <bool> Detects if the Queue is full.
{
	bool full = true;
	for (int i = 0; i < sizeof(QUEUE); i++)
	{
		if (QUEUE[i] == 0)
		{
			full = false;
		}
	}
	return full;
}

Action AddToQ(int client) // <void> : Add invoking client to queue
{
	// Team check. We cannot let two teammates fight each other.
	int CLIENT_TEAM = GetClientTeam(client); // 3 = Blu ; 4 = Red
	
	// Red Team Check
	if (CLIENT_TEAM == 4 && RED_BLUE[0] == true)
	{
		ReplyToCommand(client, "[SM] Red Team already has a player in queue.");
		return Plugin_Stop;
	}
	
	// Blu Team Check
	if (CLIENT_TEAM == 3 && RED_BLUE[1] == true)
	{
		ReplyToCommand(client, "[SM] Blu Team already has a player in queue.");
		return Plugin_Stop;
	}
	
	// Queue check. Do not allow someone already in the queue to queue again.
	for (int i = 0; i < sizeof(QUEUE); i++)
	{
		if (QUEUE[i] == client)
		{
			ReplyToCommand(client, "[SM] You are already in the queue.");
			return Plugin_Stop;
		}
	}
	//
	
	// If the client is not in queue and the queue is not full, add them.
	if (!QFull())
	{
		for (int i = 0; i < sizeof(QUEUE); i++)
		{
			if (QUEUE[i] == 0)
			{
				QUEUE[i] = client;
				
				ReplyToCommand(client, "[SM] You have been added to the queue.");
				
				if(CLIENT_TEAM == 4) // if player is Red
				{
					RED_BLUE[0] = true;
				}
				if(CLIENT_TEAM == 3) // if player is Blu
				{
					RED_BLUE[1] = true;
				}
				break;
			}
		}
	}
	//
	
	// If the queue is full and the game ready flag has not been activated, set it to true.
	if (QFull())
	{
		GAME_READY = true;
	}
	//
	return Plugin_Continue;
}

void Teleport_Q() // <void> : Teleport Queue clients to position.
{
	TeleportEntity(QUEUE[0], MGE_POS1, MGE_ANG1, MGE_VEL);
	TeleportEntity(QUEUE[1], MGE_POS2, MGE_ANG2, MGE_VEL);
	EmitGameSoundToAll(SOUND_START, QUEUE[0]);
}

void Toggle_Freeze(bool toggle) // <void> : Toggle freeze clients.
{
	MoveType value;
	if (toggle == true) // True = Freeze
	{
		value = MOVETYPE_NONE;
	}
	else if (toggle == false) // False = Unfreeze
	{
		value = MOVETYPE_WALK;
	}
	
	for (int i = 0; i < sizeof(QUEUE); i++)
	{
		SetEntityMoveType(QUEUE[i], value);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) // <void> : Callback function for Death hook. Adjusts score.
{
	
	int PLR1 = QUEUE[0];
	int PLR2 = QUEUE[1];
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	char vicname[32];
	GetClientName(victim, vicname, sizeof(vicname));
	
	PrintToChatAll("Client #%d has died (%s).", victim, vicname);
	
	if(victim == PLR1)
	{
		SetEntityHealth(PLR2, 125);
		SCORE[1] += 1;
		PrintToChatAll("%d | %d", SCORE[0], SCORE[1]);
	}
	else if(victim == PLR2)
	{
		SetEntityHealth(PLR1, 125);
		SCORE[0] += 1;
		PrintToChatAll("%d | %d", SCORE[0], SCORE[1]);
	}
	
	CreateTimer(0.1, Timer_NewRound, _, TIMER_REPEAT);
}

public void Toggle_DeathHook(bool toggle) // <void> : Toggle Death Hook.
{
	if (toggle == true) // True = Hook Death
	{
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		PrintToChatAll("Death hooked.");
	}
	else if (toggle == false)
	{
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		PrintToChatAll("Death unhooked.");
	}
}


bool Is_Finished() // <bool> : Returns the state of the duel.
{
	for (int i = 0; i < sizeof(SCORE); i++)
	{
		if(SCORE[i] >= ROUNDS)
		{
			return true;
		}
	}
	return false;
}

void Game_Loop() // <void> : The main game loop.
{
	Teleport_Q();
	Toggle_Freeze(true);
	Toggle_DeathHook(true);
	//
	char PLR1[32], PLR2[32];
	
	// Get both of the participants names.
	GetClientName(QUEUE[0], PLR1, sizeof(PLR1));
	GetClientName(QUEUE[1], PLR2, sizeof(PLR2));
	// 
	
	PrintToChatAll("[SM] Underwater Wrap Assassin duel between %s and %s.", PLR1, PLR2);
	
	Toggle_Freeze(false);
	PrintToChatAll("...GO!");
	
	//
	
	CreateTimer(0.25, Timer_Stall, _, TIMER_REPEAT);
}

public Action Timer_Setup(Handle timer)
{
	if (GAME_READY)
	{
		PrintToConsoleAll("GAME_READY : True");
	}
	if (!GAME_READY)
	{
		PrintToConsoleAll("GAME_READY : False");
	}
	
	if (GAME_READY && !ONGOING)
	{
		ONGOING = true;
		Game_Loop();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_Stall(Handle timer)
{
	if (Is_Finished() == false)
	{
		PrintToConsoleAll("%d | %d", SCORE[0], SCORE[1]);
	}
	if (Is_Finished() == true)
	{
		//
		Teleport_Q();
		Toggle_Freeze(true);
		//
		
		char WIN[32];
		for (int i = 0; i < sizeof(SCORE); i++)
		{
			if (SCORE[i] >= ROUNDS)
			{
				GetClientName(QUEUE[i], WIN, sizeof(WIN));
				PrintToChatAll("%s wins! %d | %d", WIN, SCORE[0], SCORE[1]);
				EmitGameSoundToAll(WIN_SOUND, QUEUE[i]);
				break;
			}
		}
		
		Toggle_Freeze(false);
		Toggle_DeathHook(false);
		CleanUp();
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

void CleanUp()
{
	for (int i = 0; i < sizeof(QUEUE); i++)
	{
		QUEUE[i] = 0;
		SCORE[i] = 0;
		RED_BLUE[i] = false;
	}
	FIRST_TIMER = false;
	GAME_READY = false;
	ONGOING = false;
}

public Action Timer_NewRound(Handle timer) // <Timer> : This timer waits for the loser to respawn and reorients the players.
{
	if (!ONGOING) // If the timer is still going after the game ends. Terminate it.
	{
		return Plugin_Stop;
	}
	bool BOTH_ALIVE = true;
	for (int i = 0; i < sizeof(QUEUE); i++)
	{
		if(!IsPlayerAlive(QUEUE[i]))
		{
			BOTH_ALIVE = false;
		}
	}
	
	if (BOTH_ALIVE)
	{
		Teleport_Q();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}