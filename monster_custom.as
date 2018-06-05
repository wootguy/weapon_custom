#include "MonsterCustomBase"
#include "weapon_custom"
#include "utils"

void MonsterCustomMapInit()
{	
	g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustom::monster_custom", "monster_custom" );
	g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustom::monster_custom_event", "monster_custom_event" );
	g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustom::monster_custom_damage", "monster_custom_damage" );
	g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustom::MonsterCustomBase", "monster_custom_generic" );
}

void MonsterCustomMapActivate()
{
	WeaponCustom::MonsterCustomMapActivate_internal();
}

namespace WeaponCustom {

void MonsterCustomMapActivate_internal()
{
	// Hook up monster_custom_event with weapon_custom_shoot
	for (uint i = 0; i < all_monster_events.length(); i++)
	{
		monster_custom_event@ evt = all_monster_events[i];
		if (evt.shoot_ent_name.Length() == 0)
			continue;
		
		bool found = false;
		array<string>@ keys = custom_weapon_shoots.getKeys();
		for (uint k = 0; k < keys.length(); k++)
		{
			weapon_custom_shoot@ shoot = cast<weapon_custom_shoot@>( custom_weapon_shoots[keys[k]] );
			if (evt.shoot_ent_name == shoot.pev.targetname)
			{
				@evt.shoot_settings = shoot;
				found = true;
			}
		}
		if (!found)
			println(logPrefix + " Couldn't find shoot entity " + evt.shoot_ent_name + " for " + evt.monster_classname + " event " + evt.event);
	}
	
	// Hook up event handlers
	for (uint i = 0; i < all_monster_events.length(); i++)
		all_monster_events[i].attachToMonster();
	
	// Hook up damage handlers
	for (uint i = 0; i < all_monster_dmgs.length(); i++)
		all_monster_dmgs[i].attachToMonster();
}

dictionary custom_monsters;
array<monster_custom_event@> all_monster_events;
array<monster_custom_damage@> all_monster_dmgs;

class monster_custom : ScriptBaseEntity
{
	string monster_classname;
	string default_model;
	string default_displayname;
	int default_class = 0;
	int bloodcolor = 1;
	float eye_height = 48;
	float fov = 180;
	float turn_speed = 90;
	Vector min_hull, max_hull;
	array<WeaponSound> idle_sounds;
	array<WeaponSound> alert_sounds;
	array<WeaponSound> pain_sounds;
	float idle_sound_freq;
	float alert_sound_freq;
	
	array<monster_custom_event@> events;
	array<monster_custom_damage@> damages;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// Handle custom keyvalues
		if (szKey == "monster_name") monster_classname = szValue;
		else if (szKey == "default_model") default_model = szValue;
		else if (szKey == "classify") default_class = atoi(szValue);
		else if (szKey == "bloodcolor") bloodcolor = atoi(szValue);
		else if (szKey == "display_name") default_displayname = szValue;
		else if (szKey == "eye_height") eye_height = atof(szValue);
		else if (szKey == "fov") fov = atof(szValue);
		else if (szKey == "turn_speed") turn_speed = atof(szValue);
		else if (szKey == "minhullsize") min_hull = parseVector(szValue);
		else if (szKey == "maxhullsize") max_hull = parseVector(szValue);
		else if (szKey == "idle_sounds") idle_sounds = parseSounds(szValue);
		else if (szKey == "alert_sounds") alert_sounds = parseSounds(szValue);
		else if (szKey == "pain_sounds") pain_sounds = parseSounds(szValue);
		else if (szKey == "idle_sound_freq") idle_sound_freq = atof(szValue);
		else if (szKey == "alert_sound_freq") alert_sound_freq = atof(szValue);
		else return BaseClass.KeyValue( szKey, szValue );
		return true;
	}
	
	void Spawn()
	{
		if (monster_classname.Length() > 0)
		{		
			custom_monsters[monster_classname] = @this;
			g_CustomEntityFuncs.RegisterCustomEntity( "WeaponCustom::MonsterCustomBase", monster_classname );
			Precache();
		}
		else
			println("monster_custom creation failed. No monster_class specified");
	}
	
	WeaponSound@ getRandomIdleSound()
	{
		if (idle_sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, idle_sounds.length()-1);
		return idle_sounds[randIdx];
	}
	
	WeaponSound@ getRandomAlertSound()
	{
		if (alert_sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, alert_sounds.length()-1);
		return alert_sounds[randIdx];
	}
	
	WeaponSound@ getRandomPainSound()
	{
		if (pain_sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, pain_sounds.length()-1);
		return pain_sounds[randIdx];
	}
	
	void PrecacheModel(string model)
	{
		if (model.Length() > 0) {
			debugln("Precaching model for " + monster_classname + ": " + model);
			g_Game.PrecacheModel( model );
		}
	}
	
	void PrecacheSound(string sound)
	{
		if (sound.Length() > 0) {
			debugln("Precaching sound for " + monster_classname + ": " + sound);
			g_SoundSystem.PrecacheSound( sound );
		}
	}
	
	void Precache()
	{
		for (uint i = 0; i < idle_sounds.length(); i++)
			PrecacheSound(idle_sounds[i].file);
		for (uint i = 0; i < alert_sounds.length(); i++)
			PrecacheSound(idle_sounds[i].file);
		for (uint i = 0; i < pain_sounds.length(); i++)
			PrecacheSound(idle_sounds[i].file);
		PrecacheModel(default_model);
	}
};


class monster_custom_event : ScriptBaseEntity
{
	string monster_classname;
	string shoot_ent_name;
	weapon_custom_shoot@ shoot_settings = null;
	array<WeaponSound> sounds;
	int event = 0;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// Handle custom keyvalues
		if (szKey == "monster_name") monster_classname = szValue;
		else if (szKey == "shoot_ent") shoot_ent_name = szValue;
		else if (szKey == "event_num") event = atoi(szValue);
		else if (szKey == "sounds")    sounds = parseSounds(szValue);	
		else return BaseClass.KeyValue( szKey, szValue );
		return true;
	}
	
	void Spawn()
	{
		Precache();
		all_monster_events.insertLast(@this);
	}
	
	void attachToMonster()
	{
		if (monster_classname.Length() > 0)
		{
			if (custom_monsters.exists(monster_classname))
			{
				monster_custom@ settings = cast<monster_custom>( @custom_monsters[monster_classname] );
				settings.events.insertLast(@this);
			}
			else
				println("MONSTER_CUSTOM ERROR: monster_custom_event references non-existant monster class '" + monster_classname + "'");
		}
		else
			println("MONSTER_CUSTOM ERROR: a monster_custom_event has no monster class specified");
	}
	
	WeaponSound@ getRandomSound()
	{
		if (sounds.length() == 0)
			return null;
		int randIdx = Math.RandomLong(0, sounds.length()-1);
		return sounds[randIdx];
	}
	
	void PrecacheModel(string model)
	{
		if (model.Length() > 0) {
			debugln("Precaching model for " + monster_classname + ": " + model);
			g_Game.PrecacheModel( model );
		}
	}
	
	void PrecacheSound(string sound)
	{
		if (sound.Length() > 0) {
			debugln("Precaching sound for " + monster_classname + " (event " + event + "): " + sound);
			g_SoundSystem.PrecacheSound( sound );
		}
	}
	
	void Precache()
	{
		for (uint i = 0; i < sounds.length(); i++)
			PrecacheSound(sounds[i].file);
	}
};


class monster_custom_damage : ScriptBaseEntity
{
	string monster_classname;
	int dmgType = 0;
	Vector knockback;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		// Handle custom keyvalues
		if (szKey == "monster_name")    monster_classname = szValue;
		else if (szKey == "damage_type")    dmgType = atoi(szValue);
		else if (szKey == "knockback")  knockback = parseVector(szValue);	
		else return BaseClass.KeyValue( szKey, szValue );
		return true;
	}
	
	void Spawn()
	{
		all_monster_dmgs.insertLast(@this);
	}
	
	void attachToMonster()
	{
		if (monster_classname.Length() > 0)
		{
			if (custom_monsters.exists(monster_classname))
			{
				monster_custom@ settings = cast<monster_custom>( @custom_monsters[monster_classname] );
				settings.damages.insertLast(@this);
			}
			else
				println("MONSTER_CUSTOM ERROR: monster_custom_damage references non-existant monster class '" + monster_classname + "'");
		}
		else
			println("MONSTER_CUSTOM ERROR: a monster_custom_damage has no monster class specified");
	}	
};

}