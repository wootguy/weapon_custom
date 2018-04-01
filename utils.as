#include "attack"

class Color
{ 
	uint8 r, g, b, a;
	Color() { r = g = b = a = 0; }
	Color(uint8 r, uint8 g, uint8 b) { this.r = r; this.g = g; this.b = b; this.a = 255; }
	Color(uint8 r, uint8 g, uint8 b, uint8 a) { this.r = r; this.g = g; this.b = b; this.a = a; }
	Color(float r, float g, float b, float a) { this.r = uint8(r); this.g = uint8(g); this.b = uint8(b); this.a = uint8(a); }
	Color (Vector v) { this.r = uint8(v.x); this.g = uint8(v.y); this.b = uint8(v.z); this.a = 255; }
	string ToString() { return "" + r + " " + g + " " + b + " " + a; }
	Vector getRGB() { return Vector(r, g, b); }
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

// water splashes and bubble trails for bullets
void water_bullet_effects(Vector vecSrc, Vector vecEnd)
{
	// bubble trails
	bool startInWater = g_EngineFuncs.PointContents(vecSrc) == CONTENTS_WATER;
	bool endInWater = g_EngineFuncs.PointContents(vecEnd) == CONTENTS_WATER;
	if (startInWater or endInWater)
	{
		Vector bubbleStart = vecSrc;
		Vector bubbleEnd = vecEnd;
		Vector bubbleDir = bubbleEnd - bubbleStart;
		float waterLevel;
		
		// find water level relative to trace start
		Vector waterPos = startInWater ? bubbleStart : bubbleEnd;
		waterLevel = g_Utility.WaterLevel(waterPos, waterPos.z, waterPos.z + 1024);
		waterLevel -= bubbleStart.z;
		
		// get percentage of distance travelled through water
		float waterDist = 1.0f; 
		if (!startInWater or !endInWater)
			waterDist -= waterLevel / (bubbleEnd.z - bubbleStart.z);
		if (!endInWater)
			waterDist = 1.0f - waterDist;
		
		// clip trace to just the water  portion
		if (!startInWater)
			bubbleStart = bubbleEnd - bubbleDir*waterDist;
		else if (!endInWater)
			bubbleEnd = bubbleStart + bubbleDir*waterDist;
			
		// a shitty attempt at recreating the splash effect
		Vector waterEntry = endInWater ? bubbleStart : bubbleEnd;
		if (!startInWater or !endInWater)
			te_spritespray(waterEntry, Vector(0,0,1), g_watersplash_spr, 1, 64, 0);
		
		// waterlevel must be relative to the starting point
		if (!startInWater or !endInWater)
			waterLevel = bubbleStart.z > bubbleEnd.z ? 0 : bubbleEnd.z - bubbleStart.z;
			
		// calculate bubbles needed for an even distribution
		int numBubbles = int( (bubbleEnd - bubbleStart).Length() / 128.0f );
		numBubbles = Math.max(1, Math.min(255, numBubbles));
		
		te_bubbletrail(bubbleStart, bubbleEnd, "sprites/bubble.spr", waterLevel, numBubbles, 16.0f);
	}
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

class DecalTarget
{
	Vector pos;
	TraceResult tr;
	string texture;
	EHandle ent; // for when the target is a brush entity, not the world (0 = world)
}

class BeamImpact
{
	Vector pos;
	CBaseEntity@ ent;
	bool collision = true;
}

class BeamShot
{
	Vector startPos;
	TraceResult tr;
	CBaseEntity@ ent;
}

// Traces out in every direction in hopes of finding a surface
DecalTarget getProjectileDecalTarget(CBaseEntity@ ent, Vector pos, float searchDist)
{		
	DecalTarget decalTarget = DecalTarget();
	decalTarget.pos = ent !is null ? ent.pev.origin : pos;
	
	TraceResult tr;
	Vector src = decalTarget.pos;
	
	float bboxSize = 0;
	if (ent !is null)
		bboxSize = abs(ent.pev.maxs.x - ent.pev.mins.x);
	
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
		edict_t@ edict = ent !is null ? ent.edict() : null;
		g_Utility.TraceLine( src, end, ignore_monsters, edict, tr );
		
		//te_beampoints(src, end);
		
		if (tr.flFraction < 1.0 )
		{
			decalTarget.pos = tr.vecEndPos;
			decalTarget.tr = tr;
			if (tr.pHit !is null)
			{
				decalTarget.ent = EHandle(g_EntityFuncs.Instance( tr.pHit ));
				// get the texture too, we might need that for something
				decalTarget.texture = g_Utility.TraceTexture( tr.pHit, src, end );
			}
			
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

class WeaponCustomProjectile : ScriptBaseAnimating
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
	float nextBubbleTime = 0;
	float bubbleDelay = 0.07;
	float nextTrailEffectTime = 0;
	float nextBounceEffect = 0;
	
	void Spawn()
	{
		@options = shoot_opts.projectile;
		
		self.pev.movetype = options.gravity != 0 ? MOVETYPE_BOUNCE : MOVETYPE_BOUNCEMISSILE;
		self.pev.solid = SOLID_BBOX;
		
		g_EntityFuncs.SetModel( self, pev.model );
		
		pev.mins = Vector(-options.size, -options.size, -options.size);
		pev.maxs = Vector(options.size, options.size, options.size);
		pev.angles = pev.angles + options.angles;
		//pev.avelocity = options.avel;
		//pev.friction = 1.0f - options.elasticity;
		
		pev.frame = 0;
		pev.sequence = 0;
		pev.air_finished = 0; // set to 1 externally when this needs to die
		self.ResetSequenceInfo();
		
		SetThink( ThinkFunction( MoveThink ) );
		self.pev.nextthink = g_Engine.time + thinkDelay;
		
		move_snd_playing = options.move_snd.play(self, CHAN_BODY);
	}
	
	void MoveThink()
	{
		float nextThink = g_Engine.time + thinkDelay;
		
		if (pev.air_finished > 0)
		{
			uninstall_steam_and_kill_yourself();
			return;
		}
		
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
				
				float x = tar.pev.maxs.x - tar.pev.mins.x;
				float y = tar.pev.maxs.y - tar.pev.mins.y;
				float z = tar.pev.maxs.z - tar.pev.mins.z;
				float size = x*y*z;
				float playerSize = 32*32*72;
				//println("SIZE: " + x + "x" + y + "x" + z + " " + size);
				
				bool pullMode = shoot_opts.hook_pull_mode == HOOK_MODE_PULL or 
								shoot_opts.hook_pull_mode == HOOK_MODE_PULL_LEAST_WEIGHT;
				bool pullUser = shoot_opts.hook_pull_mode == HOOK_MODE_PULL_LEAST_WEIGHT and playerSize <= size;
				pullUser = pullUser or shoot_opts.hook_pull_mode == HOOK_MODE_PULL or tar.IsBSPModel();
				
				if (pullMode)
				{
					if (pullUser)
						owner.pev.velocity = owner.pev.velocity + dir*shoot_opts.hook_force;
					else
						tar.pev.velocity = tar.pev.velocity - dir*shoot_opts.hook_force*0.5;
				}
				else
					owner.pev.velocity = owner.pev.velocity + repelDir*shoot_opts.hook_force;
					
				if (pullUser)
				{
					if (owner.pev.velocity.Length() > shoot_opts.hook_max_speed)
						owner.pev.velocity = resizeVector(owner.pev.velocity, shoot_opts.hook_max_speed);
					
					if (pullMode and owner.pev.flags & FL_ONGROUND != 0 and dir.z > 0)
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
				}
				
				nextThink = g_Engine.time; // don't let gravity overpower the pull force too easily
			}
			
			if (!tar.IsBSPModel() and !tar.IsAlive())
			{
				attached = false;
				target = null;
				if (shoot_opts.hook_type != HOOK_DISABLED)
				{
					uninstall_steam_and_kill_yourself();
					return;
				}
				pev.movetype = options.gravity != 0 ? MOVETYPE_BOUNCE : MOVETYPE_BOUNCEMISSILE;
			}
		}
		else
		{
			if (attached)
			{
				attached = false;
				if (shoot_opts.hook_type != HOOK_DISABLED)
				{
					uninstall_steam_and_kill_yourself();
					return;
				}
				pev.movetype = options.gravity != 0 ? MOVETYPE_BOUNCE : MOVETYPE_BOUNCEMISSILE;
			}
			if (shoot_opts.pev.spawnflags & FL_SHOOT_PROJ_NO_ORIENT == 0)
				g_EngineFuncs.VecToAngles(self.pev.velocity, self.pev.angles);
		}
		
		if (move_snd_playing and pev.velocity.Length() == 0)
			options.move_snd.stop(self, CHAN_BODY);
			
		bool noBubbles = shoot_opts.pev.spawnflags & FL_SHOOT_NO_BUBBLES != 0;
		bool inWater = g_EngineFuncs.PointContents(pev.origin) == CONTENTS_WATER;
		if (!attached and !noBubbles and inWater)
		{
			if (nextBubbleTime < g_Engine.time)
			{
				Vector pos = pev.origin;
				float waterLevel = g_Utility.WaterLevel(pos, pos.z, pos.z + 1024) - pos.z;
				te_bubbletrail(pos, pos, "sprites/bubble.spr", waterLevel, 1, 16.0f);
				nextBubbleTime = g_Engine.time + bubbleDelay;
			}
		}
		
		if (inWater and options.water_friction != 0)
		{
			float speed = self.pev.velocity.Length();
			if (speed > 0)
				self.pev.velocity = resizeVector(self.pev.velocity, speed - speed*options.water_friction);
		}
		else if (!inWater and options.air_friction != 0)
		{
			float speed = self.pev.velocity.Length();
			if (speed > 0)
				self.pev.velocity = resizeVector(self.pev.velocity, speed - speed*options.air_friction);
		}
		
		if (shoot_opts.effect4.valid and nextTrailEffectTime < g_Engine.time)
		{
			nextTrailEffectTime = g_Engine.time + options.trail_effect_freq;
			CBaseEntity@ owner = g_EntityFuncs.Instance( self.pev.owner );
			EHandle howner = owner;
			custom_effect(self.pev.origin, shoot_opts.effect4, EHandle(self), howner, howner, pev.velocity.Normalize(), shoot_opts.friendly_fire ? 1 : 0);
		}
		
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
		
	void DamageTarget(CBaseEntity@ ent, bool friendlyFire)
	{	
		if (ent is null or ent.entindex() == 0 or shoot_opts.shoot_type == SHOOT_MELEE)
			return;
		CBaseEntity@ owner = g_EntityFuncs.Instance( self.pev.owner );
			
		// damage done before hitgroup multipliers
		float baseDamage = shoot_opts.damage;
		
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
		
		Vector oldVel = ent.pev.velocity;
		int dmgType = shoot_opts.damageType(DMG_CLUB);
		
		g_WeaponFuncs.ClearMultiDamage(); // fixes TraceAttack() crash for some reason
		ent.TraceAttack(owner.pev, baseDamage, vecAiming, tr, dmgType);
		
		if (friendlyFire)
		{
			// set both classes in case this a pvp map where classes are always changing
			int oldClass1 = owner.GetClassification(0);
			int oldClass2 = ent.GetClassification(0);
			owner.SetClassification(CLASS_PLAYER);
			ent.SetClassification(CLASS_ALIEN_MILITARY);
			g_WeaponFuncs.ApplyMultiDamage(owner.pev, owner.pev);
			owner.SetClassification(oldClass1);
			ent.SetClassification(oldClass2);
		}
		else
			g_WeaponFuncs.ApplyMultiDamage(owner.pev, owner.pev);
			
		if (dmgType & DMG_LAUNCH == 0) // prevent high damage from launching unless we ask for it
			ent.pev.velocity = oldVel;
		
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
		if (pOther.IsBSPModel())
		{
			if (shoot_opts.hook_targets == HOOK_MONSTERS_ONLY)
				return false;
				
			if (shoot_opts.hook_texture_filter.Length() > 0)
			{				
				DecalTarget dt = getProjectileDecalTarget(self, Vector(0,0,0), 1);
				string hitTex = dt.texture.ToLowercase();
				string matchTex = shoot_opts.hook_texture_filter.ToLowercase();
				if (hitTex.Find(matchTex) != 0)
					return false;
			}
		}
		else
		{
			if (shoot_opts.hook_targets == HOOK_WORLD_ONLY or !pOther.IsAlive())
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
			@effect = @shoot_opts.effect2;
			event = options.monster_event;
		}
		
		pev.velocity = pev.velocity*options.elasticity;
		
		if (weaponPickup)
		{
			// no more special effects after the first impact (pretend we're a weaponbox)
			WeaponSound@ rico_snd = effect.getRandomSound();
			if (rico_snd !is null)
				rico_snd.play(self.pev.origin, CHAN_STATIC);
			pev.avelocity.x *= -0.9;
			return; 
		}
		
		DamageTarget(pOther, shoot_opts.friendly_fire);
		knockBack(pOther, pev.velocity.Normalize() * shoot_opts.knockback);
		
		// don't spam bounce sounds when rolling on ground
		if (event != PROJ_ACT_BOUNCE or nextBounceEffect < g_Engine.time)
		{
			nextBounceEffect = g_Engine.time + options.bounce_effect_delay;
			CBaseEntity@ owner = g_EntityFuncs.Instance( self.pev.owner );
			EHandle howner = owner;
			EHandle htarget = pOther;
			custom_effect(self.pev.origin, effect, EHandle(self), htarget, howner, Vector(0,0,0), shoot_opts.friendly_fire ? 1 : 0);
		}
		
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
				
				// attach to center of monster
				if (shoot_opts.hook_type != HOOK_DISABLED and pOther.IsMonster())
				{
					CBaseMonster@ mon = cast<CBaseMonster@>(pOther);
					float height = mon.pev.maxs.z - mon.pev.mins.z;
					attachStartOri = mon.pev.origin + Vector(0,0,height*0.5f);					
				}
				return;
		}
	}
}

int getRandomPitch(int variance)
{
	return Math.RandomLong(100-variance, 100+variance);
}

// custom effect flags
int FL_EFFECT_FRIENDLY_FIRE = 1;
int FL_EFFECT_DELAY_FINISHED = 2;

void custom_effect(Vector pos, weapon_custom_effect@ effect, EHandle creator, EHandle target,
					EHandle owner, Vector vDir, int flags, DecalTarget@ dt=null)
{
	if (!effect.valid)
		return;
		
	if (dt is null)
	{
		@dt = @getProjectileDecalTarget(creator.IsValid() ? creator.GetEntity() : null, !creator.IsValid() ? pos : Vector(0,0,0), 32);
	}
	
	bool delayFinished = (flags & FL_EFFECT_DELAY_FINISHED) != 0;
	bool friendlyFire = (flags & FL_EFFECT_FRIENDLY_FIRE) != 0;
	if (effect.delay > 0 and !delayFinished)
	{
		g_Scheduler.SetTimeout("custom_effect", effect.delay, pos, @effect, creator, target, owner, vDir, flags | FL_EFFECT_DELAY_FINISHED, @dt);
		return;
	}
	
	// velocity for explosion-type effects
	Vector vel = delayFinished or !creator.IsValid() ? Vector(0,0,0) : creator.GetEntity().pev.velocity;
	bool inWater = g_EngineFuncs.PointContents(pos) == CONTENTS_WATER;
	Vector dir = !creator.IsValid() ? dt.tr.vecPlaneNormal : creator.GetEntity().pev.velocity.Normalize();	
		
	if (effect.pev.spawnflags & FL_EFFECT_EXPLOSION != 0)
	{
		Vector exp_pos = pos;
		if (dt.ent)
			exp_pos = exp_pos + dt.tr.vecPlaneNormal*effect.explode_offset;
		custom_explosion(exp_pos, vel, effect, dt.pos, dt.ent, owner, inWater, friendlyFire);
	}
	if (effect.pev.spawnflags & FL_EFFECT_LIGHTS != 0)
	{
		int l_size = int(effect.explode_light_adv.x);
		int l_life = int(effect.explode_light_adv.y);
		int l_decay = int(effect.explode_light_adv.z);
		if (l_size > 0 and l_life > 0)
			te_dlight(pos, l_size, effect.explode_light_color, l_life, l_decay);
			
		int l_size2 = int(effect.explode_light_adv2.x);
		int l_life2 = int(effect.explode_light_adv2.y);
		int l_decay2 = int(effect.explode_light_adv2.z);
		if (l_size2 > 0)
			te_dlight(pos, l_size2, effect.explode_light_color2, l_life2, l_decay2);
	}
	if (effect.pev.spawnflags & FL_EFFECT_SPARKS != 0)
	{
		te_sparks(pos);
	}
	if (effect.pev.spawnflags & FL_EFFECT_RICOCHET != 0)
	{
		te_ricochet(pos, 0);
	}
	if (effect.pev.spawnflags & FL_EFFECT_TARBABY != 0)
	{
		te_tarexplosion(pos);
	}
	if (effect.pev.spawnflags & FL_EFFECT_TARBABY2 != 0)
	{
		te_explosion2(pos);
	}
	if (effect.pev.spawnflags & FL_EFFECT_BURST != 0)
	{
		te_particlebust(pos, effect.burst_radius, effect.burst_color, effect.burst_life);
	}
	if (effect.pev.spawnflags & FL_EFFECT_LAVA != 0)
	{
		te_lavasplash(pos);
	}
	if (effect.pev.spawnflags & FL_EFFECT_TELEPORT != 0)
	{
		te_teleport(pos);
	}
	if (effect.glow_spr.Length() > 0)
	{
		te_glowsprite(pos, effect.glow_spr, effect.glow_spr_life, effect.glow_spr_scale, effect.glow_spr_opacity);
	}
	if (effect.spray_count > 0 and effect.spray_sprite.Length() > 0)
	{
		te_spritespray(pos, dir, effect.spray_sprite, effect.spray_count, effect.spray_speed, effect.spray_rand);
	}
	if (effect.implode_count > 0)
	{
		te_implosion(pos, effect.implode_radius, effect.implode_count, effect.implode_life);
	}
	if (effect.rico_part_count > 0)
	{
		te_spritetrail(pos, pos + dt.tr.vecPlaneNormal, effect.rico_part_spr, 
					   effect.rico_part_count, 0, effect.rico_part_scale, 
					   effect.rico_part_speed, effect.rico_part_speed/2);
	}
	if (effect.blood_stream != 0)
	{
		int stream_power = effect.blood_stream;
		Vector bdir = vDir;
		if (bdir == Vector())
			bdir = dir;
		if (stream_power < 0)
		{
			stream_power = -stream_power;
			bdir = bdir * -1;
		}
		int bcolor = 0;
		if (target)
		{
			CBaseEntity@ targetEnt = target;
			bcolor = targetEnt.BloodColor();
			if (bcolor == BLOOD_COLOR_RED) // 247
				bcolor = 222; // the enum val is wrong
		}
		
		te_bloodstream(pos, bdir, bcolor, stream_power);
	}
	if (effect.rico_trace_count > 0)
	{
		te_streaksplash(pos, dt.tr.vecPlaneNormal, effect.rico_trace_color,
						effect.rico_trace_count, effect.rico_trace_speed, effect.rico_trace_rand);
	}
	if (effect.rico_decal != DECAL_NONE and dt.ent)
	{
		string decal = getBulletDecalOverride(dt.ent, getDecal(effect.rico_decal));
		if (effect.pev.spawnflags & FL_EFFECT_GUNSHOT_RICOCHET != 0)
			te_gunshotdecal(pos, dt.ent, decal);
		else
			te_decal(pos, dt.ent, decal);
	}
	
	if (effect.explode_gibs > 0 and effect.explode_gib_mdl.Length() > 0)
	{		
		te_breakmodel(pos, Vector(2,2,2), dir*effect.explode_gib_speed, effect.explode_gib_rand, 
					  effect.explode_gib_mdl, effect.explode_gibs, 5, effect.explode_gib_mat | effect.explode_gib_effects);
	}
	if (effect.explode_bubbles > 0 and (inWater or effect.pev.spawnflags & FL_EFFECT_BUBBLES_IN_AIR != 0))
	{
		Vector mins = pos + effect.explode_bubble_mins;
		Vector maxs = pos + effect.explode_bubble_maxs;
		float height = (maxs.z - mins.z)*2.0f;
		if (inWater)
			height = g_Utility.WaterLevel(pos, pos.z, pos.z + 1024) - mins.z;
		string spr = effect.explode_bubble_spr;
		if (spr.Length() == 0)
			spr = "sprites/bubble.spr";
		int count = effect.explode_bubbles;
		float speed = effect.explode_bubble_speed;
		g_Scheduler.SetTimeout("delayed_bubbles", effect.explode_bubble_delay, mins, maxs, height, spr, count, speed);
	}
	if (effect.shake_radius > 0)
	{
		g_PlayerFuncs.ScreenShake(pos, effect.shake_amp, effect.shake_freq, effect.shake_time, effect.shake_radius);
	}
	
	WeaponSound@ rico_snd = effect.getRandomSound();
	if (rico_snd !is null)
		rico_snd.play(pos, CHAN_STATIC);
	
	if (effect.next_effect !is null)
		custom_effect(pos, effect.next_effect, creator, target, owner, vDir, flags & ~FL_EFFECT_DELAY_FINISHED, dt);
}

void custom_explosion(Vector pos, Vector vel, weapon_custom_effect@ effect, Vector decalPos, 
					  CBaseEntity@ decalEnt, EHandle owner, bool inWater, bool friendlyFire)
{
	if (!effect.valid)
		return;
		
	int smokeScale = int(effect.explode_smoke_spr_scale * 10.0f);
	int smokeFps = int(effect.explode_smoke_spr_fps);
	int expScale = int(effect.explode_spr_scale * 10.0f);
	int expFps = int(effect.explode_spr_fps);
	string expSprite = effect.explode_spr;
	if (inWater and effect.explode_water_spr.Length() > 0)
		expSprite = effect.explode_water_spr;
	int life = 8;
	
	if (expSprite.Length() > 0)
	{
		switch(effect.explosion_style)
		{
			case EXPLODE_SPRITE_PARTICLES:
			case EXPLODE_SPRITE:
			{					
				int flags = 2 | 4; // no sound or lights
				if (effect.explosion_style == EXPLODE_SPRITE)
					flags |= 8; // no particles
				te_explosion(pos, expSprite, expScale, expFps, flags);
				break;
			}
			case EXPLODE_DISK:
				te_beamdisk(pos, effect.explode_beam_radius, expSprite, 
								effect.explode_beam_frame, effect.explode_beam_fps, 
								effect.explode_beam_life, effect.explode_beam_width, 
								effect.explode_beam_noise, effect.explode_beam_color,
								effect.explode_beam_scroll);
				break;
			case EXPLODE_CYLINDER:
				te_beamcylinder(pos, effect.explode_beam_radius, expSprite, 
								effect.explode_beam_frame, effect.explode_beam_fps, 
								effect.explode_beam_life, effect.explode_beam_width, 
								effect.explode_beam_noise, effect.explode_beam_color,
								effect.explode_beam_scroll);
				break;
			case EXPLODE_TORUS:
				te_beamtorus(pos, effect.explode_beam_radius, expSprite, 
								effect.explode_beam_frame, effect.explode_beam_fps, 
								effect.explode_beam_life, effect.explode_beam_width, 
								effect.explode_beam_noise, effect.explode_beam_color,
								effect.explode_beam_scroll);
				break;
		}
	}
	
	if (effect.explode_radius > 0 and effect.explode_damage > 0 and owner)
	{
		CBaseEntity@ ownerEnt = owner;
		float radius = effect.explode_radius;
		float dmg = effect.explode_damage;
		
		if (friendlyFire)
		{
			// set class of all players to opposite of attacker, just until after we call RadiusDamage
			array<CBaseEntity@> victims;
			array<int> oldClassify;
			CBaseEntity@ victim = null;
			do {
				@victim = g_EntityFuncs.FindEntityByClassname(victim, "player");
				if (victim !is null)
				{
					victims.insertLast(victim);
					oldClassify.insertLast(victim.GetClassification(0));
					victim.SetClassification(CLASS_ALIEN_MILITARY);
				}
			} while (victim !is null);
			
			ownerEnt.SetClassification(CLASS_PLAYER);
			
			RadiusDamage(pos, ownerEnt.pev, ownerEnt.pev, dmg, radius, 0, effect.damageType());
			
			for (uint i = 0; i < victims.length(); i++)
				victims[i].SetClassification(oldClassify[i]);
		}
		else
		{
			RadiusDamage(pos, ownerEnt.pev, ownerEnt.pev, dmg, radius, 0, effect.damageType());
		}
	}
	
	if (effect.explode_smoke_spr.Length() > 0)
		g_Scheduler.SetTimeout("delayed_smoke", effect.explode_smoke_delay, pos, 
								effect.explode_smoke_spr, smokeScale, smokeFps);
}

// a basic set of directions for a sphere (up/down/left/right/front/back with 1 in-between step)
// This isn't good enough for large explosions, but hopefully FindEntityInSphere will work at that point.
array<Vector> sphereDirs = {Vector(1,0,0).Normalize(), Vector(0,1,0).Normalize(), Vector(0,0,1).Normalize(),
							  Vector(-1,0,0).Normalize(), Vector(0,-1,0).Normalize(), Vector(0,0,-1).Normalize(),
							  Vector(1,1,0).Normalize(), Vector(-1,1,0).Normalize(), Vector(1,-1,0).Normalize(), Vector(-1,-1,0).Normalize(),
							  Vector(1,0,1).Normalize(), Vector(-1,0,1).Normalize(), Vector(1,0,-1).Normalize(), Vector(-1,0,-1).Normalize(),
							  Vector(0,1,1).Normalize(), Vector(0,-1,1).Normalize(), Vector(0,1,-1).Normalize(), Vector(0,-1,-1).Normalize()};

void RadiusDamage( Vector vecSrc, entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, float flRadius, int iClassIgnore, int bitsDamageType )
{
	CBaseEntity@ pEntity = null;
	TraceResult	tr;
	float flAdjustedDamage, falloff;
	Vector vecSpot;

	if ( flRadius > 0 )
		falloff = flDamage / flRadius;
	else
		falloff = 1.0;

	bool bInWater = (g_EngineFuncs.PointContents(vecSrc) == CONTENTS_WATER);

	vecSrc.z += 1;// in case grenade is lying on the ground

	if ( pevAttacker is null )
		@pevAttacker = @pevInflictor;
	
	dictionary attacked;
	// iterate on all entities in the vicinity.
	while ((@pEntity = g_EntityFuncs.FindEntityInSphere( pEntity, vecSrc, flRadius, "*", "classname" )) != null)
	{
		attacked[pEntity.entindex()] = true;
		if ( pEntity.pev.takedamage != DAMAGE_NO )
		{
			// UNDONE: this should check a damage mask, not an ignore
			if ( iClassIgnore != CLASS_NONE && pEntity.Classify() == iClassIgnore )
			{// houndeyes don't hurt other houndeyes with their attack
				continue;
			}

			// blast's don't tavel into or out of water
			if (bInWater && pEntity.pev.waterlevel == 0)
				continue;
			if (!bInWater && pEntity.pev.waterlevel == 3)
				continue;

			vecSpot = pEntity.BodyTarget( vecSrc );
			
			g_Utility.TraceLine( vecSrc, vecSpot, dont_ignore_monsters, g_EntityFuncs.Instance(pevInflictor).edict(), tr );

			if ( tr.flFraction == 1.0 || g_EntityFuncs.Instance(tr.pHit).entindex() == g_EntityFuncs.Instance(pEntity.edict()).entindex() )
			{// the explosion can 'see' this entity, so hurt them!
				if (tr.fStartSolid != 0)
				{
					// if we're stuck inside them, fixup the position and distance
					tr.vecEndPos = vecSrc;
					tr.flFraction = 0.0;
				}
				
				// decrease damage for an ent that's farther from the bomb.
				flAdjustedDamage = ( vecSrc - tr.vecEndPos ).Length() * falloff;
				flAdjustedDamage = flDamage - flAdjustedDamage;
			
				if ( flAdjustedDamage < 0 )
				{
					flAdjustedDamage = 0;
				}
			
				if (tr.flFraction != 1.0)
				{
					g_WeaponFuncs.ClearMultiDamage( );
					pEntity.TraceAttack( pevInflictor, flAdjustedDamage, (tr.vecEndPos - vecSrc).Normalize( ), tr, bitsDamageType );
					g_WeaponFuncs.ApplyMultiDamage( pevInflictor, pevAttacker );
				}
				else
				{
					pEntity.TakeDamage ( pevInflictor, pevAttacker, flAdjustedDamage, bitsDamageType );
				}
			}
		}
	}

	// Now cast a few rays to make sure we hit the obvious targets. This is needed 
	// for things like tall func_breakables. For example, if the origin is at the 
	// bottom but the explosion origin is at the top. FindEntityInSphere won't  
	// detect it even if the explosion is touching the surface of the brush.
	for (uint i = 0; i < sphereDirs.size(); i++)
	{
		//te_beampoints(vecSrc, vecSrc + sphereDirs[i]*flRadius);
		g_Utility.TraceLine( vecSrc, vecSrc + sphereDirs[i]*flRadius, dont_ignore_monsters, g_EntityFuncs.Instance(pevInflictor).edict(), tr );
		CBaseEntity@ pHit = g_EntityFuncs.Instance(tr.pHit);
		if (pHit is null or attacked.exists(pHit.entindex()) or pHit.entindex() == 0)
			continue;
			
		attacked[pHit.entindex()] = true;
		
		if (tr.fStartSolid != 0)
		{
			// if we're stuck inside them, fixup the position and distance
			tr.vecEndPos = vecSrc;
			tr.flFraction = 0.0;
		}
		
		// decrease damage for an ent that's farther from the bomb.
		flAdjustedDamage = ( vecSrc - tr.vecEndPos ).Length() * falloff;
		flAdjustedDamage = flDamage - flAdjustedDamage;
	
		if ( flAdjustedDamage < 0 )
		{
			flAdjustedDamage = 0;
		}
	
		if (tr.flFraction != 1.0)
		{
			g_WeaponFuncs.ClearMultiDamage( );
			pHit.TraceAttack( pevInflictor, flAdjustedDamage, (tr.vecEndPos - vecSrc).Normalize( ), tr, bitsDamageType );
			g_WeaponFuncs.ApplyMultiDamage( pevInflictor, pevAttacker );
		}
		else
		{
			pHit.TakeDamage ( pevInflictor, pevAttacker, flAdjustedDamage, bitsDamageType );
		}
	}
	
}

void animate_view_angles(EHandle h_plr, Vector start_angle, Vector add_angle, float startTime, float endTime)
{
	if (!h_plr)
		return;
		
	CBaseEntity@ plr = h_plr;
	if (plr is null)
		return;
		
	float totalTime = endTime - startTime;
	float progress = 1;
	if (totalTime > 0)
		progress = (g_Engine.time - startTime) / totalTime;
	if (progress > 1)
		progress = 1;
		
	plr.pev.angles.x = (add_angle.x != 0) ? start_angle.x + add_angle.x*progress : plr.pev.v_angle.x;
	plr.pev.angles.y = (add_angle.y != 0) ? start_angle.y + add_angle.y*progress : plr.pev.v_angle.y;
	plr.pev.angles.z = (add_angle.z != 0) ? start_angle.z + add_angle.z*progress : plr.pev.v_angle.z;
	plr.pev.fixangle = FAM_FORCEVIEWANGLES;
	
	if (progress < 1)
		g_Scheduler.SetTimeout("animate_view_angles", 0, h_plr, start_angle, add_angle, startTime, endTime);
}

void player_sprites_effect(EHandle h_plr, string spr, int count)
{
	if (!h_plr)
		return;
		
	CBaseEntity@ ent = h_plr;
	if (ent is null or !ent.IsPlayer())
		return;
		
	CBasePlayer@ plr = cast<CBasePlayer@>(ent);
		
	te_playersprites(plr, spr, count);
}

void player_revert_glow(EHandle h_plr, Vector oldGlow, float oldGlowAmt, bool useOldGlow)
{
	if (!h_plr)
		return;
		
	CBaseEntity@ ent = h_plr;
	if (ent is null or !ent.IsPlayer())
		return;
		
	if (useOldGlow)
	{
		ent.pev.renderamt = oldGlowAmt;
		ent.pev.rendercolor = oldGlow;
	}
	else
		ent.pev.renderfx = 0;
}

void custom_user_effect(EHandle h_plr, EHandle h_wep, weapon_custom_user_effect@ effect, 
						bool delayFinished=false)
{
	if (effect is null or !h_plr)
		return;
		
	CBaseEntity@ plrEnt = h_plr;
	CBaseEntity@ wepEnt = h_wep;
	CBasePlayer@ plr = cast<CBasePlayer@>(plrEnt);
	CBasePlayerWeapon@ wep = cast<CBasePlayerWeapon@>(wepEnt);
	WeaponCustomBase@ c_wep = cast<WeaponCustomBase@>(CastToScriptClass(wepEnt));
		
	if (effect.delay > 0 and !delayFinished)
	{
		g_Scheduler.SetTimeout("custom_user_effect", effect.delay, h_plr, h_wep, effect, true);
		return;
	}
	
	if (effect.pev.spawnflags & FL_UEFFECT_KILL_ACTIVE != 0)
	{
		// TODO: Kill active effects
	}
	
	WeaponSound@ snd = effect.getRandomSound();
	if (snd !is null)
	{
		bool userOnly = effect.pev.spawnflags & FL_UEFFECT_USER_SOUNDS != 0;
		snd.play(plrEnt, CHAN_STATIC, 1, -1, 0, userOnly);
	}
	
	// damage 'em
	if (effect.self_damage != 0)
	{
		Vector oldVel = plrEnt.pev.velocity;
		plrEnt.TakeDamage(plrEnt.pev, plrEnt.pev, effect.self_damage, effect.damageType());
		
		// Idk why this even happens. No matter what the damage type is you get launched into the air
		plrEnt.pev.velocity = oldVel;
	}
		
	// punch 'em
	if (plrEnt.IsPlayer())
		plrEnt.pev.punchangle = effect.punch_angle;
	
	// push 'em
	Math.MakeVectors( plrEnt.pev.v_angle );
	Vector push = effect.push_vel;
	plrEnt.pev.velocity = plrEnt.pev.velocity + g_Engine.v_right*push.x + Vector(0,0,1)*push.y + g_Engine.v_forward*push.z;

	// rotate 'em
	if (effect.add_angle != Vector(0,0,0) or effect.add_angle_rand != Vector(0,0,0) and plrEnt.IsPlayer())
	{
		float startTime = g_Engine.time;
		float endTime = startTime + effect.add_angle_time;
		Vector r = effect.add_angle_rand;
		
		Vector randAngle = Vector(Math.RandomFloat(-r.x, r.x), Math.RandomFloat(-r.y,r.y), Math.RandomFloat(-r.z,r.z));
		Vector addAngle = effect.add_angle + randAngle;
		g_Scheduler.SetTimeout("animate_view_angles", 0, h_plr, plrEnt.pev.v_angle, addAngle, startTime, endTime);
	}
	
	// indicate something
	if (effect.action_sprite.Length() > 0 and plrEnt.IsPlayer())
		plr.ShowOverheadSprite(effect.action_sprite, effect.action_sprite_height, effect.action_sprite_time);
	
	// firstperson anim
	if (h_wep and wep !is null and plrEnt.IsAlive() and plrEnt.IsPlayer())
	{
		if (effect.v_model.Length() > 0 or effect.p_model.Length() > 0 or effect.w_model.Length() > 0 or effect.w_model_body >= 0)
		{
			c_wep.v_model_override = effect.v_model;
			c_wep.p_model_override = effect.p_model;
			c_wep.w_model_override = effect.w_model;
			if (effect.w_model_body >= 0)
				c_wep.w_model_body_override = effect.w_model_body;
			c_wep.Deploy(true);
		}
		if (effect.wep_anim != -1)
			wep.SendWeaponAnim( effect.wep_anim, 0, c_wep.w_body() );
			
		c_wep.TogglePrimaryFire(effect.primary_mode);
	}
	
	if (effect.hud_text.Length() > 0 and plrEnt.IsPlayer())
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, effect.hud_text);
	}
	
	// thirdperson anim
	if (effect.anim != -1 and plrEnt.IsPlayer())
	{
		plr.m_Activity = ACT_RELOAD;
		plr.pev.sequence = effect.anim;
		plr.pev.frame = effect.anim_frame;
		plr.ResetSequenceInfo();
		plr.pev.framerate = effect.anim_speed;
	}

	if (effect.fade_mode != -1 and plrEnt.IsPlayer())
	{
		g_PlayerFuncs.ScreenFade(plr, effect.fade_color.getRGB(), effect.fade_time, 
								 effect.fade_hold, effect.fade_color.a, effect.fade_mode);
	}
	
	//if (effect.pev.spawnflags & 
	//plr.EnableControl(false);
	//plr.pev.flags ^= 4096;
	
	if (effect.player_sprite_count > 0 and effect.player_sprite.Length() > 0 and plrEnt.IsPlayer())
	{
		int numIntervals = int(effect.player_sprite_time / effect.player_sprite_freq);
		
		player_sprites_effect(h_plr, effect.player_sprite, effect.player_sprite_count);
		g_Scheduler.SetInterval("player_sprites_effect", effect.player_sprite_freq, numIntervals, 
								h_plr, effect.player_sprite, effect.player_sprite_count);
	}
	
	if (effect.glow_time > 0)
	{
		// Remember old glow setting in case user is normally glowing due to map logic or server script
		Vector oldGlow = plr.pev.rendercolor;
		float oldGlowAmt = plr.pev.renderamt;
		bool isGlowing = plr.pev.renderfx == 19;
		
		plr.pev.renderfx = 19;
		plr.pev.renderamt = effect.glow_amt;
		plr.pev.rendercolor = effect.glow_color;
		
		g_Scheduler.SetTimeout("player_revert_glow", effect.glow_time, h_plr, oldGlow, oldGlowAmt, isGlowing);
	}
	
	if (effect.beam_mode != UBEAM_DISABLED and wep !is null)
	{
		CreateUserBeam(c_wep.state, @effect);
	}
	
	string targetStr = effect.pev.target;
	if (targetStr.Length() > 0)
	{
		CBaseEntity@ effectEnt = cast<CBaseEntity@>(@effect);
		g_EntityFuncs.FireTargets(targetStr, plrEnt, effectEnt, USE_TYPE(effect.triggerstate));
	}
	
	if (effect.next_effect !is null)
	{
		custom_user_effect(h_plr, h_wep, @effect.next_effect, false);
	}
}

void delayed_smoke(Vector origin, string sprite, int scale, int fps)
{
	te_smoke(origin, sprite, scale, fps);
}

void delayed_bubbles(Vector mins, Vector maxs, float height, string spr, int count, float speed)
{
	te_bubbles(mins, maxs, height, spr, count, speed);
}

void killProjectile(EHandle projectile, EHandle sprite, weapon_custom_shoot@ shoot_opts)
{
	ProjectileOptions@ options = shoot_opts.projectile;
	if (projectile)
	{
		CBaseEntity@ ent = projectile;
		CBaseEntity@ owner = g_EntityFuncs.Instance( ent.pev.owner );
		EHandle howner = owner;
		EHandle target;
		custom_effect(ent.pev.origin, shoot_opts.effect3, EHandle(ent), target, howner, Vector(0,0,0), shoot_opts.friendly_fire ? 1 : 0);
		ent.pev.air_finished = 1; // kill signal
		//g_EntityFuncs.Remove(ent);
	}
	if (sprite)
	{
		CBaseEntity@ ent = sprite;
		g_EntityFuncs.Remove(ent);
	}
}

void removeWeapon(CBasePlayerWeapon@ wep)
{
	//wep.Killed(wep.pev, 0);
	wep.m_hPlayer.GetEntity().RemovePlayerItem(wep);
}

void WaterSoundEffects(Vector pos, SoundArgs@ args)
{
	if (!args.underwaterEffects)
		return;
	if (g_EngineFuncs.PointContents(pos) == CONTENTS_WATER)
	{
		args.pitch = Math.max(0, args.pitch - Math.RandomLong(20, 30));
		args.volume *= 0.7f;
	}
}

void playSoundDelay(SoundArgs@ args)
{
	if (args.attachToEnt)
	{
		if (!args.ent)
			return;
		CBaseEntity@ ent = args.ent;

		WaterSoundEffects(ent.pev.origin + ent.pev.view_ofs, @args);
		
		g_SoundSystem.EmitSoundDyn( ent.edict(), args.channel, args.file, args.volume, args.attn, args.flags, 
									args.pitch, args.target_ent );
	}
	else
	{
		WaterSoundEffects(args.pos, @args);
		g_SoundSystem.PlaySound( null, args.channel, args.file, args.volume, 
								args.attn, args.flags, args.pitch, args.target_ent, true, args.pos );
	}
	
}

class SoundArgs
{
	bool valid = false;
	bool attachToEnt = true;
	Vector pos;
	EHandle ent;
	int target_ent=0; // target_ent_unreliable param
	SOUND_CHANNEL channel = CHAN_STATIC;
	string file;
	float volume = 1.0f;
	float attn = ATTN_NORM;
	int flags = 0;
	int pitch = 100;
	float delay = 0;
	WeaponSound@ next_snd;
	bool underwaterEffects = true;
}

class WeaponSound
{
	string file;
	weapon_custom_sound@ options;

	SoundArgs getSoundArgs(Vector pos, CBaseEntity@ ent, SOUND_CHANNEL channel=CHAN_STATIC, float volMult=1.0f, 
							int pitchOverride=-1, int additionalFlags=0, bool attachToEnt=false, bool userOnly=false)
	{
		if (file.Length() == 0)
			return SoundArgs();
		float volume = 1.0f;
		float attn = ATTN_NORM;
		int flags = additionalFlags;
		int pitch = getPitch();
		float delay = 0.0f;
		SOUND_CHANNEL chan = channel;
		WeaponSound@ nextSnd;
		bool underwaterEffects = true;
		if (options !is null)
		{
			@nextSnd = @options.next_snd;
			underwaterEffects = options.pev.spawnflags & FL_SOUND_NO_WATER_EFFECT == 0;
			delay = options.pev.friction;
			volume = options.pev.health / 100.0f;
			if (options.pev.sequence > -1)
				chan = SOUND_CHANNEL(options.pev.sequence);
			
			switch(options.pev.body)
			{
				case 1: attn = ATTN_IDLE; break;
				case 2: attn = ATTN_STATIC; break;
				case 3: attn = ATTN_NORM; break;
				case 4: attn = 0.3f; break;
				case 5: attn = ATTN_NONE; break;
			}
			
			if (options.pev.skin == 2)
				flags |= SND_FORCE_SINGLE;
			if (options.pev.skin == 3)
				flags |= SND_FORCE_LOOP;
		}
		if (pitchOverride != -1)
			pitch = pitchOverride;
		
		
		SoundArgs args;
		args.valid = true;
		args.attachToEnt = attachToEnt;
		args.pos = pos;
		args.delay = delay;
		args.ent = ent;
		args.channel = chan;
		args.file = file;
		args.volume = volume*volMult;
		args.attn = attn;
		args.flags = flags;
		args.pitch = pitch;
		args.target_ent = (ent !is null and userOnly) ? ent.entindex() : 0;
		args.underwaterEffects = underwaterEffects;
		@args.next_snd = @nextSnd;
		
		return args;
	}
	
	bool play(CBaseEntity@ ent, SOUND_CHANNEL channel=CHAN_STATIC, float volMult=1.0f, int pitchOverride=-1, 
			  int additionalFlags=0, bool userOnly=false)
	{
		SoundArgs args = getSoundArgs(Vector(0,0,0), ent, channel, volMult, pitchOverride, additionalFlags, 
									  true, userOnly);
		if (!args.valid)
			return false;
		
		//println("PLAY: " + args.file);
		if (args.delay > 0)		
			g_Scheduler.SetTimeout("playSoundDelay", args.delay, @args);
		else
		{
			WaterSoundEffects(ent.pev.origin + ent.pev.view_ofs, @args);
			g_SoundSystem.EmitSoundDyn( ent.edict(), args.channel, args.file, args.volume, 
									args.attn, args.flags, args.pitch, args.target_ent );
		}
		
		if (args.next_snd !is null)
			args.next_snd.play(ent, channel, volMult, pitchOverride, additionalFlags, userOnly);
		
		return true;
	}
	
	bool play(Vector pos, SOUND_CHANNEL channel=CHAN_STATIC, float volMult=1.0f, int pitchOverride=-1, 
			  int additionalFlags=0)
	{
		SoundArgs args = getSoundArgs(pos, null, channel, volMult, pitchOverride, additionalFlags, false);
		if (!args.valid)
			return false;
			
		if (args.delay > 0)		
			g_Scheduler.SetTimeout("playSoundDelay", args.delay, @args);
		else
		{
			WaterSoundEffects(args.pos, @args);
			g_SoundSystem.PlaySound( null, args.channel, args.file, args.volume, 
										args.attn, args.flags, args.pitch, args.target_ent, true, pos );
		}
		
		if (args.next_snd !is null)
			args.next_snd.play(pos, channel, volMult, pitchOverride, additionalFlags);
		
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
		if (file.Length() <= 0)
			return;
		if (options !is null and options.pev.sequence > -1)
			channel = SOUND_CHANNEL(options.pev.sequence);
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

bool shouldHealTarget(CBaseEntity@ target, CBaseEntity@ healer, weapon_custom_shoot@ shoot_opts)
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
		
	int rel = healer.IRelationship(target);
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

void monitorWeaponbox(CBaseEntity@ wep)
{
	if (wep !is null)
	{
		println("BODY: " + wep.pev.classname);
		wep.pev.body = 3;
		wep.pev.sequence = 8;
		g_Scheduler.SetTimeout("monitorWeaponbox", 0.1, @wep);
	}
	else
	{
		println("LEL NULL ENT");
	}
	
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
	target.pev.health = target.pev.max_health * (opts.damage/100.0f);
	return target.pev.health;
}

CBaseEntity@ getReviveTarget(Vector center, float radius, CBaseEntity@ healer, weapon_custom_shoot@ shoot_opts)
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityInSphere(ent, center, radius, "*", "classname"); 
		if (ent !is null)
		{
			if (ent.IsMonster() and !ent.IsAlive())
			{
				if (shouldHealTarget(ent, healer, shoot_opts))
				{
					return @ent;
				}
			}
		}
	} while (ent !is null);
	return null;
}

// force projectile to follow player's crosshairs
void projectile_follow_aim(EHandle h_plr, EHandle h_proj, weapon_custom_shoot@ opts, float timeLeft)
{
	if (!h_plr or !h_proj)
		return;
	
	CBaseEntity@ plrEnt = h_plr;
	CBasePlayer@ plr = cast<CBasePlayer@>(@plrEnt);
	CBaseEntity@ proj = h_proj;
	
	if (plr is null or proj is null)
		return;
		
	// TO_BE_SCARED_OF: Can this cause a race condition (other code using engine vectors at the same time)?
	Vector vecSrc = plr.GetGunPosition();
	Math.MakeVectors( plr.pev.v_angle );
	
	// get crosshair target location
	TraceResult tr;
	Vector vecEnd = vecSrc + g_Engine.v_forward * 65536;
	g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, proj.edict(), tr );
	
	Vector dir = proj.pev.velocity.Normalize();
	
	Vector targetDir;
	if (opts.projectile.follow_mode == FOLLOW_CROSSHAIRS)
	{
		targetDir = (tr.vecEndPos - proj.pev.origin).Normalize();
	}
	else if (opts.projectile.follow_mode == FOLLOW_ENEMIES)
	{
		CBaseEntity@ enemy = g_EntityFuncs.Instance( proj.pev.enemy );
		CBaseEntity@ ent = null;
		float bestDot = 0;
		float bestRange = 9999999.0f;
		float radius = opts.projectile.follow_radius;
		if (radius <= 0)
			radius = 9999999;
			
		// find closest enemy (TODO: give low dot products a weight to prefer not turning a lot)
		if (enemy is null)
		{
			do {
				@ent = g_EntityFuncs.FindEntityInSphere(ent, proj.pev.origin, radius, "*", "classname"); 
				if (ent !is null and ent.IsMonster() and ent.IsAlive())
				{
					if (ent.entindex() == plr.entindex())
						continue;
					if (ent.pev.classname == "squadmaker")
						continue;
					int rel = plr.IRelationship(ent);
					bool isFriendly = rel == R_AL or rel == R_NO;
	
					if (!isFriendly or true)
					{
						float dist = (ent.pev.origin - proj.pev.origin).Length();
						if (dist < bestRange)
						{
							bestRange = dist;
							@proj.pev.enemy = ent.edict();
						}
					}
				}
			} while (ent !is null);
			
			@enemy = g_EntityFuncs.Instance( proj.pev.enemy );
		}
		
		if (enemy !is null)
			targetDir = (enemy.BodyTarget(enemy.pev.origin) - proj.pev.origin).Normalize();
		else
			targetDir = dir;
	}
	
	float speed = proj.pev.velocity.Length();	
	
	Vector axis = CrossProduct(dir, targetDir).Normalize();
	
	float dot = DotProduct(targetDir, dir);
	float angle = -acos(dot);
	if (dot == -1)
		angle = Math.PI / 2.0f;
	if (dot == 1 or angle != angle)
		angle = 0;
	float maxAngle = opts.projectile.follow_angle * Math.PI / 180.0f;
	angle = Math.max(-maxAngle, Math.min(maxAngle, angle));
	
	if (abs(angle) > 0.001f)
	{
		// Apply rotation around arbitrary axis
		array<float> rotMat = rotationMatrix(axis, angle);
		dir = matMultVector(rotMat, dir).Normalize();
		proj.pev.velocity = dir*speed;
		g_EngineFuncs.VecToAngles(proj.pev.velocity, proj.pev.angles);	
	}
	
	
	bool oneMoreTime = false;
	if (timeLeft > 0)
	{
		timeLeft -= 0.05;
		if (timeLeft <= 0)
		{
			oneMoreTime = true;
			timeLeft = -1;
		}
	}
	
	if (timeLeft >= 0 or oneMoreTime)
		g_Scheduler.SetTimeout("projectile_follow_aim", opts.projectile.follow_time.z, h_plr, h_proj, @opts, timeLeft);
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
	if (snd !is null and snd.options !is null)
		return;
		
	CBaseEntity@ ent = g_EntityFuncs.FindEntityByTargetname(null, snd.file);
	if (ent !is null)
	{
		snd.file = ent.pev.message;
		@snd.options = cast<weapon_custom_sound@>(CastToScriptClass(ent));
		snd.options.loadExternalSoundSettings();
	}
}

weapon_custom_effect@ loadEffectSettings(weapon_custom_effect@ effect, string name="")
{
	if (effect !is null and effect.valid)
		return @effect;
		
	string searchStr = effect !is null ? effect.name : name;
	CBaseEntity@ ent = g_EntityFuncs.FindEntityByTargetname(null, searchStr);
	if (ent !is null)
	{
		weapon_custom_effect@ ef = cast<weapon_custom_effect@>(CastToScriptClass(ent));
		ef.loadExternalSoundSettings();
		ef.valid = true;
		ef.name = searchStr;
		
		@effect = @ef;
		
		ef.loadExternalEffectSettings(); // load chained effects
		return @ef;
	} 
	else if (string(searchStr).Length() > 0) 
	{
		println("WEAPON_CUSTOM ERROR: Failed to find weapon_custom_effect " + searchStr);
	}
	return @effect;
}

weapon_custom_user_effect@ loadUserEffectSettings(weapon_custom_user_effect@ effect, string name="")
{
	if (effect !is null and effect.valid)
		return @effect;
		
	CBaseEntity@ ent = g_EntityFuncs.FindEntityByTargetname(null, name);
	if (ent !is null)
	{
		weapon_custom_user_effect@ ef = cast<weapon_custom_user_effect@>(CastToScriptClass(ent));
		ef.loadExternalSoundSettings();
		ef.valid = true;
		
		@effect = @ef;
		
		ef.loadExternalUserEffectSettings(); // load chained effects
		return @ef;
	} 
	else if (string(name).Length() > 0) 
	{
		println("WEAPON_CUSTOM ERROR: Failed to find weapon_custom_user_effect " + name);
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
void te_bubbles(Vector mins, Vector maxs, float height=256.0f, string sprite="sprites/bubble.spr", uint8 count=64, float speed=16.0f, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BUBBLES);m.WriteCoord(mins.x);m.WriteCoord(mins.y);m.WriteCoord(mins.z);m.WriteCoord(maxs.x);m.WriteCoord(maxs.y);m.WriteCoord(maxs.z);m.WriteCoord(height);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(count);m.WriteCoord(speed);m.End(); }
void te_spritespray(Vector pos, Vector velocity, string sprite="sprites/bubble.spr", uint8 count=8, uint8 speed=16, uint8 noise=255, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_SPRITE_SPRAY);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteCoord(velocity.x);m.WriteCoord(velocity.y);m.WriteCoord(velocity.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(count);m.WriteByte(speed);m.WriteByte(noise);m.End(); }
void te_ricochet(Vector pos, uint8 scale=10, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_ARMOR_RICOCHET);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteByte(scale);m.End(); }
void te_tarexplosion(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) {_te_pointeffect(pos, msgType, dest, TE_TAREXPLOSION);}
void te_explosion2(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_EXPLOSION2);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteByte(0);m.WriteByte(127);m.End();}
void te_particlebust(Vector pos, uint16 radius=128, uint8 color=250, uint8 life=5, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) {NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_PARTICLEBURST);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(radius);m.WriteByte(color);m.WriteByte(life);m.End();}
void te_lavasplash(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_pointeffect(pos, msgType, dest, TE_LAVASPLASH); }
void te_teleport(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) {_te_pointeffect(pos, msgType, dest, TE_TELEPORT);}
void te_implosion(Vector pos, uint8 radius=255, uint8 count=32, uint8 life=5, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null){NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_IMPLOSION);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteByte(radius);m.WriteByte(count);m.WriteByte(life);m.End();}
void te_playersprites(CBasePlayer@ target, string sprite="sprites/bubble.spr", uint8 count=16, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) {NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_PLAYERSPRITES);m.WriteShort(target.entindex());m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(count);m.WriteByte(0);m.End();}
void te_bloodstream(Vector pos, Vector dir, uint8 color=70, uint8 speed=64, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BLOODSTREAM);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteCoord(dir.x);m.WriteCoord(dir.y);m.WriteCoord(dir.z);m.WriteByte(color);m.WriteByte(speed);m.End();}