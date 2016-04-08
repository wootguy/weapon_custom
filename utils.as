class Color
{ 
	uint8 r, g, b, a;
	Color() { r = g = b = a = 0; }
	Color(uint8 r, uint8 g, uint8 b) { this.r = r; this.g = g; this.b = b; this.a = 255; }
	Color(uint8 r, uint8 g, uint8 b, uint8 a) { this.r = r; this.g = g; this.b = b; this.a = a; }
	Color (Vector v) { this.r = int(v.x); this.g = int(v.y); this.b = int(v.z); this.a = 255; }
	string ToString() { return "" + r + " " + g + " " + b + " " + a; }
}

Color RED    = Color(255,0,0);
Color GREEN  = Color(0,255,0);
Color BLUE   = Color(0,0,255);
Color YELLOW = Color(255,255,0);
Color ORANGE = Color(255,127,0);
Color PURPLE = Color(127,0,255);
Color PINK   = Color(255,0,127);
Color TEAL   = Color(0,255,255);
Color WHITE  = Color(255,255,255);
Color BLACK  = Color(0,0,0);
Color GRAY  = Color(127,127,127);

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

void debug(string text) { if (debug_mode) print(text); }
void debugln(string text) { if (debug_mode) println(text); }

string logPrefix = "WEAPON_CUSTOM ERROR: ";

// convert output from Vector.ToString() back into a Vector
Vector parseVector(string s) {
	array<string> values = s.Split(" ");
	Vector v(0,0,0);
	if (values.length() > 0) v.x = atof( values[0] );
	if (values.length() > 1) v.y = atof( values[1] );
	if (values.length() > 2) v.z = atof( values[2] );
	return v;
}

// convert output from Vector.ToString() back into a Vector
Color parseColor(string s) {
	array<string> values = s.Split(" ");
	Color c(0,0,0,0);
	if (values.length() > 0) c.r = atoi( values[0] );
	if (values.length() > 1) c.g = atoi( values[1] );
	if (values.length() > 2) c.b = atoi( values[2] );
	if (values.length() > 3) c.a = atoi( values[3] );
	return c;
}

Vector resizeVector( Vector v, float length )
{
	float d = length / sqrt( (v.x*v.x) + (v.y*v.y) + (v.z*v.z) );
	v.x *= d;
	v.y *= d;
	v.z *= d;
	return v;
}

array<float> rotationMatrix(Vector axis, float angle)
{
	axis = axis.Normalize();
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
 
	array<float> mat = {
		oc * axis.x * axis.x + c,          oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0,
		oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c,          oc * axis.y * axis.z - axis.x * s, 0.0,
		oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c,			 0.0,
		0.0,                               0.0,                               0.0,								 1.0
	};
	return mat;
}

// create rotation matrix from euler angles
array<float> eulerMatrix(Vector angles)
{
	angles.x = Math.DegreesToRadians(angles.x);
	angles.y = Math.DegreesToRadians(angles.y);
	angles.z = Math.DegreesToRadians(-angles.z);
	float ch = cos(angles.x);
    float sh = sin(angles.x);
    float ca = cos(angles.y);
    float sa = sin(angles.y);
    float cb = cos(angles.z);
    float sb = sin(angles.z);
 
	array<float> mat = {
		ch * ca, sh*sb - ch*sa*cb, ch*sa*sb + sh*cb,  0.0,
		sa,      ca*cb,            -ca*sb,            0.0,
		-sh*ca,  sh*sa*cb + ch*sb, -sh*sa*sb + ch*cb, 0.0,
		0.0,     0.0,              0.0,			      1.0
	};
	return mat;
}

// multiply a matrix with a vector (assumes w component of vector is 1.0f) 
Vector matMultVector(array<float> rotMat, Vector v)
{
	Vector outv;
	outv.x = rotMat[0]*v.x + rotMat[4]*v.y + rotMat[8]*v.z  + rotMat[12];
	outv.y = rotMat[1]*v.x + rotMat[5]*v.y + rotMat[9]*v.z  + rotMat[13];
	outv.z = rotMat[2]*v.x + rotMat[6]*v.y + rotMat[10]*v.z + rotMat[14];
	return outv;
}

// http://stackoverflow.com/questions/1148309/inverting-a-4x4-matrix
// TODO: Only 3x3 inversion is needed
array<float> invertMatrix(array<float> m)
{
	array<float> inv(16);

	inv[0] = m[5]  * m[10] * m[15] - 
		m[5]  * m[11] * m[14] - 
		m[9]  * m[6]  * m[15] + 
		m[9]  * m[7]  * m[14] +
		m[13] * m[6]  * m[11] - 
		m[13] * m[7]  * m[10];

	inv[4] = -m[4]  * m[10] * m[15] + 
		m[4]  * m[11] * m[14] + 
		m[8]  * m[6]  * m[15] - 
		m[8]  * m[7]  * m[14] - 
		m[12] * m[6]  * m[11] + 
		m[12] * m[7]  * m[10];

	inv[8] = m[4]  * m[9] * m[15] - 
		m[4]  * m[11] * m[13] - 
		m[8]  * m[5] * m[15] + 
		m[8]  * m[7] * m[13] + 
		m[12] * m[5] * m[11] - 
		m[12] * m[7] * m[9];

	inv[12] = -m[4]  * m[9] * m[14] + 
		m[4]  * m[10] * m[13] +
		m[8]  * m[5] * m[14] - 
		m[8]  * m[6] * m[13] - 
		m[12] * m[5] * m[10] + 
		m[12] * m[6] * m[9];

	inv[1] = -m[1]  * m[10] * m[15] + 
		m[1]  * m[11] * m[14] + 
		m[9]  * m[2] * m[15] - 
		m[9]  * m[3] * m[14] - 
		m[13] * m[2] * m[11] + 
		m[13] * m[3] * m[10];

	inv[5] = m[0]  * m[10] * m[15] - 
		m[0]  * m[11] * m[14] - 
		m[8]  * m[2] * m[15] + 
		m[8]  * m[3] * m[14] + 
		m[12] * m[2] * m[11] - 
		m[12] * m[3] * m[10];

	inv[9] = -m[0]  * m[9] * m[15] + 
		m[0]  * m[11] * m[13] + 
		m[8]  * m[1] * m[15] - 
		m[8]  * m[3] * m[13] - 
		m[12] * m[1] * m[11] + 
		m[12] * m[3] * m[9];

	inv[13] = m[0]  * m[9] * m[14] - 
		m[0]  * m[10] * m[13] - 
		m[8]  * m[1] * m[14] + 
		m[8]  * m[2] * m[13] + 
		m[12] * m[1] * m[10] - 
		m[12] * m[2] * m[9];

	inv[2] = m[1]  * m[6] * m[15] - 
		m[1]  * m[7] * m[14] - 
		m[5]  * m[2] * m[15] + 
		m[5]  * m[3] * m[14] + 
		m[13] * m[2] * m[7] - 
		m[13] * m[3] * m[6];

	inv[6] = -m[0]  * m[6] * m[15] + 
		m[0]  * m[7] * m[14] + 
		m[4]  * m[2] * m[15] - 
		m[4]  * m[3] * m[14] - 
		m[12] * m[2] * m[7] + 
		m[12] * m[3] * m[6];

	inv[10] = m[0]  * m[5] * m[15] - 
		m[0]  * m[7] * m[13] - 
		m[4]  * m[1] * m[15] + 
		m[4]  * m[3] * m[13] + 
		m[12] * m[1] * m[7] - 
		m[12] * m[3] * m[5];

	inv[14] = -m[0]  * m[5] * m[14] + 
		m[0]  * m[6] * m[13] + 
		m[4]  * m[1] * m[14] - 
		m[4]  * m[2] * m[13] - 
		m[12] * m[1] * m[6] + 
		m[12] * m[2] * m[5];

	inv[3] = -m[1] * m[6] * m[11] + 
		m[1] * m[7] * m[10] + 
		m[5] * m[2] * m[11] - 
		m[5] * m[3] * m[10] - 
		m[9] * m[2] * m[7] + 
		m[9] * m[3] * m[6];

	inv[7] = m[0] * m[6] * m[11] - 
		m[0] * m[7] * m[10] - 
		m[4] * m[2] * m[11] + 
		m[4] * m[3] * m[10] + 
		m[8] * m[2] * m[7] - 
		m[8] * m[3] * m[6];

	inv[11] = -m[0] * m[5] * m[11] + 
		m[0] * m[7] * m[9] + 
		m[4] * m[1] * m[11] - 
		m[4] * m[3] * m[9] - 
		m[8] * m[1] * m[7] + 
		m[8] * m[3] * m[5];

	inv[15] = m[0] * m[5] * m[10] - 
		m[0] * m[6] * m[9] - 
		m[4] * m[1] * m[10] + 
		m[4] * m[2] * m[9] + 
		m[8] * m[1] * m[6] - 
		m[8] * m[2] * m[5];

	float det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];

	if (det == 0)
	{
		println("Matrix inversion failed (determinant is zero)");
		return m;
	}

	det = 1.0 / det;
	
	for (int i = 0; i < 16; i++)
		m[i] = inv[i] * det;

	return m;
}

// Randomize the direction of a vector by some amount
// Max degrees = 360, which makes a full sphere
Vector spreadDir(Vector dir, float degrees, int spreadFunc=SPREAD_UNIFORM)
{
	float spread = Math.DegreesToRadians(degrees) * 0.5f;
	float x, y;
	Vector vecAiming = dir;
	
	if (spreadFunc == SPREAD_GAUSSIAN) 
	{
		g_Utility.GetCircularGaussianSpread( x, y );
		x *= Math.RandomFloat(-spread, spread);
		y *= Math.RandomFloat(-spread, spread);
	} 
	else if (spreadFunc == SPREAD_UNIFORM) 
	{
		float c = Math.RandomFloat(0, Math.PI*2); // random point on circle
		float r = Math.RandomFloat(-1, 1); // random radius
		x = cos(c) * r * spread;
		y = sin(c) * r * spread;
	}
	
	// get "up" vector relative to aim direction
	Vector pitAxis = CrossProduct(dir, Vector(0, 0, 1)).Normalize(); // get left vector of aim dir
	Vector yawAxis = CrossProduct(dir, pitAxis).Normalize(); // get up vector relative to aim dir
	
	// Apply rotation around arbitrary "up" axis
	array<float> yawRotMat = rotationMatrix(yawAxis, x);
	vecAiming = matMultVector(yawRotMat, vecAiming).Normalize();
	
	// Apply rotation around "left/right" axis
	array<float> pitRotMat = rotationMatrix(pitAxis, y);
	vecAiming = matMultVector(pitRotMat, vecAiming).Normalize();
			
	return vecAiming;
}

int g_ambientId = 0;
void ambientSound(Vector origin, WeaponSound@ soundFile, int flags)
{
	// play global sound
	string ambientName = "weapon_custom__" + g_ambientId;
	dictionary keyvalues;
	keyvalues["origin"] = origin.ToString();
	keyvalues["targetname"] = ambientName;
	keyvalues["message"] = soundFile.file;
	keyvalues["pitch"] = string(soundFile.getPitch());
	keyvalues["spawnflags"] = "" + flags;
	keyvalues["playmode"] = "1";
	keyvalues["health"] = string(soundFile.getVolume()*10);

	CBaseEntity@ ambient = g_EntityFuncs.CreateEntity( "ambient_generic", keyvalues, true );
	g_EntityFuncs.FireTargets(ambientName, null, null, USE_ON);
	if (ambient !is null)
		g_EntityFuncs.Remove(ambient);
		
	g_ambientId++;
}

class DecalTarget
{
	Vector pos;
	TraceResult tr;
	string texture;
	CBaseEntity@ ent; // for when the target is a brush entity, not the world (0 = world)
}

class BeamImpact
{
	Vector pos;
	CBaseEntity@ ent;
}

// Traces out in every direction in hopes of finding a surface
DecalTarget getProjectileDecalTarget(CBaseEntity@ ent, float searchDist)
{		
	DecalTarget decalTarget = DecalTarget();
	decalTarget.pos = ent.pev.origin;
	
	TraceResult tr;
	Vector src = ent.pev.origin;
	
	float bboxSize = ent.pev.maxs.x - ent.pev.mins.x;
	if (bboxSize < 0) bboxSize = -bboxSize; // there's no abs() util function??
	
	Vector[] dirs = {
		// Box sides
		Vector(1, 0, 0),
		Vector(-1, 0, 0),
		Vector(0, 1, 0),
		Vector(0, -1, 0),
		Vector(0, 0, 1),
		Vector(0, 0, -1),
		// Box corners
		Vector( -0.577350, -0.577350, -0.577350),
		Vector(0.577350, -0.577350, -0.577350),
		Vector(-0.577350, 0.577350, -0.577350),
		Vector(-0.577350, -0.577350, 0.577350),
		Vector(0.577350, -0.577350, 0.577350),
		Vector(0.577350, 0.577350, -0.577350),
		Vector(0.577350, 0.577350, 0.577350),
		Vector(-0.577350, 0.577350, 0.577350)
	};	
	
	for (uint i = 0; i < dirs.length(); i++)
	{
		Vector end = src + dirs[i]*(bboxSize+searchDist);
		g_Utility.TraceLine( src, end, ignore_monsters, ent.edict(), tr );
		if (tr.flFraction < 1.0 and tr.pHit !is null)
		{
			decalTarget.pos = tr.vecEndPos;
			decalTarget.tr = tr;
			@decalTarget.ent = g_EntityFuncs.Instance( tr.pHit );
			
			// get the texture too, we might need that for something
			decalTarget.texture = g_Utility.TraceTexture( tr.pHit, src, end );
			
			return decalTarget;
		}
	}

	return decalTarget;
}

// rotates a point around 0,0,0 using YXZ euler rotation order
Vector rotatePoint(Vector pos, Vector angles)
{
	Vector yawAxis = Vector(0,0,1);
	Vector pitAxis = Vector(0,1,0);
	Vector rollAxis = Vector(1,0,0);
	
	array<float> yawRotMat = rotationMatrix(yawAxis, Math.DegreesToRadians(angles.y));
	pitAxis = matMultVector(yawRotMat, pitAxis);
	rollAxis = matMultVector(yawRotMat, rollAxis);
	
	array<float> pitRotMat = rotationMatrix(pitAxis, Math.DegreesToRadians(angles.x));
	rollAxis = matMultVector(pitRotMat, rollAxis);
	
	array<float> rollRotMat = rotationMatrix(rollAxis, Math.DegreesToRadians(angles.z));
	
	pos = matMultVector(yawRotMat, pos);
	pos = matMultVector(pitRotMat, pos);
	pos = matMultVector(rollRotMat, pos);
	
	return pos;
}

// Given a point that has been rotated around 0,0,0 by "angles", figure out
// where the point would be if we were to unapply all of those rotations.
// This is probably a super naive way of doing it (me no is good at math).
Vector unwindPoint(Vector pos, Vector angles)
{
	Vector yawAxis = Vector(0,0,1);
	Vector pitAxis = Vector(0,1,0);
	Vector rollAxis = Vector(1,0,0);
	angles.x = Math.DegreesToRadians(angles.x);
	angles.y = Math.DegreesToRadians(angles.y);
	angles.z = Math.DegreesToRadians(angles.z);
	
	// get rotation axes from angles
	array<float> yawRotMat = rotationMatrix(yawAxis, angles.y);
	pitAxis = matMultVector(yawRotMat, pitAxis);
	rollAxis = matMultVector(yawRotMat, rollAxis);
	array<float> pitRotMat = rotationMatrix(pitAxis, angles.x);
	rollAxis = matMultVector(pitRotMat, rollAxis);
	
	// create matrices that undo the rotations
	yawRotMat = rotationMatrix(yawAxis, -angles.y);
	pitRotMat = rotationMatrix(pitAxis, -angles.x);
	array<float> rollRotMat = rotationMatrix(rollAxis, -angles.z);
	
	// apply opposite rotations in reverse order
	pos = matMultVector(rollRotMat, pos);
	pos = matMultVector(pitRotMat, pos);
	pos = matMultVector(yawRotMat, pos);
	
	return pos;
}

class WeaponCustomProjectile : ScriptBaseEntity
{
	float thinkDelay = 0.05;
	weapon_custom_shoot@ shoot_opts;
	ProjectileOptions@ options;
	EHandle spriteAttachment; // we'll need to kill this before we die (lol murder)
	bool attached;
	EHandle target; // entity attached to
	Vector attachStartOri; // Our initial position when attaching to the entity
	Vector targetStartOri; // initial position of the entity we attached to
	Vector attachStartDir; // our initial direction when attaching to the entity
	int attachTime = 0;
	
	bool move_snd_playing = false;
	string pickup_classname;
	bool weaponPickup = false;
	float pickupRadius = 64.0f;
	
	void Spawn()
	{
		@options = shoot_opts.projectile;
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
		
		g_EntityFuncs.SetModel( self, pev.model );
		
		pev.mins = Vector(-options.size, -options.size, -options.size);
		pev.maxs = Vector(options.size, options.size, options.size);
		pev.angles = pev.angles + options.angles;
		pev.avelocity = options.avel;
		//pev.friction = 1.0f - options.elasticity;
		
		SetThink( ThinkFunction( MoveThink ) );
		self.pev.nextthink = g_Engine.time + thinkDelay;
		
		move_snd_playing = options.move_snd.play(self, CHAN_BODY);
	}
	
	void MoveThink()
	{
		float nextThink = g_Engine.time + thinkDelay;
		
		if (attached and target)
		{
			CBaseEntity@ tar = target;
			
			// rotate position around target
			Vector newOri = attachStartOri + (tar.pev.origin - targetStartOri);
			newOri = rotatePoint(newOri - tar.pev.origin, -tar.pev.angles) + tar.pev.origin;
			
			// rotate orientation around target
			Vector newDir = rotatePoint(attachStartDir, -tar.pev.angles);
			g_EngineFuncs.VecToAngles(newDir, self.pev.angles);
			
			pev.origin = newOri;
			
			// prevent sudden jerking due to movement lagging behind the Touch() event
			attachTime++;
			if (attachTime > 2) {
				pev.velocity = Vector(0,0,0);
				pev.movetype = MOVETYPE_FLY;
			}
			
			if (shoot_opts.hook_type != HOOK_DISABLED)
			{
				CBaseEntity@ owner = g_EntityFuncs.Instance( self.pev.owner );
				
				Vector dir = (pev.origin - owner.pev.origin).Normalize();
				Vector repelDir = dir;
				repelDir.z = 0;
				
				//if (DotProduct(dir, owner.pev.velocity.Normalize()) < 0)
				//	owner.pev.velocity = -owner.pev.velocity;
				
				if (shoot_opts.hook_pull_mode == HOOK_MODE_PULL)
					owner.pev.velocity = owner.pev.velocity + dir*shoot_opts.hook_force;
				else
					owner.pev.velocity = owner.pev.velocity + repelDir*shoot_opts.hook_force;
					
				if (owner.pev.velocity.Length() > shoot_opts.hook_max_speed)
					owner.pev.velocity = resizeVector(owner.pev.velocity, shoot_opts.hook_max_speed);
				
				if (shoot_opts.hook_pull_mode == HOOK_MODE_PULL and owner.pev.flags & FL_ONGROUND != 0 and dir.z > 0)
				{	
					// The player is going to be stubborn and glue itself to the ground.
					// Make sure that forcing the player upward won't jam it into something solid
					TraceResult tr;
					Vector vecSrc = owner.pev.origin;
					Vector vecEnd = owner.pev.origin + Vector(0,0,2);
					g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, human_hull, owner.edict(), tr );
					if ( tr.flFraction >= 1.0 )
						owner.pev.origin.z += 2; // cool, we're all clear
				}
				
				nextThink = g_Engine.time; // don't let gravity overpower the pull force
			}
		}
		else
		{
			if (shoot_opts.pev.spawnflags & FL_SHOOT_PROJ_NO_ORIENT == 0)
				g_EngineFuncs.VecToAngles(self.pev.velocity, self.pev.angles);
		}
		
		if (move_snd_playing and pev.velocity.Length() == 0)
			options.move_snd.stop(self, CHAN_BODY);
		
		if (weaponPickup)
		{
			if (pev.velocity.Length() < 128)
			{
				if ( !attached and pev.flags & FL_ONGROUND != 0 )
				{
					pev.angles.x = 0;
					pev.angles.z = 0;
				}
				
				CBaseEntity@ ent = null;
				do {
					@ent = g_EntityFuncs.FindEntityInSphere(ent, pev.origin, pickupRadius, "player", "classname"); 
					if (ent !is null)
					{
						CBasePlayer@ plr = cast<CBasePlayer@>(ent);
						plr.SetItemPickupTimes(0);
						if (plr.HasNamedPlayerItem(pickup_classname) !is null)
						{
							// play the pickup sound even if they already have the weapon
							g_SoundSystem.EmitSoundDyn( plr.edict(), CHAN_ITEM, "items/gunpickup2.wav", 1.0, 
														ATTN_NORM, 0, 100 );
						}
						else
							plr.GiveNamedItem(pickup_classname, 0, 0);
						uninstall_steam_and_kill_yourself();
					}
				} while (ent !is null);
			}
		}
		
		self.pev.nextthink = nextThink;
	}
	
	void uninstall_steam_and_kill_yourself()
	{
		if (move_snd_playing)
			options.move_snd.stop(self, CHAN_BODY);
		g_EntityFuncs.Remove(self);
		if (spriteAttachment)
			g_EntityFuncs.Remove(spriteAttachment);
	}
	
	void DamageTarget(CBaseEntity@ ent)
	{	
		if (ent is null or ent.entindex() == 0)
			return;
		CBaseEntity@ owner = g_EntityFuncs.Instance( self.pev.owner );
			
		// damage done before hitgroup multipliers
		float baseDamage = options.impact_dmg;
		
		if (baseDamage == 0)
			return;
		
		baseDamage = applyDamageModifiers(baseDamage, ent, owner, shoot_opts);
		
		TraceResult tr;
		Vector vecSrc = pev.origin;
		Vector vecAiming = pev.velocity.Normalize();
		Vector vecEnd = vecSrc + vecAiming * pev.velocity.Length()*2;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, self.edict(), tr );
		CBaseEntity@ pHit = tr.pHit !is null ? g_EntityFuncs.Instance( tr.pHit ) : null;
		//te_beampoints(vecSrc, tr.vecEndPos);
		if ( tr.flFraction >= 1.0 or pHit.entindex() != ent.entindex())
		{
			// This does a trace in the form of a box so there is a much higher chance of hitting something
			// From crowbar.cpp in the hlsdk:
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, self.edict(), tr );
			if ( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				@pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null or pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, self.edict() );
				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
				vecAiming = (vecEnd - vecSrc).Normalize();
			}
		}
		
		g_WeaponFuncs.ClearMultiDamage(); // fixes TraceAttack() crash for some reason
		ent.TraceAttack(owner.pev, baseDamage, vecAiming, tr, DMG_CLUB);
		g_WeaponFuncs.ApplyMultiDamage(ent.pev, owner.pev);
		
		WeaponSound@ impact_snd;
		if ((ent.IsMonster() or ent.IsPlayer()) and !ent.IsMachine())
			@impact_snd = shoot_opts.getRandomMeleeFleshSound();
		else
			@impact_snd = shoot_opts.getRandomMeleeHitSound();
			
		if (impact_snd !is null)
			impact_snd.play(self, CHAN_WEAPON);
	}
	
	void ConvertToWeapon()
	{
		if (options.type == PROJECTILE_WEAPON)
		{
			pev.angles.z = 0;
			weaponPickup = true;
			if (move_snd_playing)
				options.move_snd.stop(self, CHAN_BODY);
		}
	}
	
	bool isValidHookSurface(CBaseEntity@ pOther)
	{
		if (shoot_opts.hook_texture_filter.Length() > 0)
		{
			if (!pOther.IsBSPModel())
				return false;
			
			DecalTarget dt = getProjectileDecalTarget(self, 1);
			if (dt.texture.Find(shoot_opts.hook_texture_filter) != 0)
				return false;
		}
		return true;
	}
	
	void Touch( CBaseEntity@ pOther )
	{
		if (attached)
			return;
		int event = PROJ_ACT_BOUNCE;
		weapon_custom_effect@ effect = shoot_opts.effect1;
		if (pOther.IsBSPModel())
			event = options.world_event;
		else
		{
			effect = shoot_opts.effect2;
			event = options.monster_event;
		}
		
		pev.velocity = pev.velocity*options.elasticity;
		
		if (weaponPickup)
		{
			// no more special effects after the first impact (pretend we're a weaponbox)
			custom_effect_sound(effect, self);
			pev.avelocity.x *= -0.9;
			return; 
		}
		
		DamageTarget(pOther);
		knockBack(pOther, pev.velocity.Normalize() * shoot_opts.knockback);
		custom_effect(self.pev.origin, effect, self);
		ConvertToWeapon();
		
		switch(event)
		{
			case PROJ_ACT_IMPACT:
				uninstall_steam_and_kill_yourself();
				return;
			case PROJ_ACT_ATTACH:
				if (shoot_opts.hook_type != HOOK_DISABLED and !isValidHookSurface(pOther))
				{
					uninstall_steam_and_kill_yourself();
					return;
				}
				
				target = pOther;
				attachStartOri = unwindPoint(pev.origin - pOther.pev.origin, -pOther.pev.angles) + pOther.pev.origin;
				attachStartDir = unwindPoint(pev.velocity.Normalize(), -pOther.pev.angles);
				targetStartOri = pOther.pev.origin;
				self.pev.solid = SOLID_NOT;
				pev.velocity = Vector(0,0,0);
				pev.avelocity = Vector(0,0,0);
				attached = true;
				return;
		}
	}
}

int getRandomPitch(int variance)
{
	return Math.RandomLong(100-variance, 100+variance);
}

void custom_effect_sound(weapon_custom_effect@ effect, CBaseEntity@ owner)
{
	WeaponSound@ rico_snd = effect.getRandomSound();
	if (rico_snd !is null)
	{
		rico_snd.play(owner, CHAN_STATIC);
	}
}

void custom_effect(Vector pos, weapon_custom_effect@ effect, CBaseEntity@ creator)
{
	if (!effect.valid)
		return;
		
	if (effect.pev.spawnflags & FL_EFFECT_RICOCHET != 0)
	{
		DecalTarget dt = getProjectileDecalTarget(creator, 0);
		custom_ricochet(pos, dt.tr.vecPlaneNormal, effect, creator, dt.ent);
	}
	if (effect.pev.spawnflags & FL_EFFECT_EXPLOSION != 0)
	{
		DecalTarget dt = getProjectileDecalTarget(creator, 32);
		custom_explosion(creator.pev.origin, creator.pev.velocity, effect, dt.pos, dt.ent);
	}
	if (effect.pev.spawnflags & FL_EFFECT_SPARKS != 0)
	{
		te_sparks(pos);
	}
	
	// TODO: CHECK IF EXPLOSION SOUNDS WORK
	//ambientSound(pos, effect.explode_snd, 40);
	custom_effect_sound(effect, creator);
}

void custom_ricochet(Vector pos, Vector dir, weapon_custom_effect@ effect, CBaseEntity@ owner, CBaseEntity@ decalEnt)
{
	if (!effect.valid)
		return;
		
	if (effect.rico_part_count > 0)
	{
		te_spritetrail(pos, pos + dir, effect.rico_part_spr, 
					   effect.rico_part_count, 0, effect.rico_part_scale, 
					   effect.rico_part_speed/2, effect.rico_part_speed);
	}
	if (effect.rico_trace_count > 0)
	{
		te_streaksplash(pos, dir, effect.rico_trace_color,
						effect.rico_trace_count, effect.rico_trace_speed/2, effect.rico_trace_speed);
	}
	if (effect.rico_decal != DECAL_NONE)
	{
		te_decal(pos, decalEnt, getBulletDecalOverride(decalEnt, getDecal(effect.rico_decal)));
	}
	
}

void custom_explosion(Vector pos, Vector vel, weapon_custom_effect@ effect, Vector decalPos, CBaseEntity@ decalEnt)
{
	if (!effect.valid)
		return;
		
	int scale = Math.max(1, Math.min(255, int(effect.explode_mag/10)));
	int dscale = Math.max(8, Math.min(255, int(effect.explode_mag/20)));
	int smokeScale = Math.min(255, scale+10);
	float smokeDelay = 0.2;
	int life = 8;
	switch(effect.explosion_style)
	{
		case EXPLODE_SPRITE:
		{
			int flags = 2 | 4;
			te_explosion(pos, effect.explode_spr, scale, 30, flags);
			smokeDelay = 0.4;
			break;
		}
		case EXPLODE_DISK:
			te_beamdisk(pos, effect.explode_mag, effect.explode_spr, 0, 15, life, 255, 0, WHITE, 0);
			break;
		case EXPLODE_CYLINDER:
			te_beamcylinder(pos, effect.explode_mag, effect.explode_spr, 0, 15, life, scale, 0, WHITE, 0);
			break;
		case EXPLODE_TORUS:
			te_beamtorus(pos, effect.explode_mag, effect.explode_spr, 0, 15, life, scale, 0, WHITE, 0);
			break;
	}
	
	if (effect.explode_smoke_spr.Length() > 0)
		g_Scheduler.SetTimeout("delayed_smoke", smokeDelay, pos, effect.explode_smoke_spr, smokeScale);
	if (effect.explode_light.a > 0)
		te_dlight(pos, dscale, effect.explode_light, 255, 50);
		
	if (effect.explode_gibs > 0)
	{
		te_breakmodel(pos, Vector(2,2,2), vel, smokeScale, 
					  effect.explode_gib_mdl, effect.explode_gibs, 5, effect.explode_gib_mat | 16);
	}

	if (effect.explode_decal != DECAL_NONE)
	{
		// search is distance > 0 because it's unlikely that a projectile will be 
		// touching a surface when its life expires.
		te_decal(decalPos, decalEnt, getDecal(effect.explode_decal));
	}
}

void delayed_smoke(Vector origin, string sprite, int scale)
{
	te_smoke(origin, sprite, scale);
}

void killProjectile(EHandle projectile, EHandle sprite, weapon_custom_shoot@ shoot_opts)
{
	ProjectileOptions@ options = shoot_opts.projectile;
	if (projectile)
	{
		CBaseEntity@ ent = projectile;
		custom_effect(ent.pev.origin, shoot_opts.effect3, ent);
		g_EntityFuncs.Remove(ent);
	}
	if (sprite)
	{
		CBaseEntity@ ent = sprite;
		g_EntityFuncs.Remove(ent);
	}
}

void removeWeapon(CBasePlayerWeapon@ wep)
{
	wep.Killed(wep.pev, 0);
}

void playSoundDelay(SoundArgs@ args)
{
	if (!args.ent)
		return;

	CBaseEntity@ ent = args.ent;
	g_SoundSystem.EmitSoundDyn( ent.edict(), args.channel, args.file, args.volume, args.attn, args.flags, args.pitch );
}

class SoundArgs
{
	EHandle ent;
	SOUND_CHANNEL channel;
	string file;
	float volume;
	float attn;
	int flags;
	int pitch;
}

class WeaponSound
{
	string file;
	weapon_custom_sound@ options;

	bool play(CBaseEntity@ ent, SOUND_CHANNEL channel=CHAN_STATIC, float volMult=1.0f, int pitchOverride=-1, 
			  int additionalFlags=0)
	{
		if (file.Length() == 0)
			return false;
		float volume = 1.0f;
		float attn = ATTN_NORM;
		int flags = additionalFlags;
		int pitch = getPitch();
		float delay = 0.0f;
		if (options !is null)
		{
			delay = options.pev.friction;
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
		if (pitchOverride != -1)
			pitch = pitchOverride;
		
		if (delay > 0)
		{
			SoundArgs args;
			args.ent = ent;
			args.channel = channel;
			args.file = file;
			args.volume = volume*volMult;
			args.attn = attn;
			args.flags = flags;
			args.pitch = pitch;
			
			g_Scheduler.SetTimeout("playSoundDelay", delay, @args);
		}
		else
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

enum impact_decal_type
{
	DECAL_NONE = -2,
	DECAL_BIGBLOOD = 0,
	DECAL_BIGSHOT,
	DECAL_BLOOD,
	DECAL_BLOODHAND,
	DECAL_BULLETPROOF,
	DECAL_GLASSBREAK,
	DECAL_LETTERS,
	DECAL_SMALLCRACK,
	DECAL_LARGECRACK,
	DECAL_LARGEDENT,
	DECAL_SMALLDENT,
	DECAL_DING,
	DECAL_RUST,
	DECAL_FEET,
	DECAL_GARGSTOMP,
	DECAL_GUASS,
	DECAL_GRAFITTI,
	DECAL_HANDICAP,
	DECAL_MOMMABLOB,
	DECAL_SMALLSCORTCH,
	DECAL_MEDIUMSCORTCH,
	DECAL_TINYSCORTCH,
	DECAL_OIL,
	DECAL_LARGESCORTCH,
	DECAL_SMALLSHOT,
	DECAL_NUMBERS,
	DECAL_TINYSCORTCH2,
	DECAL_SMALLSCORTCH2,
	DECAL_SPIT,
	DECAL_BIGABLOOD,
	DECAL_TARGET,
	DECAL_TIRE,
	DECAL_ABLOOD,
	DECAL_TYPES,
}

array< array<string> > g_decals = {
	{"{bigblood1", "{bigblood2"},
	{"{bigshot1", "{bigshot2", "{bigshot3", "{bigshot4", "{bigshot5"},
	{"{blood1", "{blood2", "{blood3", "{blood4", "{blood5", "{blood6", "{blood7", "{blood8"},
	{"{bloodhand1", "{bloodhand2", "{bloodhand3", "{bloodhand4", "{bloodhand5", "{bloodhand6"},
	{"{bproof1"},
	{"{break1", "{break2", "{break3"},
	{"{capsa", "{capsb", "{capsc", "{capsd", "{capse", "{capsf", "{capsg", "{capsh", "{capsi", "{capsj",
		"{capsk", "{capsl", "{capsm", "{capsn", "{capso", "{capsp", "{capsq", "{capsr", "{capss", "{capst",
		"{capsu", "{capsv", "{capsw", "{capsx", "{capsy", "{capsz"},
	{"{crack1", "{crack2"},
	{"{crack3", "{crack4"},
	{"{dent1", "{dent2"},
	{"{dent3", "{dent4", "{dent5", "{dent6"},
	{"{ding3", "{ding4", "{ding5", "{ding6", "{ding7", "{ding8", "{ding9"},
	{"{ding10", "{ding11"},
	{"{foot_l", "{foot_r"},
	{"{gargstomp"},
	{"{gaussshot1"},
	{"{graf001", "{graf002", "{graf003", "{graf004", "{graf005"},
	{"{handi"},
	{"{mommablob"},
	{"{ofscorch1", "{ofscorch2", "{ofscorch3"},
	{"{ofscorch4", "{ofscorch5", "{ofscorch6"},
	{"{ofsmscorch1", "{ofsmscorch2", "{ofsmscorch3"},
	{"{oil1", "{oil2"},
	{"{scorch1", "{scorch2", "{scorch3"},
	{"{shot1", "{shot2", "{shot3", "{shot4", "{shot5"},
	{"{small#s0", "{small#s1", "{small#s2", "{small#s3", "{small#s4",
		"{small#s5", "{small#s6", "{small#s7", "{small#s8", "{small#s9"},
	{"{smscorch1", "{smscorch2"},
	{"{smscorch3"},
	{"{spit1", "{spit2"},
	{"{spr_splt1", "{spr_splt2", "{spr_splt3"},
	{"{target", "{target2"},
	{"{tire1", "{tire2"},
	{"{yblood1", "{yblood2", "{yblood3", "{yblood4", "{yblood5", "{yblood6"},
};

string getDecal(int decalType)
{
	if (decalType < 0 or decalType >= int(g_decals.length()))
		decalType = DECAL_SMALLSHOT;
		
	array<string> decals = g_decals[decalType];
	return decals[ Math.RandomLong(0, decals.length()-1) ];
}

bool isBreakableEntity(CBaseEntity@ ent)
{
	if (ent.pev.classname == "func_breakable")
		return true;
	if (ent.pev.classname == "func_door" or ent.pev.classname == "func_door_rotating")
		return true; // TODO: Figure out how to check "breakable" keyvalue
	return false;
}

int getMonsterClass(CBaseMonster@ mon)
{
	if (mon.Classify() == CLASS_PLAYER_ALLY)
	{
		// PLAYER_ALLY masks the actual monster class, so remove that for a sec
		mon.SetPlayerAlly(false);
		int c = mon.Classify();
		mon.SetPlayerAlly(true);
		return c;
	}
	return mon.Classify();
}

bool isHuman(CBaseEntity@ ent)
{
	if (ent.IsMonster()) {
		CBaseMonster@ mon = cast<CBaseMonster@>(ent);
		int c = getMonsterClass(mon);
		switch(c)
		{
			case CLASS_PLAYER:
			case CLASS_HUMAN_PASSIVE:
			case CLASS_HUMAN_MILITARY:
				return true;
		}
	}
	return false;
}

bool isAlien(CBaseEntity@ ent)
{
	if (ent.IsMonster()) {
		CBaseMonster@ mon = cast<CBaseMonster@>(ent);
		int c = getMonsterClass(mon);		

		switch(c)
		{
			case CLASS_ALIEN_MILITARY:
			case CLASS_ALIEN_PASSIVE:
			case CLASS_ALIEN_MONSTER:
			case CLASS_ALIEN_PREY:
			case CLASS_ALIEN_PREDATOR:
			case CLASS_PLAYER_BIOWEAPON:
			case CLASS_ALIEN_BIOWEAPON:
			case CLASS_XRACE_PITDRONE:
			case CLASS_XRACE_SHOCK:
			case CLASS_BARNACLE:
				return true;
		}
	}
	return false;
}

bool isRepairable(CBaseEntity@ breakable)
{
	if (breakable.pev.classname == "func_door")
		return true; // no way to check breakable key that I know of
	if (breakable.pev.classname == "func_breakable")
		return breakable.pev.spawnflags & 8 != 0;
	return false;
}

bool shouldHealTarget(CBaseEntity@ target, CBaseEntity@ plr, weapon_custom_shoot@ shoot_opts)
{
	if (shoot_opts.heal_mode == HEAL_OFF)
		return false;
	
	int mode = shoot_opts.heal_mode;
	
	int heals = shoot_opts.heal_targets;
	bool healAll = heals == HEALT_EVERYTHING;
	bool healMachines = heals == HEALT_MACHINES or heals == HEALT_MACHINES_AND_BREAKABLES;
	bool healHumans = heals == HEALT_HUMANS or heals == HEALT_HUMANS_AND_ALIENS;
	bool healAliens = heals == HEALT_ALIENS or heals == HEALT_HUMANS_AND_ALIENS;
	bool healBreakables = heals == HEALT_BREAKABLES or heals == HEALT_MACHINES_AND_BREAKABLES;
		
	// breakables ignore friendly status for whatever reason
	if (target.IsBSPModel() and isRepairable(target) and (healBreakables or healAll))
		return true;
		
	int rel = plr.IRelationship(target);
	bool isFriendly = rel == R_AL or rel == R_NO;
	bool healFriend = mode == HEAL_FRIENDS or mode == HEAL_REVIVE_FRIENDS or mode == HEAL_ALL;
	bool healFoe = mode == HEAL_FOES or mode == HEAL_REVIVE_FOES or mode == HEAL_ALL;
	
	if ((isFriendly and healFriend) or (!isFriendly and healFoe))
	{
		
		if (healAll) return true;
		if (target.IsMachine() and healMachines) return true;
		if (isHuman(target) and healHumans) return true;
		if (isAlien(target) and healAliens) return true;
	}
	return false;
}

bool shouldAttack(CBaseEntity@ target, CBaseEntity@ plr, weapon_custom_shoot@ shoot_opts)
{
	bool shoot_on_damage = shoot_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0;
	if (!shouldHealTarget(target, plr, shoot_opts) and !shoot_on_damage)
		return false;
	return true;
}

float applyDamageModifiers(float damage, CBaseEntity@ target, CBaseEntity@ plr, weapon_custom_shoot@ shoot_opts)
{
	// don't do any damage if target is friendly and npc_kill is set to 0 or 2
	bool ignoreDmg = false;
	if (target.IsMonster()) {
		CBaseMonster@ mon = cast<CBaseMonster@>(target);
		if (mon.CheckAttacker(plr)) {
			damage = 0;
		}
	}
	
	bool didHeal = false;
	if (shouldHealTarget(target, plr, shoot_opts))
	{
		didHeal = true;
		damage = -damage;
	}
	
	// Award player with poitns (TODO: Account for hitgroup multipliers)
	plr.pev.frags += target.GetPointsForDamage(didHeal ? -damage : damage);
	
	return damage;
}

void knockBack(CBaseEntity@ target, Vector vel)
{
	if (target.IsMonster() and !target.IsMachine())
		target.pev.velocity = target.pev.velocity + vel;
}

float heal(CBaseEntity@ target, weapon_custom_shoot@ opts, float amt)
{
	float oldHealth = target.pev.health;
	if (opts.heal_mode < HEAL_REVIVE_FRIENDS)
	{
		target.pev.health += amt;
		if (target.pev.health > target.pev.max_health)
			target.pev.health = target.pev.max_health;
	}
	return oldHealth - target.pev.health;
}

float revive(CBaseEntity@ target, weapon_custom_shoot@ opts)
{
	target.EndRevive(0);
	target.pev.health = target.pev.max_health * (opts.bullet_damage/100.0f);
	return target.pev.health;
}

CBaseEntity@ getReviveTarget(Vector center, float radius, CBasePlayer@ plr, weapon_custom_shoot@ shoot_opts)
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityInSphere(ent, center, radius, "*", "classname"); 
		if (ent !is null)
		{
			if (ent.IsMonster() and !ent.IsAlive())
			{
				if (shouldHealTarget(ent, plr, shoot_opts))
				{
					return @ent;
				}
			}
		}
	} while (ent !is null);
	return null;
}

// breakable glass uses a special decal when shot
string getBulletDecalOverride(CBaseEntity@ ent, string currentDecal)
{
	TraceResult tr;
	if (ent !is null and isBreakableEntity(ent))
	{
		if (ent.pev.playerclass == 1) // learned this from HLSDK func_break.cpp line 158
			return getDecal(DECAL_GLASSBREAK);
		if (ent.TakeDamage(ent.pev, ent.pev, 0, DMG_GENERIC) == 0) // TODO: Don't do this, it makes sound
			return getDecal(DECAL_BULLETPROOF); // only unbreakable glass can't take damage
	}
	
	return currentDecal;
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

weapon_custom_effect@ loadEffectSettings(weapon_custom_effect@ effect)
{
	CBaseEntity@ ent = g_EntityFuncs.FindEntityByTargetname(null, effect.name);
	if (ent !is null)
	{
		weapon_custom_effect@ ef = cast<weapon_custom_effect@>(CastToScriptClass(ent));
		ef.loadExternalSoundSettings();
		ef.valid = true;
		ef.name = effect.name;
		return @ef;
	} 
	else if (string(effect.name).Length() > 0) 
	{
		println("WEAPON_CUSTOM ERROR: Failed to find weapon_custom_effect " + effect.name);
	}
	return @effect;
}

void loadSoundSettings(array<WeaponSound>@ sound_list)
{
	for (uint k = 0; k < sound_list.length(); k++)
		loadSoundSettings(sound_list[k]);
}

// Temporary Entity Effects (minimized)
void te_explosion(Vector pos, string sprite="sprites/zerogxplode.spr", int scale=10, int frameRate=15, int flags=0, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_EXPLOSION);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(scale);m.WriteByte(frameRate);m.WriteByte(flags);m.End(); }
void te_smoke(Vector pos, string sprite="sprites/steam1.spr", int scale=10, int frameRate=15, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_SMOKE);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(scale);m.WriteByte(frameRate);m.End(); }
void _te_beamcircle(Vector pos, float radius, string sprite, uint8 startFrame, uint8 frameRate, uint8 life, uint8 width, uint8 noise, Color c, uint8 scrollSpeed, NetworkMessageDest msgType, edict_t@ dest, int beamType) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(beamType);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z + radius);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(startFrame);m.WriteByte(frameRate);m.WriteByte(life);m.WriteByte(width);m.WriteByte(noise);m.WriteByte(c.r);m.WriteByte(c.g);m.WriteByte(c.b);m.WriteByte(c.a);m.WriteByte(scrollSpeed);m.End(); }
void te_beamtorus(Vector pos, float radius, string sprite="sprites/laserbeam.spr", uint8 startFrame=0, uint8 frameRate=16, uint8 life=8, uint8 width=8, uint8 noise=0, Color c=PURPLE, uint8 scrollSpeed=0, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_beamcircle(pos, radius, sprite, startFrame, frameRate, life, width, noise, c, scrollSpeed, msgType, dest, TE_BEAMTORUS); }
void te_beamdisk(Vector pos, float radius, string sprite="sprites/laserbeam.spr", uint8 startFrame=0, uint8 frameRate=16, uint8 life=8, uint8 width=8, uint8 noise=0, Color c=PURPLE, uint8 scrollSpeed=0, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_beamcircle(pos, radius, sprite, startFrame, frameRate, life, width, noise, c, scrollSpeed, msgType, dest, TE_BEAMDISK); }
void te_beamcylinder(Vector pos, float radius, string sprite="sprites/laserbeam.spr", uint8 startFrame=0, uint8 frameRate=16, uint8 life=8, uint8 width=8, uint8 noise=0, Color c=PURPLE, uint8 scrollSpeed=0, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_beamcircle(pos, radius, sprite, startFrame, frameRate, life, width, noise, c, scrollSpeed, msgType, dest, TE_BEAMCYLINDER); }
void te_breakmodel(Vector pos, Vector size, Vector velocity, uint8 speedNoise=16, string model="models/hgibs.mdl", uint8 count=8, uint8 life=0, uint8 flags=20, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BREAKMODEL);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteCoord(size.x);m.WriteCoord(size.y);m.WriteCoord(size.z);m.WriteCoord(velocity.x);m.WriteCoord(velocity.y);m.WriteCoord(velocity.z);m.WriteByte(speedNoise);m.WriteShort(g_EngineFuncs.ModelIndex(model));m.WriteByte(count);m.WriteByte(life);m.WriteByte(flags);m.End(); }
void te_dlight(Vector pos, uint8 radius=16, Color c=PURPLE, uint8 life=255, uint8 decayRate=4, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_DLIGHT);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteByte(radius);m.WriteByte(c.r);m.WriteByte(c.g);m.WriteByte(c.b);m.WriteByte(life);m.WriteByte(decayRate);m.End(); }
void _te_decal(Vector pos, CBaseEntity@ plr, CBaseEntity@ brushEnt, string decal, NetworkMessageDest msgType, edict_t@ dest, int decalType) { int decalIdx = g_EngineFuncs.DecalIndex(decal); int entIdx = brushEnt is null ? 0 : brushEnt.entindex(); if (decalIdx == -1) {  if (plr !is null) decalIdx = 0;  else  { println("Invalid decal: " + decalIdx); return;  } } if (decalIdx > 511) {  println("Decal index too high (" + decalIdx + ")! Max decal index is 511.");  return; } if (decalIdx > 255) {  decalIdx -= 255;  if (decalType == TE_DECAL) decalType = TE_DECALHIGH;  else if (decalType == TE_WORLDDECAL) decalType = TE_WORLDDECALHIGH;  else println("Decal type " + decalType + " doesn't support indicies > 255"); } if (decalType == TE_DECAL and entIdx == 0) decalType = TE_WORLDDECAL; if (decalType == TE_DECALHIGH and entIdx == 0) decalType = TE_WORLDDECALHIGH; NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest); m.WriteByte(decalType); if (plr !is null) m.WriteByte(plr.entindex()); m.WriteCoord(pos.x); m.WriteCoord(pos.y); m.WriteCoord(pos.z); switch(decalType) {  case TE_DECAL: case TE_DECALHIGH: m.WriteByte(decalIdx); m.WriteShort(entIdx); break;  case TE_GUNSHOTDECAL: case TE_PLAYERDECAL: m.WriteShort(entIdx); m.WriteByte(decalIdx); break;  default: m.WriteByte(decalIdx); } m.End(); }
void te_decal(Vector pos, CBaseEntity@ brushEnt=null, string decal="{handi", NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_decal(pos, null, brushEnt, decal, msgType, dest, TE_DECAL); }
void te_gunshotdecal(Vector pos, CBaseEntity@ brushEnt=null, string decal="{handi", NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_decal(pos, null, brushEnt, decal, msgType, dest, TE_GUNSHOTDECAL); }
void te_usertracer(Vector pos, Vector dir, float speed=6000.0f, uint8 life=32, uint color=4, uint8 length=12, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { Vector velocity = dir*speed;NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_USERTRACER);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteCoord(velocity.x);m.WriteCoord(velocity.y);m.WriteCoord(velocity.z);m.WriteByte(life);m.WriteByte(color);m.WriteByte(length);m.End();}
void te_tracer(Vector start, Vector end, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_TRACER);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.End(); }
void te_spritetrail(Vector start, Vector end, string sprite="sprites/hotglow.spr", uint8 count=2, uint8 life=0, uint8 scale=1, uint8 speed=16, uint8 speedNoise=8, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_SPRITETRAIL);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(count);m.WriteByte(life);m.WriteByte(scale);m.WriteByte(speedNoise);m.WriteByte(speed);m.End(); }
void te_streaksplash(Vector start, Vector dir, uint8 color=250, uint16 count=256, uint16 speed=2048, uint16 speedNoise=128, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_STREAK_SPLASH);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(dir.x);m.WriteCoord(dir.y);m.WriteCoord(dir.z);m.WriteByte(color);m.WriteShort(count);m.WriteShort(speed);m.WriteShort(speedNoise);m.End(); }
void te_glowsprite(Vector pos, string sprite="sprites/glow01.spr", uint8 life=1, uint8 scale=10, uint8 alpha=255, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_GLOWSPRITE);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(life);m.WriteByte(scale);m.WriteByte(alpha);m.End(); }
void te_bloodsprite(Vector pos, string sprite1="sprites/bloodspray.spr", string sprite2="sprites/blood.spr", uint8 color=70, uint8 scale=3, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BLOODSPRITE);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite1));m.WriteShort(g_EngineFuncs.ModelIndex(sprite2));m.WriteByte(color);m.WriteByte(scale);m.End(); }
void te_beampoints(Vector start, Vector end, string sprite="sprites/laserbeam.spr", uint8 frameStart=0, uint8 frameRate=100, uint8 life=20, uint8 width=2, uint8 noise=0, Color c=GREEN, uint8 scroll=32, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BEAMPOINTS);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(frameStart);m.WriteByte(frameRate);m.WriteByte(life);m.WriteByte(width);m.WriteByte(noise);m.WriteByte(c.r);m.WriteByte(c.g);m.WriteByte(c.b);m.WriteByte(c.a);m.WriteByte(scroll);m.End(); }
void _te_pointeffect(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null, int effect=TE_SPARKS) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(effect);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.End(); }
void te_sparks(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_pointeffect(pos, msgType, dest, TE_SPARKS); }
void te_bubbletrail(Vector start, Vector end, string sprite="sprites/bubble.spr", float height=128.0f, uint8 count=16, float speed=16.0f, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BUBBLETRAIL);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.WriteCoord(height);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(count);m.WriteCoord(speed);m.End(); }
