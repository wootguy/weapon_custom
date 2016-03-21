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
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_sound", "weapon_custom_sound" );
	g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustomProjectile", "weapon_custom_projectile" );
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
		bool foundTertiary = false;
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
			if (shoot.pev.targetname == wep.tertiary_fire and wep.tertiary_fire.Length() > 0) {
				@wep.fire_settings[2] = shoot;
				foundTertiary = true;
			}
		}
		if (!foundPrimary and wep.primary_fire.Length() > 0)
			println(logPrefix + " Couldn't find primary fire entity " + wep.primary_fire + " for " + wep.weapon_classname);
		if (!foundSecondary and wep.secondary_fire.Length() > 0)
			println(logPrefix + " Couldn't find secondary fire entity '" + wep.secondary_fire + "' for " + wep.weapon_classname);
		if (!foundTertiary and wep.tertiary_fire.Length() > 0)
			println(logPrefix + " Couldn't find tertiary fire entity " + wep.tertiary_fire + " for " + wep.weapon_classname);
	}
	
	// Hook up ambient_generic with weapon_custom_shoot
	keys = custom_weapon_shoots.getKeys();
	for (uint i = 0; i < keys.length(); i++)
	{
		weapon_custom_shoot@ shoot = cast<weapon_custom_shoot@>( custom_weapon_shoots[keys[i]] );
		shoot.loadExternalSoundSettings();
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
bool debug_mode = false;

// spawn flags
int FL_FIRE_UNDERWATER = 1;

// shoot spawn flags
int FL_SHOOT_HEAL = 1;
int FL_SHOOT_REPAIR = 2;
int FL_SHOOT_NO_MELEE_SOUND_OVERLAP = 4;
int FL_SHOOT_RESPONSIVE_WINDUP = 8;
int FL_SHOOT_RICO_SPARKS = 16;
int FL_SHOTT_CUSTOM_EXPLOSION = 32;
int FL_SHOOT_PROJ_NO_GRAV = 64;
int FL_SHOOT_PROJ_NO_ORIENT = 128;
int FL_SHOOT_IN_WATER = 256;
int FL_SHOOT_NO_AUTOFIRE = 512;
int FL_SHOOT_DETONATE_SATCHELS = 1024;


enum shoot_types
{
	SHOOT_BULLETS,
	SHOOT_PROJECTILE,
	SHOOT_BEAM
}

enum bullet_impact
{
	BULLET_IMPACT_STANDARD,
	BULLET_IMPACT_MELEE,
	BULLET_IMPACT_EXPLODE,
}

enum spread_func
{
	SPREAD_GAUSSIAN,
	SPREAD_UNIFORM,
}

enum fire_mode
{
	PRIMARY,
	SECONDARY
}

enum projectile_action
{
	PROJ_ACT_DAMAGE,
	PROJ_ACT_EXPLODE,
	PROJ_ACT_BOUNCE,
	PROJ_ACT_ATTACH,
	PROJ_ACT_BOUNCE_RICO,
	PROJ_ACT_BOUNCE_EXP,
	PROJ_ACT_BOUNCE_RICO_EXP,
}

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
	PROJECTILE_WEAPON,
	PROJECTILE_CUSTOM,
	PROJECTILE_OTHER
}

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

enum windup_ease
{
	EASE_NONE,
	EASE_IN,
	EASE_OUT,
	EASE_INOUT,
	EASE_IN_HEAVY,
	EASE_OUT_HEAVY,
	EASE_INOUT_HEAVY
}

enum windup_actions
{
	WINDUP_SHOOT_ON_RELEASE,
	WINDUP_SHOOT_ONCE,
	WINDUP_SHOOT_CONSTANT,
}

enum player_anim_refs
{
	ANIM_REF_CROWBAR, // also includes wrench for windups
	ANIM_REF_GREN,
	ANIM_REF_TRIP,
	ANIM_REF_ONEHANDED,
	ANIM_REF_PYTHON, // One Hnaded with more recoil
	ANIM_REF_SHOTGUN,
	ANIM_REF_GAUSS,
	ANIM_REF_MP5,
	ANIM_REF_RPG,
	ANIM_REF_EGON,
	ANIM_REF_SQUEAK,
	ANIM_REF_HIVE,
	ANIM_REF_BOW, // also includes scope animations
	ANIM_REF_MINIGUN,
	ANIM_REF_UZIS,
	ANIM_REF_M16, // also includes grenade launch anim (m203)
	ANIM_REF_SNIPER, // also includes scope animations
	ANIM_REF_SAW,
}
array<string> g_panim_refs = {
	"crowbar", "gren", "trip", "onehanded", "python", "shotgun", "gauss", "mp5", 
	"rpg", "egon", "squeak", "hive", "bow", "minigun", "uzis", "m16", "sniper", "saw" 
};

class BeamOptions
{
	int type;
	int width;
	int noise;
	int scrollRate;
	float time;
	string sprite;
	Color color;
}

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
	float size;		  // hull size (all dimensions)
	string entity_class; // custom projectile entity
	string model;
	WeaponSound move_snd;
	string sprite;
	Vector angles;
	Vector avel;
	
	string trail_spr;
	int trail_sprId = 2; // remove me
	int trail_life;
	int trail_width;
	Color trail_color;
};

class WeaponSound
{
	string file;
	weapon_custom_sound@ options;

	bool play(CBaseEntity@ ent, SOUND_CHANNEL channel=CHAN_STATIC, float volMult=1.0f)
	{
		if (file.Length() == 0)
			return false;
		float volume = 1.0f;
		float attn = ATTN_NORM;
		int flags = 0;
		int pitch = getPitch();
		if (options !is null)
		{
			volume = options.pev.health / 100.0f;
			
			switch(options.pev.body)
			{
				case 1: attn = ATTN_IDLE; break;
				case 2: attn = ATTN_STATIC; break;
				case 3: attn = ATTN_NORM; break;
				case 4: attn = ATTN_NONE; break;
			}
			
			if (options.pev.skin == 2)
				flags |= SND_FORCE_SINGLE;
			if (options.pev.skin == 3)
				flags |= SND_FORCE_LOOP;
		}
		g_SoundSystem.EmitSoundDyn( ent.edict(), channel, file, volume*volMult, attn, flags, pitch );
		return true;
	}
	
	int getPitch()
	{
		if (options !is null)
		{
			int pitch_rand = options.pev.renderfx;
			return options.pev.rendermode + Math.RandomLong(-pitch_rand, pitch_rand);
		}
		return 100;
	}
	
	float getVolume()
	{
		if (options !is null)
		{
			return options.pev.health / 100.0f;
		}
		return 1.0f;
	}
	
	void stop(CBaseEntity@ ent, SOUND_CHANNEL channel=CHAN_STATIC)
	{
		g_SoundSystem.StopSound(ent.edict(), channel, file);
	}
}

array<WeaponSound> parseSounds(string val)
{
	array<string> strings = val.Split(";");
	array<WeaponSound> sounds;
	for (uint i = 0; i < strings.length(); i++)
	{
		WeaponSound s;
		s.file = strings[i];
		sounds.insertLast(s);
	}
	return sounds;
}

class weapon_custom_shoot : ScriptBaseEntity
{
	int shoot_type;
	array<WeaponSound> sounds; // shoot sounds
	array<string> shoot_anims; // shoot or melee swing
	array<string> melee_anims; // melee hit anims
	array<WeaponSound> melee_hit_sounds;
	array<WeaponSound> melee_flesh_sounds;
	int ammo_cost;
	float cooldown = 0.5;
	float recoil;
	float kickback;
	float knockback;
	float max_range;
	int bullets;
	int bullet_type; // see docs for "Bullet"
	int bullet_color;
	int bullet_spread_func;
	int bullet_impact;
	int bullet_decal;
	float bullet_damage;
	float bullet_spread;
	float bullet_delay; // burst fire delay
	
	float melee_miss_cooldown;
	
	ProjectileOptions@ projectile;
	
	string beam_impact_spr;
	int beam_ricochet_limit; // maximum number of ricochets
	
	int explosion_style;
	float explode_mag;
	float explode_damage;
	string explode_spr;
	WeaponSound explode_snd;
	int explode_decal;
	string explode_smoke_spr;
	Color explode_light;
	int explode_gibs;
	string explode_gib_mdl;
	int explode_gib_mat;
	
	array<WeaponSound> rico_snds;
	int rico_decal;
	string rico_part_spr;
	float rico_angle;
	int rico_part_count;
	int rico_part_scale;
	int rico_part_speed;
	int rico_trace_count;
	int rico_trace_color;
	int rico_trace_speed;
	
	float windup_time;
	float windup_min_time;
	float wind_down_time;
	float windup_mult;
	WeaponSound windup_snd;
	int windup_pitch_start;
	int windup_pitch_end;
	int windup_easing;
	int windup_action;
	int windup_cost;
	int windup_anim;
	int wind_down_anim;
	
	array<BeamOptions> beams = {BeamOptions(), BeamOptions()};
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if (projectile is null)
			@projectile = ProjectileOptions();
			
		if 		(szKey == "sounds")        sounds = parseSounds(szValue);					
		else if (szKey == "shoot_anims")   shoot_anims = szValue.Split(";");					
		else if (szKey == "ammo_cost")     ammo_cost = atoi(szValue);			
		else if (szKey == "shoot_type")    shoot_type = atoi(szValue);			
		else if (szKey == "cooldown")      cooldown = atof(szValue);
		else if (szKey == "recoil")        recoil = atof(szValue);
		else if (szKey == "kickback")      kickback = atof(szValue);
		else if (szKey == "knockback")     knockback = atof(szValue);
		else if (szKey == "max_range")     max_range = atof(szValue);
		
		else if (szKey == "bullets")       bullets = atoi(szValue);
		else if (szKey == "bullet_type")   bullet_type = atoi(szValue);
		else if (szKey == "bullet_damage") bullet_damage = atof(szValue);
		else if (szKey == "bullet_spread") bullet_spread = atof(szValue);
		else if (szKey == "bullet_delay")  bullet_delay = atof(szValue);
		else if (szKey == "bullet_color")  bullet_color = atoi(szValue);
		else if (szKey == "bullet_spread_func")  bullet_spread_func = atoi(szValue);
		else if (szKey == "bullet_impact")  bullet_impact = atoi(szValue);
		else if (szKey == "bullet_decal")  bullet_decal = atoi(szValue);
		
		else if (szKey == "melee_anims")   melee_anims = szValue.Split(";");			
		else if (szKey == "melee_hit_sounds")   melee_hit_sounds = parseSounds(szValue);			
		else if (szKey == "melee_flesh_sounds") melee_flesh_sounds = parseSounds(szValue);					
		else if (szKey == "melee_miss_cooldown") melee_miss_cooldown = atof(szValue);	
		
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
		else if (szKey == "projectile_mdl")    		  projectile.model = szValue;
		else if (szKey == "projectile_snd")    		  projectile.move_snd.file = szValue;
		else if (szKey == "projectile_spr")    		  projectile.sprite = szValue;
		else if (szKey == "projectile_size")          projectile.size = atof(szValue);
		else if (szKey == "projectile_trail_spr")     projectile.trail_spr = szValue;
		else if (szKey == "projectile_trail_life")    projectile.trail_life = atoi(szValue);
		else if (szKey == "projectile_trail_width")   projectile.trail_width = atoi(szValue);
		else if (szKey == "projectile_trail_color")   projectile.trail_color = parseColor(szValue);
		else if (szKey == "projectile_angles")  	  projectile.angles = parseVector(szValue);
		else if (szKey == "projectile_avel")  		  projectile.avel = parseVector(szValue);
				
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
		else if (szKey == "explode_snd")       explode_snd.file = szValue;
		else if (szKey == "explode_decal")     explode_decal = atoi(szValue);
		else if (szKey == "explode_smoke_spr") explode_smoke_spr = szValue;
		else if (szKey == "explode_dlight")    explode_light = parseColor(szValue);
		else if (szKey == "explode_gibs")      explode_gibs = atoi(szValue);
		else if (szKey == "explode_gib_model") explode_gib_mdl = szValue;
		else if (szKey == "explode_gib_mat")   explode_gib_mat = atoi(szValue);
		
		else if (szKey == "rico_snds")        rico_snds = parseSounds(szValue);	
		else if (szKey == "rico_decal")       rico_decal = atoi(szValue);
		else if (szKey == "rico_part_spr")    rico_part_spr = szValue;
		else if (szKey == "rico_part_count")  rico_part_count = atoi(szValue);
		else if (szKey == "rico_part_scale")  rico_part_scale = atoi(szValue);
		else if (szKey == "rico_part_speed")  rico_part_speed = atoi(szValue);
		else if (szKey == "rico_trace_count") rico_trace_count = atoi(szValue);
		else if (szKey == "rico_trace_speed") rico_trace_speed = atoi(szValue);
		else if (szKey == "rico_trace_color") rico_trace_color = atoi(szValue);
		else if (szKey == "rico_angle") 	  rico_angle = atof(szValue);
		
		else if (szKey == "windup_time") 	    windup_time = atof(szValue);
		else if (szKey == "windup_min_time") 	windup_min_time = atof(szValue);
		else if (szKey == "wind_down_time") 	wind_down_time = atof(szValue);
		else if (szKey == "windup_mult") 	    windup_mult = atof(szValue);
		else if (szKey == "windup_snd") 	    windup_snd.file = szValue;
		else if (szKey == "windup_pitch_start") windup_pitch_start = atoi(szValue);
		else if (szKey == "windup_pitch_end") 	windup_pitch_end = atoi(szValue);
		else if (szKey == "windup_easing") 		windup_easing = atoi(szValue);
		else if (szKey == "windup_action") 		windup_action = atoi(szValue);
		else if (szKey == "windup_cost") 		windup_cost = atoi(szValue);
		else if (szKey == "windup_anim") 		windup_anim = atoi(szValue);
		else if (szKey == "wind_down_anim") 	wind_down_anim = atoi(szValue);
		
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	void loadSoundSettings(WeaponSound@ snd)
	{
		CBaseEntity@ ent = g_EntityFuncs.FindEntityByTargetname(null, snd.file);
		if (ent !is null)
		{
			snd.file = ent.pev.message;
			@snd.options = cast<weapon_custom_sound@>(CastToScriptClass(ent));
		}
	}
	
	void loadSoundSettings(array<WeaponSound>@ sound_list)
	{
		for (uint k = 0; k < sound_list.length(); k++)
			loadSoundSettings(sound_list[k]);
	}
		
	void loadExternalSoundSettings()
	{
		loadSoundSettings(sounds);
		loadSoundSettings(melee_hit_sounds);
		loadSoundSettings(melee_flesh_sounds);
		loadSoundSettings(rico_snds);
		loadSoundSettings(windup_snd);
		loadSoundSettings(explode_snd);
		loadSoundSettings(projectile.move_snd);
	}
	
	WeaponSound@ getRandomShootSound()
	{
		if (sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, sounds.length()-1);
		return sounds[randIdx];
	}
	
	WeaponSound@ getRandomRicochetSound()
	{
		if (rico_snds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, rico_snds.length()-1);
		return rico_snds[randIdx];
	}
	
	WeaponSound@ getRandomMeleeHitSound()
	{
		if (melee_hit_sounds.length() == 0)
			return WeaponSound();
		int randIdx = Math.RandomLong(0, melee_hit_sounds.length()-1);
		return melee_hit_sounds[randIdx];
	}
	
	WeaponSound@ getRandomMeleeFleshSound()
	{
		if (melee_flesh_sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, melee_flesh_sounds.length()-1);
		return melee_flesh_sounds[randIdx];
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
		int iBullets = shoot_type == SHOOT_BULLETS ? bullets : 0; 
		//int iProjectiles = pev.spawnflags & FL_SHOOT_PROJECTILE != 0 ? 2 : 0; 
		float bps = (1.0f / cooldown) * iBullets;
		
		if (int(bps) > REC_BULLETS_PER_SECOND)
			println("\nWEAPON_CUSTOM WARNING: " + pev.targetname + " bullets per second (" + int(bps) + 
					") is greater than the max recommended (" + REC_BULLETS_PER_SECOND + ")\n"
					"Your game might freeze occasionally with 'Overflow 2048 temporary ents!' spammed in console\n");
		
		int iBeams = shoot_type == SHOOT_BEAM ? beam_ricochet_limit+1 : 0;
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
	
	bool can_fire_underwater() { return pev.spawnflags & FL_SHOOT_IN_WATER != 0; }
	
	void Precache()
	{
		for (uint i = 0; i < sounds.length(); i++)
			PrecacheSound(sounds[i].file);
		for (uint i = 0; i < melee_hit_sounds.length(); i++)
			PrecacheSound(melee_hit_sounds[i].file);
		for (uint i = 0; i < melee_flesh_sounds.length(); i++)
			PrecacheSound(melee_flesh_sounds[i].file);
		for (uint i = 0; i < rico_snds.length(); i++)
			PrecacheSound(rico_snds[i].file);
		PrecacheSound(windup_snd.file);
			
		PrecacheSound(projectile.move_snd.file);
		PrecacheModel(beam_impact_spr);
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
		if (projectile.type == PROJECTILE_HVR)
			PrecacheModel( "models/HVR.mdl" );
			
		PrecacheModel( projectile.model );
		PrecacheModel( projectile.sprite );
		if (projectile.trail_spr.Length() > 0)
			projectile.trail_sprId = PrecacheModel( projectile.trail_spr );
			
		PrecacheModel( explode_spr );
		PrecacheModel( explode_smoke_spr );
		PrecacheModel( explode_gib_mdl );
		PrecacheSound( explode_snd.file );
			
		if (projectile.entity_class.Length() > 0)
			g_Game.PrecacheOther( projectile.entity_class );
			
		if (rico_part_spr.Length() > 0)
			PrecacheModel(rico_part_spr);		
			
		
		
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
	
	string secondary_fire;
	string secondary_reload_snd;
	string secondary_empty_snd;
	string secondary_ammo_type;
	
	string tertiary_fire;
	string tertiary_empty_snd;
	int tertiary_ammo_type;
	
	string wpn_v_model;
	string wpn_w_model;
	string wpn_p_model;
	string hud_sprite;
	string hud_sprite_folder;
	
	array<string> idle_anims;
	
	float idle_time;
	
	int deploy_anim;
	int player_anims;
	int slot;
	int slotPosition;
	int priority; // auto switch priority
	
	// primary and secondary fire settings
	array<weapon_custom_shoot@> fire_settings =
	{ weapon_custom_shoot(), weapon_custom_shoot(), weapon_custom_shoot() }; 
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// Only custom keyvalues get sent here
		if (szKey == "weapon_name") weapon_classname = szValue;
		
		else if (szKey == "primary_fire") primary_fire = szValue;
		else if (szKey == "primary_reload_snd") primary_reload_snd = szValue;
		else if (szKey == "primary_empty_snd") primary_empty_snd = szValue;
		else if (szKey == "primary_ammo") primary_ammo_type = szValue;
		
		else if (szKey == "secondary_fire") secondary_fire = szValue;
		else if (szKey == "secondary_reload_snd") secondary_reload_snd = szValue;
		else if (szKey == "secondary_empty_snd") secondary_empty_snd = szValue;
		else if (szKey == "secondary_ammo") secondary_ammo_type = szValue;
		
		else if (szKey == "tertiary_fire") tertiary_fire = szValue;
		else if (szKey == "tertiary_empty_snd") tertiary_empty_snd = szValue;
		else if (szKey == "tertiary_ammo") tertiary_ammo_type = atoi(szValue);
		
		else if (szKey == "weapon_slot") slot = atoi(szValue);
		else if (szKey == "weapon_slot_pos") slotPosition = atoi(szValue);
		else if (szKey == "wpn_v_model") wpn_v_model = szValue;
		else if (szKey == "wpn_w_model") wpn_w_model = szValue;
		else if (szKey == "wpn_p_model") wpn_p_model = szValue;
		else if (szKey == "deploy_anim") deploy_anim = atoi(szValue);
		else if (szKey == "idle_anims") idle_anims = szValue.Split(";");
		else if (szKey == "idle_time") idle_time = atof(szValue);
		
		else if (szKey == "hud_sprite") hud_sprite = szValue;
		else if (szKey == "sprite_directory") hud_sprite_folder = szValue;
		else if (szKey == "weapon_priority") priority = atoi(szValue);
		else if (szKey == "player_anims") player_anims = atoi(szValue);
		else return BaseClass.KeyValue( szKey, szValue );
			
		return true;
	}
	
	int clip_size()                      { return self.pev.skin; }
	weapon_custom_shoot@ get_shoot_settings(int fmode) { return @fire_settings[fmode]; }
	
	string getPlayerAnimExt()
	{
		if (player_anims < 0 or player_anims >= int(g_panim_refs.length()))
			return g_panim_refs[ANIM_REF_ONEHANDED];
		return g_panim_refs[player_anims];
	}
	
	int getRandomIdleAnim()
	{
		if (idle_anims.length() == 0)
			return 0;
		int randIdx = Math.RandomLong(0, idle_anims.length()-1);
		return atoi( idle_anims[randIdx] );
	}
	
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

class weapon_custom_sound : ScriptBaseEntity
{	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{
		Precache();
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
		PrecacheSound(pev.message);
	}
};
