init()
{
	switch(game["allies"])
	{
		case "marines":
			precacheShader("mpflag_american");
		break;
	}
	game["strings"]["autobalance"] = &"MP_AUTOBALANCE_NOW";
	precacheShader("mpflag_russian");
	precacheShader("mpflag_spectator");
	precacheString(&"MP_AUTOBALANCE_NOW");
	precacheString(&"MP_AUTOBALANCE_NEXT_ROUND");
	precacheString(&"MP_AUTOBALANCE_SECONDS");

	if(getDvar("scr_teambalance") == "")
		setDvar("scr_teambalance", "0");
	
	level.teamBalance = getDvarInt("scr_teambalance");
	level.maxClients = getDvarInt("sv_maxclients");
	
	setPlayerModels();
	level.freeplayers = [];

	if(level.teamBased)
	{
		level thread onPlayerConnect();
		level thread updateTeamBalance();
		wait .15;
		level thread updatePlayerTimes();
	}
	else
	{
		level thread onFreePlayerConnect();
		wait .15;
		level thread updateFreePlayerTimes();
	}
}

onPlayerConnect()
{
	for(;;)
	{
		level waittill("connecting", player);
		player thread onJoinedTeam();
		player thread onJoinedSpectators();
		player thread trackPlayedTime();
	}
}

onFreePlayerConnect()
{
	for(;;)
	{
		level waittill("connecting", player);
		player thread trackFreePlayedTime();
	}
}

onJoinedTeam()
{
	self endon("disconnect");
	for(;;)
	{
		self waittill("joined_team");
		self logString("joined team: " + self.pers["team"]);
		self updateTeamTime();
	}
}

onJoinedSpectators()
{
	self endon("disconnect");
	for(;;)
	{
		self waittill("joined_spectators");
		self.pers["teamTime"] = undefined;
	}
}

trackPlayedTime()
{
	self endon("disconnect");
	self.timePlayed["allies"] = 0;
	self.timePlayed["axis"] = 0;
	self.timePlayed["free"] = 0;
	self.timePlayed["other"] = 0;
	self.timePlayed["total"] = 0;
	
	while(level.inPrematchPeriod)
		wait(0.05);

	for(;;)
	{
		if(game["state"] == "playing")
		{
			if(self.sessionteam == "allies")
			{
				self.timePlayed["allies"]++;
				self.timePlayed["total"]++;
			}
			else if(self.sessionteam == "axis")
			{
				self.timePlayed["axis"]++;
				self.timePlayed["total"]++;
			}
			else if(self.sessionteam == "spectator")
			{
				self.timePlayed["other"]++;
			}
		}
		wait (1.0);
	}
}

updatePlayerTimes()
{
	nextToUpdate = 0;
	for (;;)
	{
		nextToUpdate++;
		if(nextToUpdate >= level.players.size)
			nextToUpdate = 0;
		if(isDefined(level.players[nextToUpdate]))
			level.players[nextToUpdate] updatePlayedTime();
		wait(4.0);
	}
}

updatePlayedTime()
{
	if(self.timePlayed["allies"])
	{
		self maps\mp\gametypes\_persistence::statAdd("time_played_allies", self.timePlayed["allies"]);
		self maps\mp\gametypes\_persistence::statAdd("time_played_total", self.timePlayed["allies"]);
	}
	if(self.timePlayed["axis"])
	{
		self maps\mp\gametypes\_persistence::statAdd("time_played_opfor", self.timePlayed["axis"]);
		self maps\mp\gametypes\_persistence::statAdd("time_played_total", self.timePlayed["axis"]);
	}
	if(self.timePlayed["other"])
	{
		self maps\mp\gametypes\_persistence::statAdd("time_played_other", self.timePlayed["other"]);			
		self maps\mp\gametypes\_persistence::statAdd("time_played_total", self.timePlayed["other"]);
	}
	if(game["state"] == "postgame")
		return;

	self.timePlayed["allies"] = 0;
	self.timePlayed["axis"] = 0;
	self.timePlayed["other"] = 0;
}

updateTeamTime()
{
	if(game["state"] != "playing")
		return;
	self.pers["teamTime"] = getTime();
}

updateTeamBalanceDvar()
{
	for(;;)
	{
		teambalance = getdvarInt("scr_teambalance");
		if(level.teambalance != teambalance)
			level.teambalance = getdvarInt("scr_teambalance");
		wait 1;
	}
}

updateTeamBalance()
{
	level.teamLimit = level.maxclients / 2;
	level thread updateTeamBalanceDvar();
	wait .15;
	
	if(level.teamBalance && (level.roundLimit > 1 || (!level.roundLimit && level.scoreLimit != 1)))
	{
    	if(isDefined(game["BalanceTeamsNextRound"]))
    		iPrintLnbold(&"MP_AUTOBALANCE_NEXT_ROUND");

		// TODO: add or change
		level waittill("restarting");

		if(isDefined(game["BalanceTeamsNextRound"]))
		{
			level balanceTeams();
			game["BalanceTeamsNextRound"] = undefined;
		}
		else if(!getTeamBalance())
			game["BalanceTeamsNextRound"] = true;
	}
	else
	{
		level endon ("game_ended");
		for(;;)
		{
			if(level.teamBalance)
			{
				if(!getTeamBalance())
				{
					iPrintLnBold(&"MP_AUTOBALANCE_SECONDS", 15);
				    wait 15.0;

					if(!getTeamBalance())
						level balanceTeams();
				}
				wait 59.0;
			}
			wait 1.0;
		}
	}
}

getTeamBalance()
{
	AlliedPlayers = [];
	AxisPlayers = [];
    players = getEntArray("player", "classname");
	
	players = level.players;
	for(i = 0; i < players.size; i++) // Fills teams array
	{	
		if((isdefined(players[i].pers["team"])) && (players[i].pers["team"] == "allies"))
			AlliedPlayers[AlliedPlayers.size] = players[i];
		else if((isdefined(players[i].pers["team"])) && (players[i].pers["team"] == "axis"))
			AxisPlayers[AxisPlayers.size] = players[i];
	}
	
	if((AlliedPlayers.size == (AxisPlayers.size + 1)) || (AxisPlayers.size == (AlliedPlayers.size + 1)) || AlliedPlayers.size == AxisPlayers.size || (level.bombPlanted && (AlliedPlayers.size + AxisPlayers.size == 2 )))
		return false;
	else
		return true;
}

balanceTeams()
{
	AlliedPlayers = [];
	AxisPlayers = [];
	mostRecentPlayer = undefined;
	
	players = getEntArray("player", "classname");
	for(i = 0; i < players.size; i++) // fills players teams array
	{
		if((isdefined(players[i].pers["team"])) && (players[i].pers["team"] == "allies"))
			AlliedPlayers[AlliedPlayers.size] = players[i]; //[AlliedPlayers.size]
		else if((isdefined(players[i].pers["team"])) && (players[i].pers["team"] == "axis"))
			AxisPlayers[AxisPlayers.size] = players[i]; //[AxisPlayers.size]
	}

	while((AlliedPlayers.size > (AxisPlayers.size + 1)) || (AxisPlayers.size > (AlliedPlayers.size + 1)))
	{
		if(AlliedPlayers.size > (AxisPlayers.size + 1))
		{
			// Move the player that's been on the team the shortest ammount of time (highest teamTime value)
			for(j = 0; j < AlliedPlayers.size; j++)
			{
				if(!isDefined(mostRecentPlayer))
					mostRecentPlayer = AlliedPlayers[j];
				if(AlliedPlayers[j].pers["teamTime"] > mostRecentPlayer.pers["teamTime"])
					mostRecentPlayer = AlliedPlayers[j];
			}
			mostRecentPlayer changeTeam("axis");
		}
		else if(AxisPlayers.size > (AlliedPlayers.size + 1))
		{
			// Move the player that's been on the team the shortest ammount of time (highest teamTime value)
			for(j = 0; j < AxisPlayers.size; j++)
			{
				if(!isDefined(mostRecentPlayer))
					mostRecentPlayer = AxisPlayers[j];
				if(AxisPlayers[j].pers["teamTime"] > mostRecentPlayer.pers["teamTime"])
					mostRecentPlayer = AxisPlayers[j];
			}
			mostRecentPlayer changeTeam("allies");
		}
		
		mostRecentPlayer = undefined;
		AlliedPlayers = [];
		AxisPlayers = [];
		
		players = getEntArray("player", "classname");
		for(i = 0; i < players.size; i++)
		{
			if((isdefined(players[i].pers["team"])) && (players[i].pers["team"] == "allies"))
				AlliedPlayers[AlliedPlayers.size] = players[i];
			else if((isdefined(players[i].pers["team"])) &&(players[i].pers["team"] == "axis"))
				AxisPlayers[AxisPlayers.size] = players[i];
		}
	}
	wait 0.1;
	iPrintLn("^1Teams are balancing!");
}

changeTeam(team)
{
	if(self.sessionstate != "dead")
	{
		// Set a flag on the player to they aren't robbed points for dying - the callback will remove the flag
		self.switching_teams = true;
		self.joining_team = team;
		self.leaving_team = self.pers["team"];
		// Suicide the player so they can't hit escape and fail the team balance, don't balance if SD/SR and its round end
		if(self.sessionstate == "playing" && level.gametype != "sd" && level.gametype != "sr")
			self suicide();
	}

	self.pers["team"] = team;
	self.team = team;
	self.pers["teamTime"] = undefined;
	self.sessionteam = self.pers["team"];
	self maps\mp\gametypes\_globallogic::updateObjectiveText();
	// Update spectator permissions immediately on change of team
	self maps\mp\gametypes\_spectating::setSpectatePermissions();
	
	if(self.pers["team"] == "allies")
	{
		self setclientdvar("g_scriptMainMenu", game["menu_class_allies"]);
		self openMenu(game["menu_changeclass_allies"]);
	}
	else
	{
		self setclientdvar("g_scriptMainMenu", game["menu_class_axis"]);
		self openMenu(game["menu_changeclass_axis"]);
	}
	self notify("end_respawn");
}


setPlayerModels()
{
	game["allies_model"] = [];
	alliesCharSet = tableLookup("mp/mapsTable.csv", 0, getDvar("mapname"), 1);
	if(!isDefined(alliesCharSet) || alliesCharSet == "")
	{
		if(!isDefined(game["allies_soldiertype"]) || !isDefined(game["allies"]))	
		{
			game["allies_soldiertype"] = "desert";
			game["allies"] = "marines";
		}
	}
	else
		game["allies_soldiertype"] = alliesCharSet;

	axisCharSet = tableLookup("mp/mapsTable.csv", 0, getDvar("mapname"), 2);
	if(!isDefined(axisCharSet) || axisCharSet == "")
	{
		if(!isDefined(game["axis_soldiertype"]) || !isDefined(game["axis"]))
		{
			game["axis_soldiertype"] = "desert";
			game["axis"] = "arab";
		}
	}
	else
		game["axis_soldiertype"] = axisCharSet;

	// Do we really need to custom classes to be defined on promod ??
	if(game["allies_soldiertype"] == "desert")
	{
		mptype\mptype_ally_cqb::precache();
		mptype\mptype_ally_sniper::precache();
		mptype\mptype_ally_engineer::precache();
		mptype\mptype_ally_rifleman::precache();
		mptype\mptype_ally_support::precache();
		game["allies_model"]["SNIPER"] = mptype\mptype_ally_sniper::main;
		game["allies_model"]["SUPPORT"] = mptype\mptype_ally_support::main;
		game["allies_model"]["ASSAULT"] = mptype\mptype_ally_rifleman::main;
		game["allies_model"]["RECON"] = mptype\mptype_ally_engineer::main;
		game["allies_model"]["SPECOPS"] = mptype\mptype_ally_cqb::main;
		// Custom class defaults
		game["allies_model"]["CLASS_CUSTOM1"] = mptype\mptype_ally_cqb::main;
		game["allies_model"]["CLASS_CUSTOM2"] = mptype\mptype_ally_cqb::main;
		game["allies_model"]["CLASS_CUSTOM3"] = mptype\mptype_ally_cqb::main;
		game["allies_model"]["CLASS_CUSTOM4"] = mptype\mptype_ally_cqb::main;
		game["allies_model"]["CLASS_CUSTOM5"] = mptype\mptype_ally_cqb::main;
	}
	else if(game["allies_soldiertype"] == "urban")
	{
		assert(game["allies"] == "sas");
		mptype\mptype_ally_urban_sniper::precache();
		mptype\mptype_ally_urban_support::precache();
		mptype\mptype_ally_urban_assault::precache();
		mptype\mptype_ally_urban_recon::precache();
		mptype\mptype_ally_urban_specops::precache();
		game["allies_model"]["SNIPER"] = mptype\mptype_ally_urban_sniper::main;
		game["allies_model"]["SUPPORT"] = mptype\mptype_ally_urban_support::main;
		game["allies_model"]["ASSAULT"] = mptype\mptype_ally_urban_assault::main;
		game["allies_model"]["RECON"] = mptype\mptype_ally_urban_recon::main;
		game["allies_model"]["SPECOPS"] = mptype\mptype_ally_urban_specops::main;
		// Custom class defaults
		game["allies_model"]["CLASS_CUSTOM1"] = mptype\mptype_ally_urban_assault::main;
		game["allies_model"]["CLASS_CUSTOM2"] = mptype\mptype_ally_urban_assault::main;
		game["allies_model"]["CLASS_CUSTOM3"] = mptype\mptype_ally_urban_assault::main;
		game["allies_model"]["CLASS_CUSTOM4"] = mptype\mptype_ally_urban_assault::main;
		game["allies_model"]["CLASS_CUSTOM5"] = mptype\mptype_ally_urban_assault::main;
	}
	else
	{
		assert(game["allies"] == "sas");
		mptype\mptype_ally_woodland_assault::precache();
		mptype\mptype_ally_woodland_recon::precache();
		mptype\mptype_ally_woodland_sniper::precache();
		mptype\mptype_ally_woodland_specops::precache();
		mptype\mptype_ally_woodland_support::precache();
		game["allies_model"]["SNIPER"] = mptype\mptype_ally_woodland_sniper::main;
		game["allies_model"]["SUPPORT"] = mptype\mptype_ally_woodland_support::main;
		game["allies_model"]["ASSAULT"] = mptype\mptype_ally_woodland_assault::main;
		game["allies_model"]["RECON"] = mptype\mptype_ally_woodland_recon::main;
		game["allies_model"]["SPECOPS"] = mptype\mptype_ally_woodland_specops::main;
		// Custom class defaults
		game["allies_model"]["CLASS_CUSTOM1"] = mptype\mptype_ally_woodland_recon::main;
		game["allies_model"]["CLASS_CUSTOM2"] = mptype\mptype_ally_woodland_recon::main;
		game["allies_model"]["CLASS_CUSTOM3"] = mptype\mptype_ally_woodland_recon::main;
		game["allies_model"]["CLASS_CUSTOM4"] = mptype\mptype_ally_woodland_recon::main;
		game["allies_model"]["CLASS_CUSTOM5"] = mptype\mptype_ally_woodland_recon::main;
	}
	
	if(game["axis_soldiertype"] == "desert")
	{
		mptype\mptype_axis_cqb::precache();
		mptype\mptype_axis_sniper::precache();
		mptype\mptype_axis_engineer::precache();
		mptype\mptype_axis_rifleman::precache();
		mptype\mptype_axis_support::precache();
		game["axis_model"] = [];
		game["axis_model"]["SNIPER"] = mptype\mptype_axis_sniper::main;
		game["axis_model"]["SUPPORT"] = mptype\mptype_axis_support::main;
		game["axis_model"]["ASSAULT"] = mptype\mptype_axis_rifleman::main;
		game["axis_model"]["RECON"] = mptype\mptype_axis_engineer::main;
		game["axis_model"]["SPECOPS"] = mptype\mptype_axis_cqb::main;
		// Custom class defaults
		game["axis_model"]["CLASS_CUSTOM1"] = mptype\mptype_axis_cqb::main;
		game["axis_model"]["CLASS_CUSTOM2"] = mptype\mptype_axis_cqb::main;
		game["axis_model"]["CLASS_CUSTOM3"] = mptype\mptype_axis_cqb::main;
		game["axis_model"]["CLASS_CUSTOM4"] = mptype\mptype_axis_cqb::main;
		game["axis_model"]["CLASS_CUSTOM5"] = mptype\mptype_axis_cqb::main;
	}
	else if(game["axis_soldiertype"] == "urban")
	{
		mptype\mptype_axis_urban_sniper::precache();
		mptype\mptype_axis_urban_support::precache();
		mptype\mptype_axis_urban_assault::precache();
		mptype\mptype_axis_urban_engineer::precache();
		mptype\mptype_axis_urban_cqb::precache();
		game["axis_model"]["SNIPER"] = mptype\mptype_axis_urban_sniper::main;
		game["axis_model"]["SUPPORT"] = mptype\mptype_axis_urban_support::main;
		game["axis_model"]["ASSAULT"] = mptype\mptype_axis_urban_assault::main;
		game["axis_model"]["RECON"] = mptype\mptype_axis_urban_engineer::main;
		game["axis_model"]["SPECOPS"] = mptype\mptype_axis_urban_cqb::main;
		// Custom class defaults
		game["axis_model"]["CLASS_CUSTOM1"] = mptype\mptype_axis_urban_assault::main;
		game["axis_model"]["CLASS_CUSTOM2"] = mptype\mptype_axis_urban_assault::main;
		game["axis_model"]["CLASS_CUSTOM3"] = mptype\mptype_axis_urban_assault::main;	
		game["axis_model"]["CLASS_CUSTOM4"] = mptype\mptype_axis_urban_assault::main;
		game["axis_model"]["CLASS_CUSTOM5"] = mptype\mptype_axis_urban_assault::main;
	}
	else
	{
		assert(game["axis"] == "opfor");
		mptype\mptype_axis_woodland_rifleman::precache();
		mptype\mptype_axis_woodland_cqb::precache();
		mptype\mptype_axis_woodland_sniper::precache();
		mptype\mptype_axis_woodland_engineer::precache();
		mptype\mptype_axis_woodland_support::precache();
		game["axis_model"]["SNIPER"] = mptype\mptype_axis_woodland_sniper::main;
		game["axis_model"]["SUPPORT"] = mptype\mptype_axis_woodland_support::main;
		game["axis_model"]["ASSAULT"] = mptype\mptype_axis_woodland_rifleman::main;
		game["axis_model"]["RECON"] = mptype\mptype_axis_woodland_engineer::main;
		game["axis_model"]["SPECOPS"] = mptype\mptype_axis_woodland_cqb::main;
		// Custom class defaults
		game["axis_model"]["CLASS_CUSTOM1"] = mptype\mptype_axis_woodland_cqb::main;
		game["axis_model"]["CLASS_CUSTOM2"] = mptype\mptype_axis_woodland_cqb::main;
		game["axis_model"]["CLASS_CUSTOM3"] = mptype\mptype_axis_woodland_cqb::main;	
		game["axis_model"]["CLASS_CUSTOM4"] = mptype\mptype_axis_woodland_cqb::main;
		game["axis_model"]["CLASS_CUSTOM5"] = mptype\mptype_axis_woodland_cqb::main;	
	}
}

playerModelForWeapon(weapon)
{
	self detachAll();
	weaponClass = tablelookup("mp/statstable.csv", 4, weapon, 2);
	
	switch (weaponClass)
	{
		case "weapon_smg":
			[[game[self.pers["team"]+"_model"]["SPECOPS"]]]();
			break;
		case "weapon_assault":
			[[game[self.pers["team"]+"_model"]["ASSAULT"]]]();
			break;
		case "weapon_sniper":
			[[game[self.pers["team"]+"_model"]["SNIPER"]]]();
			break;
		case "weapon_shotgun":
			[[game[self.pers["team"]+"_model"]["RECON"]]]();
			break;
		case "weapon_lmg":
			[[game[self.pers["team"]+"_model"]["SUPPORT"]]]();
			break;
		default:
			[[game[self.pers["team"]+"_model"]["ASSAULT"]]]();
			break;
	}
}	

CountPlayers()
{
	players = level.players;
	allies = 0;
	axis = 0;
	for(i = 0; i < players.size; i++)
	{
		if(players[i] == self)
			continue;
		if((isdefined(players[i].pers["team"])) && (players[i].pers["team"] == "allies"))
			allies++;
		else if((isdefined(players[i].pers["team"])) && (players[i].pers["team"] == "axis"))
			axis++;
	}
	players["allies"] = allies;
	players["axis"] = axis;
	return players;
}

trackFreePlayedTime()
{
	self endon("disconnect");
	self.timePlayed["allies"] = 0;
	self.timePlayed["axis"] = 0;
	self.timePlayed["other"] = 0;
	self.timePlayed["total"] = 0;

	for(;;)
	{
		if(game["state"] == "playing")
		{
			if(isDefined(self.pers["team"]) && self.pers["team"] == "allies" && self.sessionteam != "spectator")
			{
				self.timePlayed["allies"]++;
				self.timePlayed["total"]++;
			}
			else if(isDefined(self.pers["team"]) && self.pers["team"] == "axis" && self.sessionteam != "spectator")
			{
				self.timePlayed["axis"]++;
				self.timePlayed["total"]++;
			}
			else
			{
				self.timePlayed["other"]++;
			}
		}
		wait (1.0);
	}
}

updateFreePlayerTimes()
{
	nextToUpdate = 0;
	for(;;)
	{
		nextToUpdate++;
		if(nextToUpdate >= level.players.size)
			nextToUpdate = 0;

		if(isDefined(level.players[nextToUpdate]))
			level.players[nextToUpdate] updateFreePlayedTime();

		wait (1.0);
	}
}

updateFreePlayedTime()
{
	if(self.timePlayed["allies"])
	{
		self maps\mp\gametypes\_persistence::statAdd("time_played_allies", self.timePlayed["allies"]);
		self maps\mp\gametypes\_persistence::statAdd("time_played_total", self.timePlayed["allies"]);
	}
	if(self.timePlayed["axis"])
	{
		self maps\mp\gametypes\_persistence::statAdd("time_played_opfor", self.timePlayed["axis"]);
		self maps\mp\gametypes\_persistence::statAdd("time_played_total", self.timePlayed["axis"]);
	}
	if(self.timePlayed["other"])
	{
		self maps\mp\gametypes\_persistence::statAdd("time_played_other", self.timePlayed["other"]);			
		self maps\mp\gametypes\_persistence::statAdd("time_played_total", self.timePlayed["other"]);
	}
	if(game["state"] == "postgame")
		return;

	self.timePlayed["allies"] = 0;
	self.timePlayed["axis"] = 0;
	self.timePlayed["other"] = 0;
}

getJoinTeamPermissions(team)
{
	teamcount = 0;
	players = level.players;
	for(i = 0; i < players.size; i++)
	{
		player = players[i];
		if((isdefined(player.pers["team"])) && (player.pers["team"] == team))
			teamcount++;
	}
	if(teamCount < level.teamLimit)
		return true;
	else
		return false;
}

setSpectatePermissions()
{
	self allowSpectateTeam("allies", true);
	self allowSpectateTeam("axis", true);
	self allowSpectateTeam("none", false);
}