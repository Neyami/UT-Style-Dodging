// Double-tap timing based on Sprint by akcaliberg
//WHY WON'T YOU WORK
//#include "../ChatCommandManager" //By the svencoop team, should come with the game (svencoop\scripts\)

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );

	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @UnrealDodge::ClientPutInServer );
	g_Hooks.RegisterHook( Hooks::Player::PlayerPreThink, @UnrealDodge::PlayerPreThink );
	g_Hooks.RegisterHook( Hooks::Game::MapChange, @UnrealDodge::MapChange );

	@UnrealDodge::cvar_iEnabled = CCVar( "dodge-enable", 1, "0/1 - Disable/enable the plugin. (default: 1)", ConCommandFlag::AdminOnly );
	@UnrealDodge::cvar_flKeyPressInterval = CCVar( "dodge-keylisten-interval", 0.2, "The amount of time between keytaps to register as double-tap. (default: 0.2)", ConCommandFlag::AdminOnly );
	@UnrealDodge::cvar_flCooldown = CCVar( "dodge-cooldown", 0.0, "The amount of time between dodges. (default: 5.0)", ConCommandFlag::AdminOnly ); //slightly bugged if over 0.0 :/
	@UnrealDodge::cvar_flDodgeSpeed = CCVar( "dodge-speed", 400.0, "How far you dodge. (default: 400.0)", ConCommandFlag::AdminOnly );

	/*
	//WHY WON'T YOU WORK
	@UnrealDodge::pChatCommands = ChatCommandSystem::ChatCommandManager();

	UnrealDodge::pChatCommands.AddCommand( ChatCommandSystem::ChatCommand( "disabledodge", @UnrealDodge::DisablePlayerDodge, false ) );
	UnrealDodge::pChatCommands.AddCommand( ChatCommandSystem::ChatCommand( "enabledodge", @UnrealDodge::EnablePlayerDodge, false ) );*/

	UnrealDodge::arrsDisabledSteamIDs.resize(0);
	UnrealDodge::ReadPlayerSettingsFile();
}

void MapInit()
{
	UnrealDodge::arrsDisabledSteamIDs.resize(0);
	UnrealDodge::ReadPlayerSettingsFile();
}

namespace UnrealDodge
{

CClientCommand disabledodge( "disabledodge", "Disables UT dodge for the player.", @DisablePlayerDodgeCmd );
CClientCommand enabledodge( "enabledodge", "Enables UT dodge for the player.", @EnablePlayerDodgeCmd );

//WHY WON'T YOU WORK
//ChatCommandSystem::ChatCommandManager@ pChatCommands = null;
const string sPlayerSettingsFile = "scripts/plugins/store/utdodge/disabledids.txt";
const float DODGE_UPSPEED = 200;

array<float> flLastForwardPressed(33);
array<float> flLastBackPressed(33);
array<float> flLastLeftPressed(33);
array<float> flLastRightPressed(33);
array<float> flLastDodge(33);
array<bool> bIsUserDodging(33);
array<string> arrsDisabledSteamIDs;

CCVar@ cvar_iEnabled, cvar_flKeyPressInterval, cvar_flCooldown, cvar_flDodgeSpeed;

CClientCommand dodge_enable( "dodge_enable", "0/1 - Disable/enable the plugin. (default: 1)", @PluginSettings, ConCommandFlag::AdminOnly );
CClientCommand dodge_keylisten_interval( "dodge_keylisten_interval", "# - The amount of time between keytaps to register as double-tap. (default: 0.2)", @PluginSettings, ConCommandFlag::AdminOnly );
CClientCommand dodge_cooldown( "dodge_cooldown", "# - The amount of time between dodges. (default: 5.0)", @PluginSettings, ConCommandFlag::AdminOnly );
CClientCommand dodge_speed( "dodge_speed", "# / How far you dodge. (default: 400.0)", @PluginSettings, ConCommandFlag::AdminOnly );

enum direction_e
{
	DIR_FORWARD = 0,
	DIR_BACKWARD,
	DIR_LEFT,
	DIR_RIGHT
};

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	int id = g_EngineFuncs.IndexOfEdict(pPlayer.edict());
	flLastForwardPressed[id] = 0.0;
	flLastBackPressed[id] = 0.0;
	flLastLeftPressed[id] = 0.0;
	flLastRightPressed[id] = 0.0;
	flLastDodge[id] = 0.0;
	bIsUserDodging[id] = false;

	return HOOK_CONTINUE;
}

HookReturnCode PlayerPreThink( CBasePlayer@ pPlayer, uint& out uiFlags )
{
	if( cvar_iEnabled.GetInt() <= 0 ) return HOOK_CONTINUE;

	if( arrsDisabledSteamIDs.find(g_EngineFuncs.GetPlayerAuthId(pPlayer.edict())) >= 0 ) return HOOK_CONTINUE;

	if( !pPlayer.IsAlive() ) return HOOK_CONTINUE;

	int button, oldbuttons, id;

	button = pPlayer.pev.button;
	oldbuttons = pPlayer.pev.oldbuttons;
	id = pPlayer.entindex();

	if( (pPlayer.pev.flags & FL_DUCKING == 0) and (pPlayer.pev.flags & FL_ONGROUND) != 0 )
	{
		if( (button & IN_FORWARD) != 0 and (oldbuttons & IN_FORWARD) == 0 ) //Pushed down
		{
			if( (g_Engine.time - flLastForwardPressed[id]) < cvar_flKeyPressInterval.GetFloat() ) //Check for double-tap
			{
				if( cvar_flCooldown.GetFloat() > 0.0 )
				{
					if( (g_Engine.time - flLastDodge[id]) >= cvar_flCooldown.GetFloat() ) //Check for cooldown
					{
						bIsUserDodging[id] = true;
						DoDodge( EHandle(pPlayer), DIR_FORWARD );
					}
				}
				else
				{
					bIsUserDodging[id] = true;
					DoDodge( EHandle(pPlayer), DIR_FORWARD );
				}
			}

			flLastForwardPressed[id] = g_Engine.time;
		}
		else if( (oldbuttons & IN_FORWARD) != 0 and (button & IN_FORWARD) == 0 ) //Released
		{
			if( bIsUserDodging[id] )
			{
				flLastDodge[id] = g_Engine.time;
				bIsUserDodging[id] = false;
			}
		}

		if( (button & IN_BACK) != 0 and (oldbuttons & IN_BACK) == 0 ) //Pushed down
		{
			if( (g_Engine.time - flLastBackPressed[id]) < cvar_flKeyPressInterval.GetFloat() ) //Check for double-tap
			{
				if( cvar_flCooldown.GetFloat() > 0.0 )
				{
					if( (g_Engine.time - flLastDodge[id]) >= cvar_flCooldown.GetFloat() ) //Check for cooldown
					{
						bIsUserDodging[id] = true;
						DoDodge( EHandle(pPlayer), DIR_BACKWARD );
					}
				}
				else
				{
					bIsUserDodging[id] = true;
					DoDodge( EHandle(pPlayer), DIR_BACKWARD );
				}
			}

			flLastBackPressed[id] = g_Engine.time;
		}
		else if( (oldbuttons & IN_BACK) != 0 and (button & IN_BACK) == 0 ) //Released
		{
			if( bIsUserDodging[id] )
			{
				flLastDodge[id] = g_Engine.time;
				bIsUserDodging[id] = false;
			}
		}

		if( (button & IN_MOVELEFT) != 0 and (oldbuttons & IN_MOVELEFT) == 0 ) //Pushed down
		{
			if( (g_Engine.time - flLastLeftPressed[id]) < cvar_flKeyPressInterval.GetFloat() ) //Check for double-tap
			{
				if( cvar_flCooldown.GetFloat() > 0.0 )
				{
					if( (g_Engine.time - flLastDodge[id]) >= cvar_flCooldown.GetFloat() ) //Check for cooldown
					{
						bIsUserDodging[id] = true;
						DoDodge( EHandle(pPlayer), DIR_LEFT );
					}
				}
				else
				{
					bIsUserDodging[id] = true;
					DoDodge( EHandle(pPlayer), DIR_LEFT );
				}
			}

			flLastLeftPressed[id] = g_Engine.time;
		}
		else if( (oldbuttons & IN_MOVELEFT) != 0 and (button & IN_MOVELEFT) == 0 ) //Released
		{
			if( bIsUserDodging[id] )
			{
				flLastDodge[id] = g_Engine.time;
				bIsUserDodging[id] = false;
			}
		}

		if( (button & IN_MOVERIGHT) != 0 and (oldbuttons & IN_MOVERIGHT) == 0 ) //Pushed down
		{
			if( (g_Engine.time - flLastRightPressed[id]) < cvar_flKeyPressInterval.GetFloat() ) //Check for double-tap
			{
				if( cvar_flCooldown.GetFloat() > 0.0 )
				{
					if( (g_Engine.time - flLastDodge[id]) >= cvar_flCooldown.GetFloat() ) //Check for cooldown
					{
						bIsUserDodging[id] = true;
						DoDodge( EHandle(pPlayer), DIR_RIGHT );
					}
				}
				else
				{
					bIsUserDodging[id] = true;
					DoDodge( EHandle(pPlayer), DIR_RIGHT );
				}
			}

			flLastRightPressed[id] = g_Engine.time;
		}
		else if( (oldbuttons & IN_MOVERIGHT) != 0 and (button & IN_MOVERIGHT) == 0 ) //Released
		{
			if( bIsUserDodging[id] )
			{
				flLastDodge[id] = g_Engine.time;
				bIsUserDodging[id] = false;
			}
		}
	}

	return HOOK_CONTINUE;
}

void DoDodge( EHandle &in ePlayer, int iDirection )
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	Vector vecDodgeVelocity = pPlayer.pev.velocity;
	Math.MakeVectors( pPlayer.pev.angles );

	switch( iDirection )
	{
		case DIR_FORWARD:
		{
			vecDodgeVelocity = g_Engine.v_forward * cvar_flDodgeSpeed.GetFloat();

			break;
		}
		case DIR_BACKWARD:
		{
			vecDodgeVelocity = -g_Engine.v_forward * cvar_flDodgeSpeed.GetFloat();

			break;
		}
		case DIR_LEFT:
		{
			vecDodgeVelocity = -g_Engine.v_right * cvar_flDodgeSpeed.GetFloat();

			break;
		}
		case DIR_RIGHT:
		{
			vecDodgeVelocity = g_Engine.v_right * cvar_flDodgeSpeed.GetFloat();

			break;
		}
	}

	vecDodgeVelocity.z = DODGE_UPSPEED;
	pPlayer.pev.velocity = vecDodgeVelocity;
}

void PluginSettings( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	const string sCommand = args.Arg(0);

	if( args.ArgC() == 1 ) //If no arguments are supplied
	{
		if( sCommand == ".dodge_enable" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_enable\" is \"" + cvar_iEnabled.GetInt() + "\"\n" );
		else if( sCommand == ".dodge_keylisten_interval" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_keylisten_interval\" is \"" + cvar_flKeyPressInterval.GetFloat() + "\"\n" );
		else if( sCommand == ".dodge_cooldown" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_cooldown\" is \"" + cvar_flCooldown.GetFloat() + "\"\n" );
		else if( sCommand == ".dodge_speed" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_speed\" is \"" + cvar_flDodgeSpeed.GetFloat() + "\"\n" );
	}
	else if( args.ArgC() == 2 )//If one arg is supplied (value to set)
	{
		if( sCommand == ".dodge_enable" )
		{
			cvar_iEnabled.SetInt( Math.clamp(0, 1, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_enable\" changed to \"" + cvar_iEnabled.GetInt() + "\"\n" );
		}
		else if( sCommand == ".dodge_keylisten_interval" )
		{
			cvar_flKeyPressInterval.SetFloat( atof(args.Arg(1)) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_keylisten_interval\" changed to \"" + cvar_flKeyPressInterval.GetFloat() + "\"\n" );
		}
		else if( sCommand == ".dodge_cooldown" )
		{
			cvar_flCooldown.SetFloat( atof(args.Arg(1)) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_cooldown\" changed to \"" + cvar_flCooldown.GetFloat() + "\"\n" );
		}
		else if( sCommand == ".dodge_speed" )
		{
			cvar_flDodgeSpeed.SetFloat( atof(args.Arg(1)) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"dodge_speed\" changed to \"" + cvar_flDodgeSpeed.GetFloat() + "\"\n" );
		}
	}
}

void ReadPlayerSettingsFile()
{
	File@ file = g_FileSystem.OpenFile( sPlayerSettingsFile, OpenFile::READ );

	if( file !is null and file.IsOpen() )
	{
		while( !file.EOFReached() )
		{
			string sLine;
			file.ReadLine(sLine);
			//fix for linux
			string sFix = sLine.SubString( sLine.Length() - 1, 1 );
			if( sFix == " " or sFix == "\n" or sFix == "\r" or sFix == "\t" )
				sLine = sLine.SubString( 0, sLine.Length() - 1 );

			//comment
			if( sLine.SubString(0,1) == "#" or sLine.IsEmpty() )
				continue;

			//if( sLine.SubString(0,5) != "STEAM" ) continue;
			if( !sLine.StartsWith("STEAM") ) continue;

			arrsDisabledSteamIDs.insertLast( sLine );
		}

		file.Close();
	}
	else
	{
		g_Game.AlertMessage( at_logged, "[UTDODGE] Installation error: cannot locate settings file\n" );
		g_Game.AlertMessage( at_logged, "[UTDODGE] Which should be in %1\n", sPlayerSettingsFile );
		return;
	}
}

void UpdatePlayerSettingsFile()
{
	if( arrsDisabledSteamIDs.length() == 0 ) return;

	File@ file = g_FileSystem.OpenFile( sPlayerSettingsFile, OpenFile::WRITE );
	if( file !is null and file.IsOpen() )
	{
		for( uint i = 0; i < arrsDisabledSteamIDs.length(); ++i )
		{
			file.Write( arrsDisabledSteamIDs[i] + "\n" );

			g_Game.AlertMessage( at_notice, "Wrote to file: \"%1\"\n", arrsDisabledSteamIDs[i] );
		}

		file.Close();
	}
	else
	{
		g_Game.AlertMessage( at_logged, "[UTDODGE] Installation error: cannot locate settings file\n" );
		g_Game.AlertMessage( at_logged, "[UTDODGE] Which should be in %1\n", sPlayerSettingsFile );
		return;
	}
}

void DisablePlayerDodgeCmd( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
	string sSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

	if( arrsDisabledSteamIDs.find(sSteamID) < 0 )
	{
		arrsDisabledSteamIDs.insertLast( sSteamID );

		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging has been disabled for you.\n");
	}
	else
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging is already disabled for you.\n" );
}

void EnablePlayerDodgeCmd( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
	string sSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

	int searchIndex = arrsDisabledSteamIDs.find(sSteamID);
	if( searchIndex >= 0 )
	{
		arrsDisabledSteamIDs.removeAt( searchIndex );

		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging has been enabled for you.\n");
	}
	else
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging is already enabled for you.\n" );
}

//WHY WON'T YOU WORK
/*void DisablePlayerDodge( SayParameters@ pParams )
{
	pParams.ShouldHide = true;

	CBasePlayer@ pPlayer = pParams.GetPlayer();
	string sSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

	if( arrsDisabledSteamIDs.find(sSteamID) < 0 )
	{
		arrsDisabledSteamIDs.insertLast( sSteamID );

		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging has been disabled for you.\n");
	}
	else
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging is already disabled for you.\n" );
}

void EnablePlayerDodge( SayParameters@ pParams )
{
	pParams.ShouldHide = true;

	CBasePlayer@ pPlayer = pParams.GetPlayer();
	string sSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

	int searchIndex = arrsDisabledSteamIDs.find(sSteamID);
	if( searchIndex >= 0 )
	{
		arrsDisabledSteamIDs.removeAt( searchIndex );

		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging has been enabled for you.\n");
	}
	else
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[UTDODGE] Dodging is already enabled for you.\n" );
}*/

HookReturnCode MapChange()
{
	//Fix for when plugins are reloaded
	if( arrsDisabledSteamIDs.length() == 0 ) ReadPlayerSettingsFile();

	UpdatePlayerSettingsFile();

	return HOOK_CONTINUE;
}

}// end of namespace UnrealDodge
/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		26 December 2023
*	-------------------------
*	- First release
*	-------------------------
*
*	Version: 	1.1
*	Date: 		30 April 2024
*	-------------------------
*	- Added commands to disable/enable for individual players
*	-------------------------
*/
