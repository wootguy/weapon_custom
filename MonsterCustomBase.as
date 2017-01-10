#include "utils"
#include "attack"

class MonsterCustomBase : ScriptBaseMonsterEntity
{
	monster_custom@ settings;
	string monster_classname;
	string displayname;
	int bloodcolor = 0;
	array<WeaponSound> sounds;
	
	WeaponState state;

	void Spawn()
	{
		if (settings is null) 
		{
			if (self.pev.classname == "monster_custom_generic")
			{
				if (custom_monsters.exists(monster_classname))
					@settings = cast<monster_custom>( @custom_monsters[monster_classname] );
				else
					println("MONSTER_CUSTOM ERROR: monster_custom_generic uses invalid class: " + monster_classname);
			}
			else
			{
				monster_classname = self.pev.classname;
				@settings = cast<monster_custom>( @custom_monsters[monster_classname] );
			}
		}
		
		Precache(); 
		
		// basic monster settings
		pev.health = pev.health != 0 ? pev.health : settings.pev.health;
		pev.view_ofs = Vector ( 0, 0, settings.eye_height );
		self.m_flFieldOfView = -(settings.fov / 180) + 0.9999999f; // less than 1 so 360 deg works as expected
		pev.yaw_speed = settings.turn_speed;
		//self.m_afCapability	= bits_CAP_DOORS_GROUP;
		
		// settings that squadmakers can override
		string model = self.pev.model;
		g_EntityFuncs.SetModel( self, model.Length() > 0 ? model : settings.default_model );	
		
		g_EntityFuncs.SetSize( self.pev, settings.min_hull, settings.max_hull );
		self.m_FormattedName = displayname.Length() > 0 ? displayname : settings.default_displayname;
		
		if (bloodcolor == 0) // "Default" blood color 
			bloodcolor = settings.bloodcolor;
		switch(bloodcolor)
		{
			case 1: self.m_bloodColor = BLOOD_COLOR_RED; break;
			case 2: self.m_bloodColor = BLOOD_COLOR_YELLOW; break;
			default: self.m_bloodColor = DONT_BLEED;
		}
		
		// physics
		pev.solid = SOLID_SLIDEBOX;
		pev.movetype = MOVETYPE_STEP;
		
		// Init AI
		SetThink( ThinkFunction( MonsterThink ) );
		SetUse( UseFunction(Use) );
		self.m_MonsterState = MONSTERSTATE_NONE; 
		self.MonsterInit(); 
		
		@state.c_mon = @this;
		@state.user = self;
	}
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// for monster_custom_generic
		if (szKey == "monster_name") monster_classname = szValue;
		else if (szKey == "bloodcolor") bloodcolor = atoi(szValue);
		else if (szKey == "displayname") displayname = szValue;
		else return BaseClass.KeyValue( szKey, szValue );
		return true;
	}

	void Precache()
	{
		if (string(self.pev.model).Length() > 0)
			g_Game.PrecacheModel( self.pev.model );
	}

	int Classify()
	{
		return settings.default_class; 
	}
	
	int ObjectCaps() {
		return BaseClass.ObjectCaps() | FCAP_IMPULSE_USE;
	}
	
	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value)
	{
		// TODO: anything
	}
	
	void MonsterThink()
	{
		AttackThink(state);
		BaseClass.Think();
	}
	
	void DoEvent(monster_custom_event@ event)
	{
		if (event.shoot_settings !is null)
		{
			println("SHOULD SHOOT "  + event.shoot_settings.pev.targetname);
			@state.active_opts = @event.shoot_settings;
			
			DoAttack(state);
		}
		
		WeaponSound@ snd = event.getRandomSound();
		if (snd !is null)
			snd.play(self, CHAN_ITEM);
	}
	
	// the gun or claw position
	Vector attackPosition()
	{
		return pev.origin + Vector(0,0,settings.eye_height);
	}

	void HandleAnimEvent( MonsterEvent@ pEvent )
	{
		// default
		switch (pEvent.event)
		{	// http://mrl.nyu.edu/~dzorin/ig06/lecture22/modeling.pdf
			case 1002: case 1003: case 1004: case 1005: case 1006: 
			case 1007: case 1008: case 1009: case 1010: case 2001: 
			case 2002: case 2010: case 2020: case 5001: case 5002: 
			case 5004: case 5011: case 5021: case 5031: case 6001:
				BaseClass.HandleAnimEvent( pEvent );
				return;				
		}			

		// custom
		bool handled = false;
		for (uint i = 0; i < settings.events.length(); i++)
		{
			monster_custom_event@ e = settings.events[i];
			if (e.event == pEvent.event)
			{
				handled = true;
				DoEvent(e);
			}
		}
		if (!handled)
			println("MONSTER_CUSTOM: Unhandled event " + pEvent.event + " for " + monster_classname);
			
	}
	
	Schedule@ GetSchedule( void )
	{
		println("GET SCHEDULE FOR STATE: " + self.m_MonsterState);
		return BaseClass.GetSchedule();
	}
}
