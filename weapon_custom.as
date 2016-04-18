#include "utils"
#include "WeaponCustomBase"

/*
 * Defines and initializes the weapon_custom and weapon_custom_shoot entites.
 */

void test()
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "beam"); 

		if (ent !is null)
		{
			CBeam@ beam = cast<CBeam@>(ent);
			println("BEAM COLOR: " + beam.pev.rendercolor.ToString() + " " + beam.pev.renderamt + 
					" WIDTH: " + beam.GetWidth() + " NOISE: " + beam.GetNoise());
			// do nothing
		}
	} while (ent !is null);
}
 
void MapInit()
{
	g_Scheduler.SetInterval("test", 0.05);
	WeaponCustomMapInit();
	
	// TODO: Fix really weird bug where manually placed weapons don't spawn.
	// It seems like weapon_test spawns before weapon_test is registered and so it doesn't initialize properly
	// Making a copy of the weapon in hammer seems to fix it (gets placed at the end of the entity list?)
}

void MapActivate()
{
	WeaponCustomMapActive();
}

string g_watersplash_spr = "sprites/wep_smoke_01.spr";

void WeaponCustomMapInit()
{	
	g_Game.PrecacheModel( g_watersplash_spr ); // used for water splash effect
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom", "weapon_custom" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_shoot", "weapon_custom_shoot" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_bullet", "weapon_custom_bullet" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_melee", "weapon_custom_melee" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_projectile", "weapon_custom_projectile" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_beam", "weapon_custom_beam" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_sound", "weapon_custom_sound" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_effect", "weapon_custom_effect" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_custom_user_effect", "weapon_custom_user_effect" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustomProjectile", "custom_projectile" );
}

void WeaponCustomMapActive()
{	
	// Hook up weapon_custom with weapon_custom_shoot
	array<string>@ keys = custom_weapons.getKeys();
	for (uint i = 0; i < keys.length(); i++)
	{
		weapon_custom@ wep = cast<weapon_custom@>( custom_weapons[keys[i]] );
		wep.loadExternalSoundSettings();
		
		if (wep.primary_fire.Length() == 0 and wep.secondary_fire.Length() == 0)
		{
			println(logPrefix + wep.weapon_classname + " has no primary or secondary fire function set");
			continue;
		}
		
		bool foundPrimary = false;
		bool foundAltPrimary = false;
		bool foundSecondary = false;
		bool foundTertiary = false;
		array<string>@ keys2 = custom_weapon_shoots.getKeys();
		for (uint k = 0; k < keys2.length(); k++)
		{
			weapon_custom_shoot@ shoot = cast<weapon_custom_shoot@>( custom_weapon_shoots[keys2[k]] );
			if (shoot.pev.targetname == wep.primary_fire and wep.primary_fire.Length() > 0) {
				@wep.fire_settings[0] = shoot;
				@shoot.weapon = wep;
				foundPrimary = true;
			}
			if (shoot.pev.targetname == wep.secondary_fire and wep.secondary_fire.Length() > 0) {
				@wep.fire_settings[1] = shoot;
				@shoot.weapon = wep;
				foundSecondary = true;
			}
			if (shoot.pev.targetname == wep.tertiary_fire and wep.tertiary_fire.Length() > 0) {
				@wep.fire_settings[2] = shoot;
				@shoot.weapon = wep;
				foundTertiary = true;
			}
			if (shoot.pev.targetname == wep.primary_alt_fire and wep.primary_alt_fire.Length() > 0) {
				@wep.alt_fire_settings[0] = shoot;
				@shoot.weapon = wep;
				foundAltPrimary = true;
			}
		}
		if (!foundPrimary and wep.primary_fire.Length() > 0)
			println(logPrefix + " Couldn't find primary fire entity " + wep.primary_fire + " for " + wep.weapon_classname);
		if (!foundSecondary and wep.secondary_fire.Length() > 0)
			println(logPrefix + " Couldn't find secondary fire entity '" + wep.secondary_fire + "' for " + wep.weapon_classname);
		if (!foundTertiary and wep.tertiary_fire.Length() > 0)
			println(logPrefix + " Couldn't find tertiary fire entity " + wep.tertiary_fire + " for " + wep.weapon_classname);
		if (!foundAltPrimary and wep.primary_alt_fire.Length() > 0)
			println(logPrefix + " Couldn't find alternate primary fire entity " + wep.primary_alt_fire + " for " + wep.weapon_classname);
	}
	
	// Hook up ambient_generic with weapon_custom_shoot
	keys = custom_weapon_shoots.getKeys();
	for (uint i = 0; i < keys.length(); i++)
	{
		weapon_custom_shoot@ shoot = cast<weapon_custom_shoot@>( custom_weapon_shoots[keys[i]] );
		shoot.loadExternalSoundSettings();
		shoot.loadExternalEffectSettings();
	}
}

// WeaponCustomBase will read this to get weapon_custom settings
// Also let's us know which weapon slots are used (Auto weapon slot position depends on this)
dictionary custom_weapons;
dictionary custom_weapon_shoots;
dictionary custom_weapon_effects;

int MAX_BEAMS = 256; // any more and you get console spam and game freezes (acutal max is 258 or 259 I think)
int REC_BEAMS = 8; // 8 * 32 players = 256
int MAX_WEAPON_SLOT_POSITION = 10;
int MIN_WEAPON_SLOT_POSITION = 5;
int MAX_WEAPON_SLOT = 5;
int REC_BULLETS_PER_SECOND = 32; // max recommended bullets per second (shotgun has most BPS)
bool debug_mode = false;

// weapon spawn flags
int FL_WEP_HIDE_SECONDARY_AMMO = 32;
int FL_WEP_LASER_SIGHT = 64;
int FL_WEP_CONTINUOUS_RELOAD = 128;

// shoot spawn flags
int FL_SHOOT_IF_NOT_DAMAGE = 1;
int FL_SHOOT_IF_NOT_MISS = 2;
int FL_SHOOT_NO_MELEE_SOUND_OVERLAP = 4;
int FL_SHOOT_RESPONSIVE_WINDUP = 8;
int FL_SHOOT_PARTIAL_AMMO_SHOOT = 16;
int FL_SHOOT_QUAKE_MUZZLEFLASH = 32;
int FL_SHOOT_PROJ_NO_GRAV = 64;
int FL_SHOOT_PROJ_NO_ORIENT = 128;
int FL_SHOOT_IN_WATER = 256;
int FL_SHOOT_NO_AUTOFIRE = 512;
int FL_SHOOT_DETONATE_SATCHELS = 1024;

// shoot effect flags
int FL_EFFECT_EXPLOSION = 1;
int FL_EFFECT_RICOCHET = 2;
int FL_EFFECT_SPARKS = 4;
int FL_EFFECT_LIGHTS = 8;
int FL_EFFECT_BUBBLES_IN_AIR = 16;
int FL_EFFECT_GUNSHOT_RICOCHET = 32;
int FL_EFFECT_TARBABY = 64;
int FL_EFFECT_TARBABY2 = 128;
int FL_EFFECT_BURST = 256;
int FL_EFFECT_LAVA = 512;
int FL_EFFECT_TELEPORT = 1024;

// User effect flags
int FL_UEFFECT_USER_SOUNDS = 1;

// shoot sound flags
int FL_SOUND_NO_WATER_EFFECT = 1;

float REVIVE_RADIUS = 64;


enum shoot_types
{
	SHOOT_BULLETS,
	SHOOT_MELEE,
	SHOOT_PROJECTILE,
	SHOOT_BEAM
}

enum tertiary_ammo_types
{
	TAMMO_NONE,
	TAMMO_SAME_AS_PRIMARY,
	TAMMO_SAME_AS_SECONDARY
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
	PROJ_ACT_IMPACT=1,
	PROJ_ACT_BOUNCE,
	PROJ_ACT_ATTACH
}

enum projectile_type
{
	PROJECTILE_ARGRENADE=1,
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
	BEAM_LINEAR_OPAQUE,
	BEAM_SPIRAL_OPAQUE,
	BEAM_PROJECTILE
}

enum explosion_types
{
	EXPLODE_SPRITE_PARTICLES,
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
	WINDUP_SHOOT_ONCE_IF_HELD,
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

enum heal_modes
{
	HEAL_OFF,
	HEAL_FRIENDS,
	HEAL_FOES,
	HEAL_ALL,
	HEAL_REVIVE_FRIENDS,
	HEAL_REVIVE_FOES,
	HEAL_REVIVE_ALL,
}

enum hook_types
{
	HOOK_DISABLED,
	HOOK_PROJECTILE,
	HOOK_INSTANT
}

enum hook_modes
{
	HOOK_MODE_PULL,
	HOOK_MODE_REPEL,
	HOOK_MODE_SWING,
}

enum heal_targets
{
	HEALT_HUMANS,
	HEALT_ALIENS,
	HEALT_MACHINES,
	HEALT_BREAKABLES,
	HEALT_MACHINES_AND_BREAKABLES,
	HEALT_HUMANS_AND_ALIENS,
	HEALT_EVERYTHING,
}

enum shell_types
{
	SHELL_NONE,
	SHELL_SMALL,
	SHELL_LARGE,
	SHELL_SHOTGUN,
}

enum fire_actions
{
	FIRE_ACT_SHOOT,
	FIRE_ACT_LASER,
	FIRE_ACT_ZOOM,
	FIRE_ACT_ALT
}

enum overcharge_actions
{
	OVERCHARGE_CONTINUE,
	OVERCHARGE_CANCEL,
	OVERCHARGE_SHOOT
}

enum projectile_follow_modes
{
	FOLLOW_NONE,
	FOLLOW_CROSSHAIRS,
	FOLLOW_ENEMIES,
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
	int type = PROJECTILE_CUSTOM;
	int world_event = PROJ_ACT_ATTACH;
	int monster_event = PROJ_ACT_ATTACH;
	float speed = 0;
	float life = 0;
	float elasticity = 0.8; // percentage of reflected velocity
	float size = 0.001;		  // hull size (all dimensions)
	string entity_class; // custom projectile entity
	string model;
	WeaponSound move_snd;
	string sprite;
	Vector angles;
	Vector avel;
	Vector offset;
	Vector player_vel_inf;
	
	int follow_mode = FOLLOW_NONE;
	float follow_radius = 0.0f;
	float follow_angle = 30.0f;
	Vector follow_time;
	
	string trail_spr;
	int trail_sprId = 2; // remove me
	int trail_life;
	int trail_width;
	Color trail_color;
};

class weapon_custom_bullet : weapon_custom_shoot
{
	void Spawn()
	{
		weapon_custom_shoot::Spawn();
		shoot_type = SHOOT_BULLETS;
	}
};

class weapon_custom_melee : weapon_custom_shoot 
{
	void Spawn()
	{
		weapon_custom_shoot::Spawn();
		shoot_type = SHOOT_MELEE;
		bullet_impact = BULLET_IMPACT_MELEE;
	}
};

class weapon_custom_projectile : weapon_custom_shoot 
{
	void Spawn()
	{
		weapon_custom_shoot::Spawn();
		shoot_type = SHOOT_PROJECTILE;
	}
};

class weapon_custom_beam : weapon_custom_shoot 
{
	void Spawn()
	{
		weapon_custom_shoot::Spawn();
		shoot_type = SHOOT_BEAM;
	}
};

class weapon_custom_shoot : ScriptBaseEntity
{
	weapon_custom@ weapon;
	int shoot_type;
	array<WeaponSound> sounds; // shoot sounds
	array<WeaponSound> cooldown_sounds; // shoot sounds
	array<string> shoot_anims; // shoot or melee swing
	array<string> melee_anims; // melee hit anims
	array<WeaponSound> melee_hit_sounds;
	array<WeaponSound> melee_flesh_sounds;
	array<WeaponSound> shoot_fail_snds;
	WeaponSound shoot_empty_snd;
	int shoot_empty_anim;
	int ammo_cost;
	float cooldown = 0.5;
	float cooldown_sound_delay;
	Vector recoil;
	float kickback;
	float knockback;
	float max_range;
	int heal_mode;
	int heal_targets;
	
	float damage;
	int damage_type;
	int damage_type2;
	int gib_type;
	
	int bullets;
	int bullet_type; // see docs for "Bullet"
	int bullet_color = -1;
	int bullet_spread_func;
	int bullet_impact;
	int bullet_decal;
	float bullet_spread;
	float bullet_delay; // burst fire delay
	
	float melee_miss_cooldown;
	
	ProjectileOptions@ projectile;
	
	float beam_impact_speed;
	string beam_impact_spr;
	int beam_impact_spr_scale;
	int beam_impact_spr_fps;
	int beam_impact_spr_opacity;
	int beam_ricochet_limit; // maximum number of ricochets
	
	weapon_custom_effect@ effect1 = weapon_custom_effect();
	weapon_custom_effect@ effect2 = weapon_custom_effect();
	weapon_custom_effect@ effect3 = weapon_custom_effect();
	
	weapon_custom_user_effect@ user_effect1;
	weapon_custom_user_effect@ user_effect2;
	weapon_custom_user_effect@ user_effect3;
	string user_effect1_str;
	string user_effect2_str;
	string user_effect3_str;
	
	float rico_angle;
	Vector muzzle_flash_color;
	Vector muzzle_flash_adv;
	WeaponSound toggle_snd;
	string toggle_txt;
	
	float windup_time;
	float windup_min_time;
	float wind_down_time;
	float windup_mult;
	float windup_kick_mult;
	float windup_anim_time;
	WeaponSound windup_snd;
	int windup_pitch_start;
	int windup_pitch_end;
	int windup_easing;
	int windup_action;
	int windup_cost;
	int windup_anim;
	int wind_down_anim;
	int windup_anim_loop;
	float windup_overcharge_time;
	float windup_overcharge_cooldown;
	int windup_overcharge_action;
	int windup_overcharge_anim;
	
	int hook_type;
	int hook_pull_mode;
	int hook_anim;
	int hook_anim2;
	float hook_force;
	float hook_speed;
	float hook_max_speed;
	float hook_delay;
	float hook_delay2;
	string hook_texture_filter;
	WeaponSound hook_snd;
	WeaponSound hook_snd2;
	
	int shell_type = 0;
	string shell_model;
	Vector shell_offset;
	Vector shell_vel;
	float shell_delay;
	WeaponSound shell_delay_snd;
	float shell_spread;
	int shell_idx;
	
	array<BeamOptions> beams = {BeamOptions(), BeamOptions()};
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if (projectile is null)
			@projectile = ProjectileOptions();
			
		if 		(szKey == "sounds")        sounds = parseSounds(szValue);					
		else if (szKey == "shoot_fail_snds") shoot_fail_snds = parseSounds(szValue);					
		else if (szKey == "cooldown_sounds") cooldown_sounds = parseSounds(szValue);					
		else if (szKey == "shoot_anims")   shoot_anims = szValue.Split(";");					
		else if (szKey == "shoot_empty_snd")  shoot_empty_snd.file = szValue;					
		else if (szKey == "shoot_empty_anim") shoot_empty_anim = atoi(szValue);			
		else if (szKey == "ammo_cost")     ammo_cost = atoi(szValue);			
		//else if (szKey == "shoot_type")    shoot_type = atoi(szValue);			
		else if (szKey == "cooldown")      cooldown = atof(szValue);
		else if (szKey == "cooldown_sound_delay") cooldown_sound_delay = atof(szValue);
		else if (szKey == "recoil")        recoil = parseVector(szValue);
		else if (szKey == "kickback")      kickback = atof(szValue);
		else if (szKey == "knockback")     knockback = atof(szValue);
		else if (szKey == "max_range")     max_range = atof(szValue);
		else if (szKey == "heal_mode")     heal_mode = atoi(szValue);
		else if (szKey == "heal_targets")  heal_targets = atoi(szValue);
		
		else if (szKey == "damage_amt")  damage = atof(szValue);
		else if (szKey == "damage_type")  damage_type = atoi(szValue);
		else if (szKey == "damage_type2")  damage_type2 = atoi(szValue);
		else if (szKey == "gib_type")  gib_type = atoi(szValue);
		
		else if (szKey == "shell_type")   shell_type = atoi(szValue);
		else if (szKey == "shell_model")  shell_model = szValue;
		else if (szKey == "shell_offset") shell_offset = parseVector(szValue);
		else if (szKey == "shell_vel")    shell_vel = parseVector(szValue);
		else if (szKey == "shell_spread") shell_spread = atof(szValue);
		else if (szKey == "shell_delay") shell_delay = atof(szValue);
		else if (szKey == "shell_delay_snd") shell_delay_snd.file = szValue;
		
		else if (szKey == "bullets")       bullets = atoi(szValue);
		else if (szKey == "bullet_type")   bullet_type = atoi(szValue);
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
		
		else if (szKey == "hook_type") hook_type = atoi(szValue);	
		else if (szKey == "hook_pull_mode") hook_pull_mode = atoi(szValue);	
		else if (szKey == "hook_anim") hook_anim = atoi(szValue);	
		else if (szKey == "hook_anim2") hook_anim2 = atoi(szValue);	
		else if (szKey == "hook_force") hook_force = atof(szValue);	
		else if (szKey == "hook_speed") hook_speed = atof(szValue);	
		else if (szKey == "hook_max_speed") hook_max_speed = atof(szValue);	
		else if (szKey == "hook_delay") hook_delay = atof(szValue);	
		else if (szKey == "hook_delay2") hook_delay2 = atof(szValue);	
		else if (szKey == "hook_texture_filter") hook_texture_filter = szValue;	
		else if (szKey == "hook_sound") hook_snd.file = szValue;	
		else if (szKey == "hook_sound2") hook_snd2.file = szValue;	
		
		else if (szKey == "projectile_type")          projectile.type = atoi(szValue);
		else if (szKey == "projectile_world_event")   projectile.world_event = atoi(szValue);
		else if (szKey == "projectile_monster_event") projectile.monster_event = atoi(szValue);
		else if (szKey == "projectile_speed")         projectile.speed = atof(szValue);
		else if (szKey == "projectile_life")          projectile.life = atof(szValue);
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
		else if (szKey == "projectile_offset")  	  projectile.offset = parseVector(szValue);
		else if (szKey == "projectile_player_vel_inf")projectile.player_vel_inf = parseVector(szValue);
		else if (szKey == "projectile_follow_mode")   projectile.follow_mode = atoi(szValue);
		else if (szKey == "projectile_follow_radius") projectile.follow_radius = atof(szValue);
		else if (szKey == "projectile_follow_angle")  projectile.follow_angle = atof(szValue);
		else if (szKey == "projectile_follow_time")   projectile.follow_time = parseVector(szValue);
				
		else if (szKey == "beam_impact_speed")       beam_impact_speed = atof(szValue);
		else if (szKey == "beam_impact_spr")         beam_impact_spr = szValue;
		else if (szKey == "beam_impact_spr_scale")   beam_impact_spr_scale = atoi(szValue);
		else if (szKey == "beam_impact_spr_fps")     beam_impact_spr_fps = atoi(szValue);
		else if (szKey == "beam_impact_spr_opacity") beam_impact_spr_opacity = atoi(szValue);
		else if (szKey == "beam_ricochet_limit")     beam_ricochet_limit = atoi(szValue);
		
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
		
		else if (szKey == "effect1_name") 	  effect1.name = szValue;
		else if (szKey == "effect2_name") 	  effect2.name = szValue;	
		else if (szKey == "effect3_name") 	  effect3.name = szValue;
		else if (szKey == "user_effect1") 	  user_effect1_str = szValue;
		else if (szKey == "user_effect2") 	  user_effect2_str = szValue;
		else if (szKey == "user_effect3") 	  user_effect3_str = szValue;
		
		else if (szKey == "rico_angle") 	  rico_angle = atof(szValue);		
		else if (szKey == "muzzle_flash_color") muzzle_flash_color = parseVector(szValue);		
		else if (szKey == "muzzle_flash_adv")   muzzle_flash_adv = parseVector(szValue);		
		else if (szKey == "toggle_snd")   toggle_snd.file = szValue;	
		else if (szKey == "toggle_txt")   toggle_txt = szValue;		
		
		else if (szKey == "windup_time") 	    windup_time = atof(szValue);
		else if (szKey == "windup_min_time") 	windup_min_time = atof(szValue);
		else if (szKey == "wind_down_time") 	wind_down_time = atof(szValue);
		else if (szKey == "windup_mult") 	    windup_mult = atof(szValue);
		else if (szKey == "windup_kick_mult") 	windup_kick_mult = atof(szValue);
		else if (szKey == "windup_snd") 	    windup_snd.file = szValue;
		else if (szKey == "windup_pitch_start") windup_pitch_start = atoi(szValue);
		else if (szKey == "windup_pitch_end") 	windup_pitch_end = atoi(szValue);
		else if (szKey == "windup_easing") 		windup_easing = atoi(szValue);
		else if (szKey == "windup_action") 		windup_action = atoi(szValue);
		else if (szKey == "windup_cost") 		windup_cost = atoi(szValue);
		else if (szKey == "windup_anim") 		windup_anim = atoi(szValue);
		else if (szKey == "wind_down_anim") 	wind_down_anim = atoi(szValue);
		else if (szKey == "windup_anim_time") 	windup_anim_time = atof(szValue);
		else if (szKey == "windup_anim_loop") 	windup_anim_loop = atoi(szValue);
		else if (szKey == "windup_overcharge_time") windup_overcharge_time = atof(szValue);
		else if (szKey == "windup_overcharge_cooldown") windup_overcharge_cooldown = atof(szValue);
		else if (szKey == "windup_overcharge_action") windup_overcharge_action = atoi(szValue);
		else if (szKey == "windup_overcharge_anim") windup_overcharge_anim = atoi(szValue);
		
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	 
	bool isPrimary()
	{
		return @weapon.fire_settings[0] == @this;
	}
	
	bool isSecondary()
	{
		return @weapon.fire_settings[1] == @this;
	}
	
	bool isTertiary()
	{
		return @weapon.fire_settings[2] == @this;
	}
		
	void loadExternalSoundSettings()
	{
		loadSoundSettings(sounds);
		loadSoundSettings(melee_hit_sounds);
		loadSoundSettings(melee_flesh_sounds);
		loadSoundSettings(shoot_fail_snds);
		loadSoundSettings(cooldown_sounds);
		loadSoundSettings(windup_snd);
		loadSoundSettings(hook_snd);
		loadSoundSettings(hook_snd2);
		loadSoundSettings(projectile.move_snd);
		loadSoundSettings(toggle_snd);
		loadSoundSettings(shell_delay_snd);
		loadSoundSettings(shoot_empty_snd);
	}
	
	void loadExternalEffectSettings()
	{
		@effect1 = loadEffectSettings(effect1);
		@effect2 = loadEffectSettings(effect2);
		@effect3 = loadEffectSettings(effect3);
		
		@user_effect1 = loadUserEffectSettings(user_effect1, user_effect1_str);
		@user_effect2 = loadUserEffectSettings(user_effect2, user_effect2_str);
		@user_effect3 = loadUserEffectSettings(user_effect3, user_effect3_str);
	}
	
	int damageType(int defaultType)
	{
		int dtype = defaultType;
		if (damage_type >= 0)
			dtype = damage_type;
		return dtype | damage_type2 | gib_type;
	}
	
	WeaponSound@ getRandomShootSound()
	{
		if (sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, sounds.length()-1);
		return sounds[randIdx];
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
	
	WeaponSound@ getRandomShootFailSound()
	{
		if (shoot_fail_snds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, shoot_fail_snds.length()-1);
		return shoot_fail_snds[randIdx];
	}
	
	WeaponSound@ getRandomCooldownSound()
	{
		if (cooldown_sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, cooldown_sounds.length()-1);
		return cooldown_sounds[randIdx];
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
		
		custom_weapon_shoots[pev.targetname] = @this;
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
		for (uint i = 0; i < shoot_fail_snds.length(); i++)
			PrecacheSound(shoot_fail_snds[i].file);
		
		PrecacheSound(windup_snd.file);
		PrecacheSound(hook_snd.file);
		PrecacheSound(hook_snd2.file);
		PrecacheSound(toggle_snd.file);
		PrecacheSound(shell_delay_snd.file);
		PrecacheSound(shoot_empty_snd.file);
			
		PrecacheSound(projectile.move_snd.file);
		PrecacheModel(beam_impact_spr);
		PrecacheModel(beams[0].sprite);
		PrecacheModel(beams[1].sprite);
		PrecacheModel(shell_model);
		
		// TODO: PrecacheOther for custom entities
		
		if (projectile.type == PROJECTILE_ARGRENADE)
			PrecacheModel( "models/grenade.mdl" );
		if (projectile.type == PROJECTILE_MORTAR)
		{
			PrecacheModel( "models/mortarshell.mdl" );
			PrecacheSound( "weapons/ofmortar.wav" );
		}
		if (projectile.type == PROJECTILE_HVR)
			PrecacheModel( "models/HVR.mdl" );
			
		PrecacheModel( projectile.model );
		PrecacheModel( projectile.sprite );
		if (projectile.trail_spr.Length() > 0)
			projectile.trail_sprId = PrecacheModel( projectile.trail_spr );
			
		if (projectile.entity_class.Length() > 0)
			g_Game.PrecacheOther( projectile.entity_class );	

		switch(shell_type)
		{
			case SHELL_SMALL:
				shell_idx = g_Game.PrecacheModel( "models/shell.mdl" );
				break;
			case SHELL_LARGE:
				shell_idx = g_Game.PrecacheModel( "models/saw_shell.mdl" );
				break;
			case SHELL_SHOTGUN:
				shell_idx = g_Game.PrecacheModel( "models/shotgunshell.mdl" );
				break;
		}
		if (shell_model.Length() > 0)
			shell_idx = g_Game.PrecacheModel( shell_model );
		
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
	string primary_alt_fire;
	WeaponSound primary_reload_snd;
	WeaponSound primary_empty_snd;
	string primary_ammo_type;
	float primary_regen_time;
	int primary_regen_amt;
	
	int secondary_action;
	string secondary_fire;
	WeaponSound secondary_reload_snd;
	WeaponSound secondary_empty_snd;
	string secondary_ammo_type;
	float secondary_regen_time;
	int secondary_regen_amt;
	
	int tertiary_action;
	string tertiary_fire;
	WeaponSound tertiary_empty_snd;
	int tertiary_ammo_type;
	
	string wpn_v_model;
	string wpn_w_model;
	string wpn_p_model;
	string hud_sprite;
	string hud_sprite_folder;
	string laser_sprite;
	int zoom_fov;
	int max_live_projectiles = 0;
	
	array<string> idle_anims;
	
	float idle_time;
	float reload_time;
	float deploy_time;
	
	WeaponSound reload_snd;
	WeaponSound reload_start_snd;
	WeaponSound reload_end_snd;
	float reload_start_time;
	float reload_end_time;
	int reload_start_anim;
	int reload_end_anim;
	int reload_ammo_amt;
	int reload_anim;
	int reload_empty_anim;
	
	int deploy_anim;
	int player_anims;
	int slot;
	int slotPosition;
	int priority; // auto switch priority
	
	bool matchingAmmoTypes = false;
	
	// primary and secondary fire settings
	array<weapon_custom_shoot@> fire_settings =
	{ weapon_custom_shoot(), weapon_custom_shoot(), weapon_custom_shoot() };
	
	array<weapon_custom_shoot@> alt_fire_settings =
	{ weapon_custom_shoot(), weapon_custom_shoot(), weapon_custom_shoot() }; 
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// Only custom keyvalues get sent here
		if (szKey == "weapon_name") weapon_classname = szValue;
		
		else if (szKey == "primary_fire") primary_fire = szValue;
		else if (szKey == "primary_alt_fire") primary_alt_fire = szValue;
		else if (szKey == "primary_reload_snd") primary_reload_snd.file = szValue;
		else if (szKey == "primary_empty_snd") primary_empty_snd.file = szValue;
		else if (szKey == "primary_ammo") primary_ammo_type = szValue;
		else if (szKey == "primary_regen_time") primary_regen_time = atof(szValue);
		else if (szKey == "primary_regen_amt") primary_regen_amt = atoi(szValue);
		
		else if (szKey == "secondary_action") secondary_action = atoi(szValue);
		else if (szKey == "secondary_fire") secondary_fire = szValue;
		else if (szKey == "secondary_reload_snd") secondary_reload_snd.file = szValue;
		else if (szKey == "secondary_empty_snd") secondary_empty_snd.file = szValue;
		else if (szKey == "secondary_ammo") secondary_ammo_type = szValue;
		else if (szKey == "secondary_regen_time") secondary_regen_time = atof(szValue);
		else if (szKey == "secondary_regen_amt") secondary_regen_amt = atoi(szValue);
		
		else if (szKey == "tertiary_action") tertiary_action = atoi(szValue);
		else if (szKey == "tertiary_fire") tertiary_fire = szValue;
		else if (szKey == "tertiary_empty_snd") tertiary_empty_snd.file = szValue;
		else if (szKey == "tertiary_ammo") tertiary_ammo_type = atoi(szValue);
		
		else if (szKey == "reload_snd") reload_snd.file = szValue;
		else if (szKey == "reload_start_snd") reload_start_snd.file = szValue;
		else if (szKey == "reload_end_snd") reload_end_snd.file = szValue;
		else if (szKey == "reload_start_time") reload_start_time = atof(szValue);
		else if (szKey == "reload_end_time") reload_end_time = atof(szValue);
		else if (szKey == "reload_start_anim") reload_start_anim = atoi(szValue);
		else if (szKey == "reload_end_anim") reload_end_anim = atoi(szValue);
		else if (szKey == "reload_ammo_amt") reload_ammo_amt = atoi(szValue);
		
		else if (szKey == "weapon_slot") slot = atoi(szValue);
		else if (szKey == "weapon_slot_pos") slotPosition = atoi(szValue);
		else if (szKey == "wpn_v_model") wpn_v_model = szValue;
		else if (szKey == "wpn_w_model") wpn_w_model = szValue;
		else if (szKey == "wpn_p_model") wpn_p_model = szValue;
		else if (szKey == "reload_anim") reload_anim = atoi(szValue);
		else if (szKey == "reload_empty_anim") reload_empty_anim = atoi(szValue);
		else if (szKey == "deploy_anim") deploy_anim = atoi(szValue);
		else if (szKey == "idle_anims") idle_anims = szValue.Split(";");
		else if (szKey == "idle_time") idle_time = atof(szValue);
		else if (szKey == "reload_time") reload_time = atof(szValue);
		else if (szKey == "deploy_time") deploy_time = atof(szValue);
		else if (szKey == "zoom_fov") zoom_fov = atoi(szValue);
		
		else if (szKey == "laser_sprite") laser_sprite = szValue;
		else if (szKey == "hud_sprite") hud_sprite = szValue;
		else if (szKey == "sprite_directory") hud_sprite_folder = szValue;
		else if (szKey == "weapon_priority") priority = atoi(szValue);
		else if (szKey == "player_anims") player_anims = atoi(szValue);
		else if (szKey == "projectile_max_alive") max_live_projectiles = atoi(szValue);
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
			
		// there aren't actually 6 weapons in this slot, but pos 5 and 6 don't work for some reason
		if (slot == 1 and position < 7)
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
	
	void loadExternalSoundSettings()
	{
		loadSoundSettings(primary_reload_snd);
		loadSoundSettings(primary_empty_snd);
		loadSoundSettings(secondary_reload_snd);
		loadSoundSettings(secondary_empty_snd);
		loadSoundSettings(reload_snd);
		loadSoundSettings(reload_start_snd);
		loadSoundSettings(reload_end_snd);
	}
	
	void Spawn()
	{
		if (weapon_classname.Length() > 0)
		{
			validateSettings();
			
			if (debug_mode)
				println("Assigning " + weapon_classname + " to slot " + slot + " at position " + slotPosition);			
		
			custom_weapons[weapon_classname] = @this;
			g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustomBase", weapon_classname );
			if (pev.spawnflags & FL_WEP_HIDE_SECONDARY_AMMO != 0)
			{
				g_ItemRegistry.RegisterWeapon( weapon_classname, hud_sprite_folder, primary_ammo_type, "" );
			}
			else
				g_ItemRegistry.RegisterWeapon( weapon_classname, hud_sprite_folder, primary_ammo_type, secondary_ammo_type );
			matchingAmmoTypes = primary_ammo_type.ToLowercase() == secondary_ammo_type.ToLowercase();
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
		PrecacheSound(primary_reload_snd.file);
		PrecacheSound(primary_empty_snd.file);
		PrecacheSound(secondary_reload_snd.file);
		PrecacheSound(secondary_empty_snd.file);
		PrecacheSound(reload_snd.file);
		PrecacheSound(reload_start_snd.file);
		PrecacheSound(reload_end_snd.file);
		PrecacheModel(wpn_v_model);
		PrecacheModel(wpn_w_model);
		PrecacheModel(wpn_p_model);
		PrecacheModel(hud_sprite);
		PrecacheModel(laser_sprite);
	}
};

class weapon_custom_sound : ScriptBaseEntity
{	
	WeaponSound next_snd;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{
		next_snd.file = pev.noise;
		Precache();
	}
	
	void loadExternalSoundSettings()
	{
		loadSoundSettings(next_snd);
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

class weapon_custom_effect : ScriptBaseEntity
{	
	string name;
	bool valid = false;
	
	float delay = 0;

	int explosion_style;
	float explode_radius;
	float explode_damage;
	float explode_offset;
	float explode_spr_scale;
	float explode_spr_fps;
	string explode_water_spr;
	string explode_spr;
	
	int damage_type;
	int damage_type2;
	int gib_type;
	
	string explode_smoke_spr;
	float explode_smoke_spr_scale;
	float explode_smoke_spr_fps;
	float explode_smoke_delay;
	
	float explode_beam_radius;
	int explode_beam_width;
	int explode_beam_life;
	int explode_beam_noise;
	Color explode_beam_color;
	int explode_beam_frame;
	int explode_beam_fps;
	int explode_beam_scroll;
	
	int explode_bubbles;
	Vector explode_bubble_mins;
	Vector explode_bubble_maxs;
	float explode_bubble_delay;
	float explode_bubble_speed;
	string explode_bubble_spr;
	
	Color explode_light_color;
	Color explode_light_color2;
	Vector explode_light_adv;
	Vector explode_light_adv2;
	
	int explode_gibs;
	string explode_gib_mdl;
	int explode_gib_mat;
	int explode_gib_speed;
	int explode_gib_rand;
	int explode_gib_effects;
	
	array<WeaponSound> sounds;
	int rico_decal;
	string rico_part_spr;
	int rico_part_count;
	int rico_part_scale;
	int rico_part_speed;
	
	int rico_trace_count;
	int rico_trace_color;
	int rico_trace_speed;
	int rico_trace_rand;
	
	string glow_spr;
	int glow_spr_scale;
	int glow_spr_life;
	int glow_spr_opacity;
	
	int spray_count;
	string spray_sprite;
	int spray_speed;
	int spray_rand;
	
	int burst_life;
	int burst_radius;
	int burst_color;
	
	int implode_count;
	int implode_radius;
	int implode_life;
	
	int rico_scale;
	
	string next_effect_str;
	
	weapon_custom_effect@ next_effect;
	bool next_effect_loaded = false;

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if (szKey == "explosion_style")   explosion_style = atoi(szValue);
		else if (szKey == "delay")       delay = atof(szValue);
		else if (szKey == "explode_radius")    explode_radius = atof(szValue);
		else if (szKey == "explode_dmg")       explode_damage = atof(szValue);
		else if (szKey == "explode_offset")    explode_offset = atof(szValue);
		else if (szKey == "explode_spr")       explode_spr = szValue;
		else if (szKey == "explode_water_spr") explode_water_spr = szValue;
		else if (szKey == "explode_spr_scale") explode_spr_scale = atof(szValue);
		else if (szKey == "explode_spr_fps")   explode_spr_fps = atof(szValue);
		else if (szKey == "explode_smoke_spr") explode_smoke_spr = szValue;
		else if (szKey == "explode_smoke_spr_scale") explode_smoke_spr_scale = atof(szValue);
		else if (szKey == "explode_smoke_spr_fps") explode_smoke_spr_fps = atof(szValue);
		else if (szKey == "explode_smoke_delay") explode_smoke_delay = atof(szValue);
		else if (szKey == "explode_light_color") explode_light_color = parseColor(szValue);
		else if (szKey == "explode_light_adv")   explode_light_adv = parseVector(szValue);
		else if (szKey == "explode_light_color2") explode_light_color2 = parseColor(szValue);
		else if (szKey == "explode_light_adv2")   explode_light_adv2 = parseVector(szValue);
		
		else if (szKey == "explode_beam_width")  explode_beam_width = atoi(szValue);
		else if (szKey == "explode_beam_life")  explode_beam_life = atoi(szValue);
		else if (szKey == "explode_beam_noise")  explode_beam_noise = atoi(szValue);
		else if (szKey == "explode_beam_frame")  explode_beam_frame = atoi(szValue);
		else if (szKey == "explode_beam_fps")  explode_beam_fps = atoi(szValue);
		else if (szKey == "explode_beam_scroll")  explode_beam_scroll = atoi(szValue);
		else if (szKey == "explode_beam_radius")  explode_beam_radius = atof(szValue);
		else if (szKey == "explode_beam_color")  explode_beam_color = parseColor(szValue);
		
		else if (szKey == "implode_count")  implode_count = atoi(szValue);
		else if (szKey == "implode_radius") implode_radius = atoi(szValue);
		else if (szKey == "implode_life")   implode_life = atoi(szValue);
		
		else if (szKey == "burst_life")   burst_life = atoi(szValue);
		else if (szKey == "burst_radius") burst_radius = atoi(szValue);
		else if (szKey == "burst_color")  burst_color = atoi(szValue);
		
		else if (szKey == "spray_count")  spray_count = atoi(szValue);
		else if (szKey == "spray_sprite") spray_sprite = szValue;
		else if (szKey == "spray_speed")  spray_speed = atoi(szValue);
		else if (szKey == "spray_rand")   spray_rand = atoi(szValue);
		
		else if (szKey == "explode_gibs")      explode_gibs = atoi(szValue);
		else if (szKey == "explode_gib_speed") explode_gib_speed = atoi(szValue);
		else if (szKey == "explode_gib_model") explode_gib_mdl = szValue;
		else if (szKey == "explode_gib_mat")   explode_gib_mat = atoi(szValue);
		else if (szKey == "explode_gib_rand")  explode_gib_rand = atoi(szValue);
		else if (szKey == "explode_gib_effects")explode_gib_effects = atoi(szValue);
		
		else if (szKey == "glow_spr")         glow_spr = szValue;
		else if (szKey == "glow_spr_scale")   glow_spr_scale = atoi(szValue);
		else if (szKey == "glow_spr_life")    glow_spr_life = atoi(szValue);
		else if (szKey == "glow_spr_opacity") glow_spr_opacity = atoi(szValue);
		
		else if (szKey == "damage_type")  damage_type = atoi(szValue);
		else if (szKey == "damage_type2")  damage_type2 = atoi(szValue);
		else if (szKey == "gib_type")  gib_type = atoi(szValue);
		
		else if (szKey == "sounds")        sounds = parseSounds(szValue);
		
		else if (szKey == "rico_decal")       rico_decal = atoi(szValue);
		else if (szKey == "rico_part_spr")    rico_part_spr = szValue;
		else if (szKey == "rico_part_count")  rico_part_count = atoi(szValue);
		else if (szKey == "rico_part_scale")  rico_part_scale = atoi(szValue);
		else if (szKey == "rico_part_speed")  rico_part_speed = atoi(szValue);
		else if (szKey == "rico_trace_count") rico_trace_count = atoi(szValue);
		else if (szKey == "rico_trace_speed") rico_trace_speed = atoi(szValue);
		else if (szKey == "rico_trace_rand")  rico_trace_rand = atoi(szValue);
		else if (szKey == "rico_trace_color") rico_trace_color = atoi(szValue);
		
		else if (szKey == "explode_bubbles")       explode_bubbles = atoi(szValue);
		else if (szKey == "explode_bubble_mins")   explode_bubble_mins = parseVector(szValue);
		else if (szKey == "explode_bubble_maxs")   explode_bubble_maxs = parseVector(szValue);
		else if (szKey == "explode_bubble_delay")  explode_bubble_delay = atof(szValue);
		else if (szKey == "explode_bubble_spr")    explode_bubble_spr = szValue;
		
		else if (szKey == "rico_scale")    rico_scale = atoi(szValue);
		
		else if (szKey == "next_effect") next_effect_str = szValue;
		
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	void Spawn()
	{
		Precache();
	}
	
	void loadExternalSoundSettings()
	{
		loadSoundSettings(sounds);
	}
	
	void loadExternalEffectSettings()
	{
		if (next_effect_loaded)
			return; // fix recursion crash
		next_effect_loaded = true;
		@next_effect = loadEffectSettings(next_effect, next_effect_str);
	}
	
	WeaponSound@ getRandomSound()
	{
		if (sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, sounds.length()-1);
		return sounds[randIdx];
	}
	
	void PrecacheSound(string sound)
	{
		if (sound.Length() > 0) {
			debugln("Precaching sound for " + pev.targetname + ": " + sound);
			g_SoundSystem.PrecacheSound( sound );
		}
	}
	
	int PrecacheModel(string model)
	{
		if (model.Length() > 0) {
			debugln("Precaching model for " + pev.targetname + ": " + model);
			return g_Game.PrecacheModel( model );
		}
		return -1;
	}
	
	int damageType()
	{
		return damage_type | damage_type2 | gib_type;
	}
	
	void Precache()
	{
		for (uint i = 0; i < sounds.length(); i++)
			PrecacheSound(sounds[i].file);
			
		PrecacheModel( explode_spr );
		PrecacheModel( explode_smoke_spr );
		PrecacheModel( explode_gib_mdl );
		PrecacheModel(rico_part_spr);	
		PrecacheModel(explode_water_spr);	
		PrecacheModel(explode_bubble_spr);	
		PrecacheModel(glow_spr);	
	}
};

class weapon_custom_user_effect : ScriptBaseEntity
{	
	bool valid = false;
	float delay = 0;	
	array<WeaponSound> sounds;

	float self_damage;
	int damage_type;
	int damage_type2;
	int gib_type;
	
	Vector add_angle;
	float add_angle_time;
	Vector punch_angle;
	Vector push_vel;
	
	string action_sprite;
	float action_sprite_height;
	float action_sprite_time;
	
	int fade_mode;
	Color fade_color;
	float fade_hold;
	float fade_time;
	
	int anim; // thirdperson anim
	float anim_speed; // thirdperson anim
	int anim_frame; // thirdperson anim
	
	int player_sprite_count;
	string player_sprite;	
	float player_sprite_freq;	
	float player_sprite_time;	
	
	float glow_time;
	int glow_amt;
	Vector glow_color;
	
	string next_effect_str;
	weapon_custom_effect@ next_effect;
	bool next_effect_loaded = false;

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if (szKey == "delay")       delay = atof(szValue);
		else if (szKey == "sounds")      sounds = parseSounds(szValue);
		
		else if (szKey == "self_damage")   self_damage = atof(szValue);
		else if (szKey == "damage_type")   damage_type = atoi(szValue);
		else if (szKey == "damage_type2")   damage_type2 = atoi(szValue);
		else if (szKey == "gib_type")   gib_type = atoi(szValue);
		
		else if (szKey == "add_angle")      add_angle = parseVector(szValue);
		else if (szKey == "add_angle_time") add_angle_time = atof(szValue);
		else if (szKey == "punch_angle")    punch_angle = parseVector(szValue);
		else if (szKey == "push_vel")       push_vel = parseVector(szValue);
		
		else if (szKey == "action_sprite")        action_sprite = szValue;
		else if (szKey == "action_sprite_height") action_sprite_height = atof(szValue);
		else if (szKey == "action_sprite_time")   action_sprite_time = atof(szValue);
		
		else if (szKey == "fade_mode")  fade_mode = atoi(szValue);
		else if (szKey == "fade_color") fade_color = parseColor(szValue);
		else if (szKey == "fade_hold")  fade_hold = atof(szValue);
		else if (szKey == "fade_time")  fade_time = atof(szValue);
		
		else if (szKey == "anim")       anim = atoi(szValue);
		else if (szKey == "anim_speed") anim_speed = atof(szValue);
		else if (szKey == "anim_frame") anim_frame = atoi(szValue);
		
		else if (szKey == "player_sprite_count") player_sprite_count = atoi(szValue);
		else if (szKey == "player_sprite")       player_sprite = szValue;
		else if (szKey == "player_sprite_freq")  player_sprite_freq = atof(szValue);
		else if (szKey == "player_sprite_time")  player_sprite_time = atof(szValue);
		
		else if (szKey == "glow_color") glow_color = parseVector(szValue);
		else if (szKey == "glow_amt")   glow_amt = atoi(szValue);
		else if (szKey == "glow_time")  glow_time = atof(szValue);
		
		else if (szKey == "next_effect") next_effect_str = szValue;
		
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	void Spawn()
	{
		Precache();
	}
	
	void loadExternalSoundSettings()
	{
		loadSoundSettings(sounds);
	}
	
	void loadExternalUserEffectSettings()
	{
		if (next_effect_loaded)
			return; // fix recursion crash
		next_effect_loaded = true;
		@next_effect = loadEffectSettings(next_effect, next_effect_str);
	}
	
	WeaponSound@ getRandomSound()
	{
		if (sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, sounds.length()-1);
		return sounds[randIdx];
	}
	
	void PrecacheSound(string sound)
	{
		if (sound.Length() > 0) {
			debugln("Precaching sound for " + pev.targetname + ": " + sound);
			g_SoundSystem.PrecacheSound( sound );
		}
	}
	
	int PrecacheModel(string model)
	{
		if (model.Length() > 0) {
			debugln("Precaching model for " + pev.targetname + ": " + model);
			return g_Game.PrecacheModel( model );
		}
		return -1;
	}
	
	int damageType()
	{
		return damage_type | damage_type2 | gib_type;
	}
	
	void Precache()
	{
		for (uint i = 0; i < sounds.length(); i++)
			PrecacheSound(sounds[i].file);
			
		PrecacheModel( action_sprite );	
		PrecacheModel( player_sprite );	
	}
};
