#include "utils"
#include "WeaponCustomBase"

/*
 * Defines and initializes the weapon_custom and weapon_custom_shoot entites.
 */

void MapInit()
{
	WeaponCustomMapInit();
	
	// TODO: Fix really weird bug where manually placed weapons don't spawn.
	// It seems like weapon_test spawns before weapon_test is registered and so it doesn't initialize properly
	// Making a copy of the weapon in hammer seems to fix it (gets placed at the end of the entity list?)
}

void MapActivate()
{
	WeaponCustomMapActive();
}

void WeaponCustomMapInit()
{	
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom", "weapon_custom" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_shoot", "weapon_custom_shoot" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_projectile", "weapon_custom_projectile" );
}

void WeaponCustomMapActive()
{	
	// Hook up weapon_custom with weapon_custom_shoot
	array<string>@ keys = custom_weapons.getKeys();
	for (uint i = 0; i < keys.length(); i++)
	{
		weapon_custom@ wep = cast<weapon_custom@>( custom_weapons[keys[i]] );
		if (wep.primary_fire.Length() == 0 and wep.secondary_fire.Length() == 0)
		{
			println(logPrefix + wep.weapon_classname + " has no primary or secondary fire function set");
			continue;
		}
		
		bool foundPrimary = false;
		bool foundSecondary = false;
		array<string>@ keys2 = custom_weapon_shoots.getKeys();
		for (uint k = 0; k < keys2.length(); k++)
		{
			weapon_custom_shoot@ shoot = cast<weapon_custom_shoot@>( custom_weapon_shoots[keys2[k]] );
			if (shoot.pev.targetname == wep.primary_fire and wep.primary_fire.Length() > 0) {
				@wep.fire_settings[0] = shoot;
				foundPrimary = true;
			}
			if (shoot.pev.targetname == wep.secondary_fire and wep.secondary_fire.Length() > 0) {
				@wep.fire_settings[1] = shoot;
				foundSecondary = true;
			}
		}
		if (!foundPrimary)
			println(logPrefix + " Couldn't find primary fire entity " + wep.primary_fire + " for " + wep.weapon_classname);
		if (!foundSecondary)
			println(logPrefix + " Couldn't find secondary fire entity '" + wep.secondary_fire + "' for " + wep.weapon_classname);
	}
}

// WeaponCustomBase will read this to get weapon_custom settings
// Also let's us know which weapon slots are used (Auto weapon slot position depends on this)
dictionary custom_weapons;
dictionary custom_weapon_shoots;

int MAX_BEAMS = 256; // any more and you get console spam and game freezes (acutal max is 258 or 259 I think)
int REC_BEAMS = 8; // 8 * 32 players = 256
int MAX_WEAPON_SLOT_POSITION = 10;
int MIN_WEAPON_SLOT_POSITION = 5;
int MAX_WEAPON_SLOT = 5;
int REC_BULLETS_PER_SECOND = 32; // max recommended bullets per second (shotgun has most BPS)
bool debug_mode = true;

// spawn flags
int FL_FIRE_UNDERWATER = 1;

// shoot spawn flags
int FL_SHOOT_BULLET = 1;
int FL_SHOOT_PROJECTILE = 2;
int FL_SHOOT_BEAM = 4;
//int FL_SHOOT_BEAM = 8;
int FL_SHOTT_CUSTOM_EXPLOSION = 16;
int FL_SHOOT_EXPLOSIVE_BULLETS = 32;
int FL_SHOOT_PROJ_NO_GRAV = 64;
int FL_SHOOT_IN_WATER = 128;
int FL_SHOOT_NO_BULLET_DECALS = 256;
int FL_SHOOT_DETONATE_SATCHELS = 512;

enum spread_func
{
	SPREAD_GAUSSIAN,
	SPREAD_UNIFORM,
}

enum fire_mode
{
	PRIMARY,
	SECONDARY
};

enum projectile_action
{
	PROJ_ACT_DAMAGE,
	PROJ_ACT_EXPLODE,
	PROJ_ACT_BOUNCE,
	PROJ_ACT_ATTACH,
};

enum projectile_type
{
	PROJECTILE_ARGRENADE,
	PROJECTILE_BANANA,
	PROJECTILE_BOLT,
	PROJECTILE_DISPLACER,
	PROJECTILE_GRENADE,
	PROJECTILE_HORNET,
	PROJECTILE_HVR,
	PROJECTILE_MORTAR,
	PROJECTILE_RPG,
	PROJECTILE_SHOCK,
	PROJECTILE_CUSTOM,
	PROJECTILE_OTHER
};

enum beam_type
{
	BEAM_DISABLED = -1,
	BEAM_LINEAR,
	BEAM_SPIRAL,
	BEAM_PROJECTILE
}

enum explosion_types
{
	EXPLODE_SPRITE,
	EXPLODE_DISK,
	EXPLODE_CYLINDER,
	EXPLODE_TORUS
}

class BeamOptions
{
	int type;
	int width;
	int noise;
	int scrollRate;
	float time;
	string sprite;
	Color color;
};

class ProjectileOptions
{
	int type;
	int die_event;
	int world_event;
	int monster_event;
	float speed;
	float life;
	float explode_mag;
	float impact_dmg;
	float elasticity; // percentage of reflected velocity
	float size;
	string entity_class; // custom projectile entity
	string explode_spr;
	string explode_snd;
	string impact_snd;
	string model;
	string sprite;
	string explode_decal;
	string bounce_decal;
	
	string trail_spr;
	int trail_sprId = 2;
	int trail_life;
	int trail_width;
	Color trail_color;
};

class weapon_custom_shoot : ScriptBaseEntity
{
	array<string> sounds; // shoot sounds
	int ammo_cost;
	float cooldown = 0.5;
	float recoil;
	float max_range;
	int bullets;
	int bullet_type; // see docs for "Bullet"
	int bullet_color;
	int bullet_spread_func;
	float bullet_damage;
	float bullet_spread;
	
	ProjectileOptions@ projectile;
	
	string beam_impact_spr;
	int beam_ricochet_limit; // maximum number of ricochets
	
	int explosion_style;
	float explode_mag;
	float explode_damage;
	string explode_spr;
	string explode_snd;
	string explode_decal;
	string explode_smoke_spr;
	Color explode_light;
	int explode_gibs;
	string explode_gib_mdl;
	int explode_gib_mat;
	
	array<string> rico_snds;
	string rico_decal;
	string rico_part_spr;
	float rico_angle;
	int rico_part_count;
	int rico_part_scale;
	int rico_part_speed;
	int rico_trace_count;
	int rico_trace_color;
	int rico_trace_speed;
	
	array<BeamOptions> beams = {BeamOptions(), BeamOptions()};

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if (projectile is null)
			@projectile = ProjectileOptions();
			
		if 		(szKey == "sounds")        sounds = szValue.Split(";");			
		else if (szKey == "ammo_cost")     ammo_cost = atoi(szValue);			
		else if (szKey == "cooldown")      cooldown = atof(szValue);
		else if (szKey == "recoil")        recoil = atof(szValue);
		else if (szKey == "max_range")     max_range = atof(szValue);
		
		else if (szKey == "bullets")       bullets = atoi(szValue);
		else if (szKey == "bullet_type")   bullet_type = atoi(szValue);
		else if (szKey == "bullet_damage") bullet_damage = atof(szValue);
		else if (szKey == "bullet_spread") bullet_spread = atof(szValue);
		else if (szKey == "bullet_color")  bullet_color = atoi(szValue);
		else if (szKey == "bullet_spread_func")  bullet_spread_func = atoi(szValue);
		
		else if (szKey == "projectile_type")          projectile.type = atoi(szValue);
		else if (szKey == "projectile_die_event")     projectile.die_event = atoi(szValue);
		else if (szKey == "projectile_world_event")   projectile.world_event = atoi(szValue);
		else if (szKey == "projectile_monster_event") projectile.monster_event = atoi(szValue);
		else if (szKey == "projectile_speed")         projectile.speed = atof(szValue);
		else if (szKey == "projectile_life")          projectile.life = atof(szValue);
		else if (szKey == "projectile_explode_mag")   projectile.explode_mag = atof(szValue);
		else if (szKey == "projectile_impact_dmg")    projectile.impact_dmg = atof(szValue);
		else if (szKey == "projectile_bounce")        projectile.elasticity = atof(szValue);
		else if (szKey == "projectile_class")         projectile.entity_class = szValue;
		else if (szKey == "projectile_explode_spr")   projectile.explode_spr = szValue;
		else if (szKey == "projectile_explode_snd")   projectile.explode_snd = szValue;
		else if (szKey == "projectile_impact_snd")    projectile.impact_snd = szValue;
		else if (szKey == "projectile_mdl")    		  projectile.model = szValue;
		else if (szKey == "projectile_spr")    		  projectile.sprite = szValue;
		else if (szKey == "projectile_size")          projectile.size = atof(szValue);
		else if (szKey == "projectile_trail_spr")     projectile.trail_spr = szValue;
		else if (szKey == "projectile_trail_life")    projectile.trail_life = atoi(szValue);
		else if (szKey == "projectile_trail_width")   projectile.trail_width = atoi(szValue);
		else if (szKey == "projectile_trail_color")   projectile.trail_color = parseColor(szValue);
		else if (szKey == "projectile_bounce_decal")  projectile.bounce_decal = szValue;
				
		else if (szKey == "beam_impact_spr")       beam_impact_spr = szValue;
		else if (szKey == "beam_ricochet_limit")   beam_ricochet_limit = atoi(szValue);
		
		else if (szKey == "beam1_type")       beams[0].type = atoi(szValue);
		else if (szKey == "beam1_time")       beams[0].time = atof(szValue);
		else if (szKey == "beam1_spr")        beams[0].sprite = szValue;
		else if (szKey == "beam1_color")      beams[0].color = parseColor(szValue);
		else if (szKey == "beam1_width")      beams[0].width = atoi(szValue);
		else if (szKey == "beam1_noise")      beams[0].noise = atoi(szValue);
		else if (szKey == "beam1_scroll")      beams[0].scrollRate = atoi(szValue);
		
		else if (szKey == "beam2_type")       beams[1].type = atoi(szValue);
		else if (szKey == "beam2_time")       beams[1].time = atof(szValue);
		else if (szKey == "beam2_spr")        beams[1].sprite = szValue;
		else if (szKey == "beam2_color")      beams[1].color = parseColor(szValue);
		else if (szKey == "beam2_width")      beams[1].width = atoi(szValue);
		else if (szKey == "beam2_noise")      beams[1].noise = atoi(szValue);
		else if (szKey == "beam2_scroll")      beams[1].scrollRate = atoi(szValue);
		
		else if (szKey == "explosion_style")   explosion_style = atoi(szValue);
		else if (szKey == "explode_mag")       explode_mag = atof(szValue);
		else if (szKey == "explode_dmg")       explode_damage = atof(szValue);
		else if (szKey == "explode_spr")       explode_spr = szValue;
		else if (szKey == "explode_snd")       explode_snd = szValue;
		else if (szKey == "explode_decal")     explode_decal = szValue;
		else if (szKey == "explode_smoke_spr") explode_smoke_spr = szValue;
		else if (szKey == "explode_dlight")    explode_light = parseColor(szValue);
		else if (szKey == "explode_gibs")      explode_gibs = atoi(szValue);
		else if (szKey == "explode_gib_model") explode_gib_mdl = szValue;
		else if (szKey == "explode_gib_mat")   explode_gib_mat = atoi(szValue);
		
		else if (szKey == "rico_snds")        rico_snds = szValue.Split(";");	
		else if (szKey == "rico_decal")       rico_decal = szValue;
		else if (szKey == "rico_part_spr")    rico_part_spr = szValue;
		else if (szKey == "rico_part_count")  rico_part_count = atoi(szValue);
		else if (szKey == "rico_part_scale")  rico_part_scale = atoi(szValue);
		else if (szKey == "rico_part_speed")  rico_part_speed = atoi(szValue);
		else if (szKey == "rico_trace_count") rico_trace_count = atoi(szValue);
		else if (szKey == "rico_trace_speed") rico_trace_speed = atoi(szValue);
		else if (szKey == "rico_trace_color") rico_trace_color = atoi(szValue);
		else if (szKey == "rico_angle") 	  rico_angle = atof(szValue);
		
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	string getRandomShootSound()
	{
		if (sounds.length() == 0)
			return "";
		int randIdx = Math.RandomLong(0, sounds.length()-1);
		return sounds[randIdx];
	}
	
	string getRandomRicochetSound()
	{
		if (rico_snds.length() == 0)
			return "";
		int randIdx = Math.RandomLong(0, rico_snds.length()-1);
		return rico_snds[randIdx];
	}
	
	bool validateSettings()
	{
		return true;
	}
	
	void Spawn()
	{				
		if (string(pev.targetname).Length() == 0) {
			println(logPrefix + "weapon_custom_shoot has no targetname and will not be used.");
			return;
		}
		else if (custom_weapon_shoots.exists(pev.targetname)) {
			println(logPrefix + "more than weapon_custom_shoot has the targetname '" + pev.targetname + "'");
		}
		
		// projectiles count as 2 bullets because they can spawn lots of special effects
		int iBullets = pev.spawnflags & FL_SHOOT_BULLET != 0 ? bullets : 0; 
		//int iProjectiles = pev.spawnflags & FL_SHOOT_PROJECTILE != 0 ? 2 : 0; 
		float bps = (1.0f / cooldown) * iBullets;
		
		if (int(bps) > REC_BULLETS_PER_SECOND)
			println("\nWEAPON_CUSTOM WARNING: " + pev.targetname + " bullets per second (" + int(bps) + 
					") is greater than the max recommended (" + REC_BULLETS_PER_SECOND + ")\n"
					"Your game might freeze occasionally with 'Overflow 2048 temporary ents!' spammed in console\n");
		
		int iBeams = pev.spawnflags & FL_SHOOT_BEAM != 0 ? beam_ricochet_limit+1 : 0;
		if (beams[1].type != BEAM_DISABLED)
			iBeams *= 2;
		
		if (iBeams > REC_BEAMS)
			println("\nWEAPON_CUSTOM WARNING: " + pev.targetname + " max beams (" + int(iBeams) + 
					") is greater than the max recommended (" + REC_BEAMS + ")\n"
					"Your game might freeze occasionally with 'Overflow beam entity list!' spammed in console\n");
		
		custom_weapon_shoots[pev.targetname] = this;
		Precache();
	}
	
	int PrecacheModel(string model)
	{
		if (model.Length() > 0) {
			debugln("Precaching model for " + pev.targetname + ": " + model);
			return g_Game.PrecacheModel( model );
		}
		return -1;
	}
	
	void PrecacheSound(string sound)
	{
		if (sound.Length() > 0) {
			debugln("Precaching sound for " + pev.targetname + ": " + sound);
			g_SoundSystem.PrecacheSound( sound );
		}
	}
	
	void Precache()
	{
		for (uint i = 0; i < sounds.length(); i++) {
			PrecacheSound(sounds[i]);
		}
		PrecacheSound(projectile.explode_snd);
		PrecacheSound(projectile.impact_snd);
		PrecacheModel(beam_impact_spr);
		PrecacheModel(projectile.explode_spr);
		PrecacheModel(beams[0].sprite);
		PrecacheModel(beams[1].sprite);
		
		// TODO: PRecacheOther for custom entities
		
		if (projectile.type == PROJECTILE_ARGRENADE)
			PrecacheModel( "models/grenade.mdl" );
		if (projectile.type == PROJECTILE_MORTAR)
		{
			PrecacheModel( "models/shell.mdl" );
			PrecacheSound( "weapons/ofmortar.wav" );
		}
		if (projectile.model.Length() > 0)
			PrecacheModel( projectile.model );
		if (projectile.sprite.Length() > 0)
			PrecacheModel( projectile.sprite );
		if (projectile.trail_spr.Length() > 0)
			projectile.trail_sprId = PrecacheModel( projectile.trail_spr );
			
		if (explode_spr.Length() > 0)
			PrecacheModel( explode_spr );
		if (explode_smoke_spr.Length() > 0)
			PrecacheModel( explode_smoke_spr );
		if (explode_gib_mdl.Length() > 0)
			PrecacheModel( explode_gib_mdl );
		if (explode_snd.Length() > 0)
			PrecacheSound( explode_snd );
			
		if (projectile.entity_class.Length() > 0)
			g_Game.PrecacheOther( projectile.entity_class );
			
		for (uint i = 0; i < rico_snds.length(); i++) {
			PrecacheSound(rico_snds[i]);
		}
		if (rico_part_spr.Length() > 0)
			PrecacheModel(rico_part_spr);
			
		
		PrecacheModel( "models/HVR.mdl" );
		
		PrecacheModel( "models/spore.mdl" );
		
		/* kingpin ball
		PrecacheModel( "sprites/nhth1.spr" );
		PrecacheModel( "sprites/shockwave.spr" );
		PrecacheModel( "sprites/muz7.spr" );
		PrecacheSound( "kingpin/kingpin_seeker_amb.wav" );
		PrecacheSound( "tor/tor-staff-discharge.wav" );
		PrecacheSound( "debris/beamstart14.wav" );
		*/
	}
}

class weapon_custom : ScriptBaseEntity
{
	string weapon_classname;
	
	string primary_fire; // targetname of weapon_custom_shoot
	string primary_reload_snd;
	string primary_empty_snd;
	string primary_ammo_type;
	
	string secondary_fire; // ^
	string secondary_reload_snd;
	string secondary_empty_snd;
	string secondary_ammo_type;
	
	string wpn_v_model;
	string wpn_w_model;
	string wpn_p_model;
	string hud_sprite;
	string hud_sprite_folder;
	int slot;
	int slotPosition;
	int priority; // auto switch priority
	
	// primary and secondary fire settings
	array<weapon_custom_shoot@> fire_settings = {weapon_custom_shoot(), weapon_custom_shoot()}; 
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// Only custom keyvalues get sent here
		if (szKey == "weapon_name") weapon_classname = szValue;
		else if (szKey == "primary_ammo") primary_ammo_type = szValue;
		else if (szKey == "secondary_ammo") secondary_ammo_type = szValue;
		else if (szKey == "weapon_slot") slot = atoi(szValue);
		else if (szKey == "weapon_slot_pos") slotPosition = atoi(szValue);
		else if (szKey == "primary_fire") primary_fire = szValue;
		else if (szKey == "primary_reload_snd") primary_reload_snd = szValue;
		else if (szKey == "primary_empty_snd") primary_empty_snd = szValue;
		else if (szKey == "secondary_fire") secondary_fire = szValue;
		else if (szKey == "secondary_reload_snd") secondary_reload_snd = szValue;
		else if (szKey == "wpn_v_model") wpn_v_model = szValue;
		else if (szKey == "wpn_w_model") wpn_w_model = szValue;
		else if (szKey == "wpn_p_model") wpn_p_model = szValue;
		else if (szKey == "hud_sprite") hud_sprite = szValue;
		else if (szKey == "sprite_directory") hud_sprite_folder = szValue;
		else if (szKey == "weapon_priority") priority = atoi(szValue);
		else return BaseClass.KeyValue( szKey, szValue );
			
		return true;
	}
	
	int clip_size()                      { return self.pev.skin; }
	float cooldown(int fmode)            { return fire_settings[fmode].cooldown; }
	bool can_fire_underwater(int fmode)  { return fire_settings[fmode].pev.spawnflags & FL_SHOOT_IN_WATER != 0; }
	bool shoots_bullet(int fmode) 	     { return fire_settings[fmode].pev.spawnflags & FL_SHOOT_BULLET != 0; }
	bool shoots_projectile(int fmode)    { return fire_settings[fmode].pev.spawnflags & FL_SHOOT_PROJECTILE != 0; }
	bool shoots_beam(int fmode) 	     { return fire_settings[fmode].pev.spawnflags & FL_SHOOT_BEAM != 0; }
	int shoot_flags(int fmode)			 { return fire_settings[fmode].pev.spawnflags; }
	ProjectileOptions@ get_projectile(int fmode) { return @fire_settings[fmode].projectile; }
	weapon_custom_shoot@ get_shoot_settings(int fmode) { return @fire_settings[fmode]; }
	string shoot_sound(int fmode)        { return fire_settings[fmode].getRandomShootSound(); }
	
	
	bool validateSettings()
	{		
		// clamp values
		if (slot < 0 or slot > MAX_WEAPON_SLOT)
			slot = 0;
		if (slotPosition < MIN_WEAPON_SLOT_POSITION or slotPosition > MAX_WEAPON_SLOT_POSITION)
			slotPosition = -1;
			
		// check that slot isn't filled
		if (slotPosition == -1) // user chose "Auto"
		{
			slotPosition = getFreeWeaponSlotPosition(slot);
			if (slotPosition == -1)
				println(logPrefix + weapon_classname + " Can't fit in weapon slot " + slotPosition +". Move this weapon to another slot and try again.");
		}
		else if (!isFreeWeaponSlot(slot, slotPosition))
		{
			println(logPrefix + "The weapon slot you chose for " + weapon_classname + " is filled. Choose another slot or slot position and try again.");
		}
		
		return true;
	}
	
	bool isFreeWeaponSlot(int slot, int position)
	{
		if (slot < 0 or slot > MAX_WEAPON_SLOT)
			return false;
		if (position < MIN_WEAPON_SLOT_POSITION or position > MAX_WEAPON_SLOT_POSITION)
			return false;
		
		array<string>@ stateKeys = custom_weapons.getKeys();
		for (uint i = 0; i < stateKeys.length(); i++)
		{
			weapon_custom@ settings = cast<weapon_custom@>( custom_weapons[stateKeys[i]] );
			if (settings.slot == slot and settings.slotPosition == position)
				return false;
		}
		
		// TODO: What if another weapon script registered a weapon here?
		return true;
	}

	int getFreeWeaponSlotPosition(int slot)
	{
		for (int i = MIN_WEAPON_SLOT_POSITION; i < MAX_WEAPON_SLOT_POSITION; i++)
		{
			if (isFreeWeaponSlot(slot, i))
				return i;
		}
		return MAX_WEAPON_SLOT_POSITION;
	}
	
	void Spawn()
	{
		if (weapon_classname.Length() > 0)
		{
			validateSettings();
			
			println("Assigning " + weapon_classname + " to slot " + slot + " at position " + slotPosition);			
		
			custom_weapons[weapon_classname] = this;
			g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustomBase", weapon_classname );
			g_ItemRegistry.RegisterWeapon( weapon_classname, hud_sprite_folder, primary_ammo_type, secondary_ammo_type );
			Precache();
		}
		else
			println("weapon_custom creation failed. No weapon_class specified");
	}
	
	void PrecacheModel(string model)
	{
		if (model.Length() > 0) {
			debugln("Precaching model for " + weapon_classname + ": " + model);
			g_Game.PrecacheModel( model );
		}
	}
	
	void PrecacheSound(string sound)
	{
		if (sound.Length() > 0) {
			debugln("Precaching sound for " + weapon_classname + ": " + sound);
			g_SoundSystem.PrecacheSound( sound );
		}
	}
	
	void Precache()
	{
		PrecacheSound(primary_reload_snd);
		PrecacheSound(primary_empty_snd);
		PrecacheSound(secondary_reload_snd);
		PrecacheSound(secondary_empty_snd);
		PrecacheModel(wpn_v_model);
		PrecacheModel(wpn_w_model);
		PrecacheModel(wpn_p_model);
		PrecacheModel(hud_sprite);
	}
};
