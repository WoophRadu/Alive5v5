#include<sourcemod>
#include<cstrike>

public Plugin myinfo =
{
	name = "Alive 5v5",
	author = "Wooph",
	description = "Alive's 5v5 custom competitive game plugin.",
	version = "0.1",
	url = "http://csgo.wooph.dev/"
};

enum struct Player
{
   int team; //1=spec, 2=T, 3=CT, 0 = none or unknown
   bool isReady; //are they ready?
}

int g_iT_LeaderID = 0;
int g_iCT_LeaderID = 0;
Player g_aPlayers[65];
int g_iReadyCount = 0;
bool g_bMatchStarted = false;
bool g_bKnifeRound = false;
bool g_bTimeToChooseSides = true;
CSRoundEndReason g_eKnifeRoundResult;

Handle g_h_mp_force_assign_teams = null;
Handle g_h_mp_force_pick_time = null;

public void OnPluginStart()
{   
	g_h_mp_force_assign_teams = FindConVar("mp_force_assign_teams");
	g_h_mp_force_pick_time = FindConVar("mp_force_pick_time");
	SetConVarBool(g_h_mp_force_assign_teams, true);
	SetConVarInt(g_h_mp_force_pick_time, 0);
	
	for (int i = 0; i <= 64; i++){ //initialize players array with 0-team players
		g_aPlayers[i].team = 0;
		g_aPlayers[i].isReady = false;
	}
    PrintToServer("[Alive5v5] Plugin loaded.");
    RegConsoleCmd("sm_ready", Command_Ready);
    RegConsoleCmd("sm_leader", Command_Leader);
    RegConsoleCmd("sm_stay", Command_Stay);
    RegConsoleCmd("sm_switch", Command_Switch);
    
    AddCommandListener(Command_JoinTeam, "jointeam");
}

public void OnClientDisconnect(int client) {
	RemovePlayer(client);
	if (g_bMatchStarted == true) return;
	ResetReadyStates();
	PrintToChatAll("> \x0E[Alive5v5] \x0F Someone disconnected. Ready states reset! (0/10)");
}

public void AddPlayer(int client) {
	 g_aPlayers[client].team = GetClientTeam(client);
	 g_aPlayers[client].isReady = false;
}
public void RemovePlayer(int client) {
		g_aPlayers[client].team = 0;
		g_aPlayers[client].isReady = false;
}

public bool PlayerInValidTeam(int client) {
	int teamId = GetClientTeam(client);
	if( !(teamId== 2 || teamId== 3 ) ) {
		return false;
	}
	return true;
}

public void ResetReadyStates() {
	for (int i = 0; i <= 64; i++) {
		g_aPlayers[i].isReady = false;
	}
	g_iReadyCount = 0;
}

public void BeginMatch() {
	g_bMatchStarted = true;
	g_bKnifeRound = true;
	//ServerCommand("mp_ct_default_secondary weapon_hkp2000");
	ServerCommand("mp_startmoney 0");
	ServerCommand("mp_ct_default_secondary \"\"");
	ServerCommand("mp_t_default_secondary \"\"");
	ServerCommand("mp_restartgame 1"); 
	ServerCommand("mp_warmup_end");
	PrintToChatAll("> \x0E[Alive5v5] \x05KNIFE ROUND - winning team decides which side to start on.");
}

public void BeginNormalRounds() {
	g_bKnifeRound = false;
	g_bTimeToChooseSides = false;
	ServerCommand("mp_startmoney 800");
	ServerCommand("mp_ct_default_secondary weapon_hkp2000");
	ServerCommand("mp_t_default_secondary weapon_glock");
	ServerCommand("mp_restartgame 1"); 
	ServerCommand("mp_warmup_end"); 
}

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason) {
	if(g_bKnifeRound == true) {
		g_bTimeToChooseSides = true
		g_bKnifeRound = false;
		g_eKnifeRoundResult = reason;
		if(g_eKnifeRoundResult == CSRoundEnd_TerroristWin) {
			PrintToChatAll("> \x0E[Alive5v5] \x09T \x05wins knife round. T leader, type \x10!stay \x05or \x10!switch \x05to choose team.");
		}
		if(g_eKnifeRoundResult == CSRoundEnd_CTWin) {
			PrintToChatAll("> \x0E[Alive5v5] \x0BCT \x05wins knife round. T leader, type \x10!stay \x05or \x10!switch \x05to choose team.");
		}
		
		ServerCommand("mp_warmup_start"); 
	}
}

public Action Command_Ready(int client, int argc)
{
	if (g_bMatchStarted == true) return Plugin_Handled;
	if( !PlayerInValidTeam(client) ) {
		PrintToChat(client, "\x0E[Alive5v5] \x0FYou must be in the T or CT team to be ready.");
		return Plugin_Handled;
	}
	int teamId = GetClientTeam(client);
	g_aPlayers[client].team = teamId;
	if(teamId == 2) {
		if(g_iT_LeaderID == 0) {
			PrintToChat(client, "> \x0E[Alive5v5] \x0FYou can't be ready, your team has no leader. Claim leadership with \x10!leader");
			return Plugin_Handled;
		}
	}
	if(teamId == 3) {
		if(g_iCT_LeaderID == 0) {
			PrintToChat(client, "> \x0E[Alive5v5] \x0FYou can't be ready, your team has no leader. Claim leadership with \x10!leader");
			return Plugin_Handled;
		}
	}
	if(g_aPlayers[client].isReady == true) {
		PrintToChat(client, "> \x0E[Alive5v5] \x0FYou're already ready!");
		return Plugin_Handled;
	}
	char cname[128];
	GetClientName(client, cname, sizeof(cname));
	AddPlayer(client);
	g_aPlayers[client].isReady = true;
	g_iReadyCount = g_iReadyCount + 1;
	PrintToChatAll("> \x0E[Alive5v5] \x10%s \x05from team %d is ready (%d/10).", cname, g_aPlayers[client].team, g_iReadyCount);
	if(g_iReadyCount == 10) { // !!! CHANGE TO ==10 FOR LIVE !!! @@@@@@@@@@
		BeginMatch();
	}
    return Plugin_Handled;
}

public Action Command_Leader(int client, int argc)
{
	if (g_bMatchStarted == true) return Plugin_Handled;
	int teamId = GetClientTeam(client);
	g_aPlayers[client].team = teamId;
	if( !PlayerInValidTeam(client) ) {
		PrintToChat(client, "> \x0E[Alive5v5] \x0FYou must be in the T or CT team to be leader.");
		return Plugin_Handled;
	}
	if(teamId == 2) {
		if(g_iT_LeaderID != 0) {
			char cName[128];
			GetClientName(g_iT_LeaderID, cName, sizeof(cName));
			PrintToChat(client, "> \x0E[Alive5v5] \x0FYou can't be \x09T \x0Fleader, because \x10%s \x0Fis already T leader.", cName);
			return Plugin_Handled;
		}
		else {
			char cName[128];
			GetClientName(client, cName, sizeof(cName));
			g_iT_LeaderID = client;
			PrintToChatAll("> \x0E[Alive5v5] \x10%s \x05is now \x09T \x05leader.", cName);
			return Plugin_Handled;
		}
	}
	if(teamId == 3) {
		if(g_iCT_LeaderID != 0) {
			char cName[128];
			GetClientName(g_iCT_LeaderID, cName, sizeof(cName));
			PrintToChat(client, "> \x0E[Alive5v5] \x0FYou can't be \x0BCT \x0Fleader, because \x10%s \x0Fis already CT leader.", cName);
			return Plugin_Handled;
		}
		else {
			char cName[128];
			GetClientName(client, cName, sizeof(cName));
			g_iCT_LeaderID = client;
			PrintToChatAll("> \x0E[Alive5v5] \x10%s \x05is now \x0BCT \x05leader.", cName);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
	
	
}

public Action Command_Stay(int client, int argc) {
	if(g_bMatchStarted == true && g_bTimeToChooseSides == true)
	{
		if(g_aPlayers[client].team == 2 && g_eKnifeRoundResult == CSRoundEnd_TerroristWin && g_iT_LeaderID == client) {
			BeginNormalRounds();
			return Plugin_Handled;
		}
		else if(g_aPlayers[client].team == 3 && g_eKnifeRoundResult == CSRoundEnd_CTWin && g_iCT_LeaderID == client) {
			BeginNormalRounds();
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

public Action Command_Switch(int client, int argc) {
	int aux;
	if(g_bMatchStarted == true && g_bTimeToChooseSides == true)
	{
		if(g_aPlayers[client].team == 2 && g_eKnifeRoundResult == CSRoundEnd_TerroristWin && g_iT_LeaderID == client) {
			aux = g_iT_LeaderID;
			g_iT_LeaderID = g_iCT_LeaderID;
			g_iCT_LeaderID = aux;
			ServerCommand("mp_swapteams");
			BeginNormalRounds();
			return Plugin_Handled;
		}
		else if(g_aPlayers[client].team == 3 && g_eKnifeRoundResult == CSRoundEnd_CTWin && g_iCT_LeaderID == client) {
			aux = g_iT_LeaderID;
			g_iT_LeaderID = g_iCT_LeaderID;
			g_iCT_LeaderID = aux;
			ServerCommand("mp_swapteams");
			BeginNormalRounds();
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}


public Action:Command_JoinTeam(int client, const String:command[], int args)
{    
	if (g_bMatchStarted == true) return Plugin_Continue;
    if (client != 0)
    {
        if(IsClientInGame(client) && !IsFakeClient(client))
        {
        	g_aPlayers[client].team = GetClientTeam(client);
			char cName[128];
			GetClientName(client, cName, sizeof(cName));
			if(g_iT_LeaderID == client) {
				g_iT_LeaderID = 0;
				PrintToChatAll("> \x0E[Alive5v5] \x09T \x0FLeader \x10%s\x0F swapped teams. He is no longer leader!", cName);
			}
			if(g_iCT_LeaderID == client) {
				g_iCT_LeaderID = 0;
				PrintToChatAll("> \x0E[Alive5v5] \x0BCT \x0FLeader \x10%s\x0F swapped teams. He is no longer leader!", cName);
			}
			ResetReadyStates();
			PrintToChatAll("> \x0E[Alive5v5] \x0FPlayer \x10%s\x0F swapped teams. Ready states reset! (0/10)", cName);
        }
    }

    return Plugin_Continue;
} 
