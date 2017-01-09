#include "MonsterCustomBase"
#include "utils"

void MonsterCustomMapInit()
{	
	g_CustomEntityFuncs.RegisterCustomEntity( "monster_custom", "monster_custom" );
	g_CustomEntityFuncs.RegisterCustomEntity( "MonsterCustomBase", "monster_custom_generic" );
}

void MonsterCustomMapActivate()
{

}

dictionary custom_monsters;

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
		else return BaseClass.KeyValue( szKey, szValue );
		return true;
	}
	
	void Spawn()
	{
		if (monster_classname.Length() > 0)
		{		
			custom_monsters[monster_classname] = @this;
			g_CustomEntityFuncs.RegisterCustomEntity( "MonsterCustomBase", monster_classname );
			Precache();
		}
		else
			println("monster_custom creation failed. No monster_class specified");
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
		PrecacheModel(default_model);
	}
};
