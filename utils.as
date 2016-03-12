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
void ambientSound(Vector origin, string soundFile, int flags)
{
	// play global sound
	string ambientName = "weapon_custom__" + g_ambientId;
	dictionary keyvalues;
	keyvalues["origin"] = origin.ToString();
	keyvalues["targetname"] = ambientName;
	keyvalues["message"] = soundFile;
	keyvalues["pitch"] = "100";
	keyvalues["spawnflags"] = "" + flags;
	keyvalues["playmode"] = "1";
	keyvalues["health"] = "10";

	CBaseEntity@ ambient = g_EntityFuncs.CreateEntity( "ambient_generic", keyvalues, true );
	g_EntityFuncs.FireTargets(ambientName, null, null, USE_ON);
	if (ambient !is null)
		g_EntityFuncs.Remove(ambient);
		
	g_ambientId++;
}

class DecalTarget
{
	Vector pos;
	CBaseEntity@ ent; // for when the target is a brush entity, not the world (0 = world)
}

class BeamImpact
{
	Vector pos;
	CBaseEntity@ ent;
}

// Extends tracers out in every direction in hopes of finding a surface
// Returns the brush entity found (or null, if world) and position of the nearest surface.
DecalTarget getProjectileDecalTarget(CBaseEntity@ ent, float searchDist)
{		
	DecalTarget decalTarget = DecalTarget();
	decalTarget.pos = ent.pev.origin;
	
	TraceResult tr;
	Vector src = ent.pev.origin;
	Vector end = src - ent.pev.velocity*2.0f;
	
	float bboxSize = ent.pev.maxs.x - ent.pev.mins.x;
	if (bboxSize < 0) bboxSize *= -1; // there's no abs() util function??
	
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
		g_Utility.TraceLine( src, src + dirs[i]*(bboxSize+searchDist), ignore_monsters, ent.edict(), tr );
		if (tr.flFraction < 1.0 and tr.pHit !is null)
		{
			decalTarget.pos = tr.vecEndPos;
			@decalTarget.ent = g_EntityFuncs.Instance( tr.pHit );
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
	
	
	void Spawn()
	{
		@options = shoot_opts.projectile;
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
		
		g_EntityFuncs.SetModel( self, pev.model );
		
		pev.mins = Vector(-options.size, -options.size, -options.size);
		pev.maxs = Vector(options.size, options.size, options.size);
		pev.mins = Vector(0.1, 0.1, 0.1);
		pev.friction = 1.0f - options.elasticity;
		
		SetThink( ThinkFunction( MoveThink ) );
		self.pev.nextthink = g_Engine.time + thinkDelay;
	}
	
	void MoveThink()
	{
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
		}
		else
		{
			g_EngineFuncs.VecToAngles(self.pev.velocity, self.pev.angles);
		}
		
		self.pev.nextthink = g_Engine.time + thinkDelay;
	}
	
	void uninstall_steam_and_kill_yourself()
	{
		g_EntityFuncs.Remove(self);
		if (spriteAttachment)
			g_EntityFuncs.Remove(spriteAttachment);
	}
	
	void KnockTarget(CBaseEntity@ ent)
	{
		ent.pev.velocity = ent.pev.velocity + pev.velocity.Normalize() * shoot_opts.knockback;
	}
	
	void Touch( CBaseEntity@ pOther )
	{
		if (attached)
			return;
		int event = PROJ_ACT_BOUNCE;
		if (pOther.IsBSPModel())
			event = options.world_event;
		else
			event = options.monster_event;
			
		KnockTarget(pOther);
		switch(event)
		{
			case PROJ_ACT_EXPLODE:
				explode_custom_projectile(@self, shoot_opts);
				uninstall_steam_and_kill_yourself();
				return;
			case PROJ_ACT_DAMAGE:
				uninstall_steam_and_kill_yourself();
				return;
			case PROJ_ACT_ATTACH:
				target = pOther;
				attachStartOri = unwindPoint(pev.origin - pOther.pev.origin, -pOther.pev.angles) + pOther.pev.origin;
				attachStartDir = unwindPoint(pev.velocity.Normalize(), -pOther.pev.angles);
				targetStartOri = pOther.pev.origin;
				self.pev.solid = SOLID_NOT;
				pev.velocity = Vector(0,0,0);
				attached = true;
				return;
		}
			
		if (options.bounce_decal.Length() > 0)
		{
			DecalTarget dt = getProjectileDecalTarget(self, 0);
			te_decal(dt.pos, dt.ent, options.bounce_decal);
		}
	}
}

void explode_custom_projectile(CBaseEntity@ ent, weapon_custom_shoot@ shoot_opts)
{
	int scale = Math.max(1, Math.min(255, int(shoot_opts.explode_mag/10)));
	int dscale = Math.max(8, Math.min(255, int(shoot_opts.explode_mag/20)));
	int smokeScale = Math.min(255, scale+10);
	float smokeDelay = 0.2;
	int life = 8;
	switch(shoot_opts.explosion_style)
	{
		case EXPLODE_SPRITE:
		{
			int flags = 2;
			if (shoot_opts.explode_snd.Length() > 0)
				flags |= 4;
			te_explosion(ent.pev.origin, shoot_opts.explode_spr, scale, 30, flags);
			smokeDelay = 0.4;
			break;
		}
		case EXPLODE_DISK:
			te_beamdisk(ent.pev.origin, shoot_opts.explode_mag, shoot_opts.explode_spr, 0, 15, life, 255, 0, WHITE, 0);
			break;
		case EXPLODE_CYLINDER:
			te_beamcylinder(ent.pev.origin, shoot_opts.explode_mag, shoot_opts.explode_spr, 0, 15, life, scale, 0, WHITE, 0);
			break;
		case EXPLODE_TORUS:
			te_beamtorus(ent.pev.origin, shoot_opts.explode_mag, shoot_opts.explode_spr, 0, 15, life, scale, 0, WHITE, 0);
			break;
	}
	
	if (shoot_opts.explode_smoke_spr.Length() > 0)
		g_Scheduler.SetTimeout("delayed_smoke", smokeDelay, ent.pev.origin, shoot_opts.explode_smoke_spr, smokeScale);
	if (shoot_opts.explode_snd.Length() > 0)
		ambientSound(ent.pev.origin, shoot_opts.explode_snd, 40);
	if (shoot_opts.explode_light.a > 0)
		te_dlight(ent.pev.origin, dscale, shoot_opts.explode_light, 255, 50);
		
	shoot_opts.explode_gibs = 8;
	if (shoot_opts.explode_gibs > 0)
	{
		te_breakmodel(ent.pev.origin, Vector(2,2,2), ent.pev.velocity, smokeScale, 
					  shoot_opts.explode_gib_mdl, shoot_opts.explode_gibs, 5, shoot_opts.explode_gib_mat | 16);
	}

	if (shoot_opts.explode_decal.Length() > 0)
	{
		// search is distance > 0 because it's unlikely that a projectile will be 
		// touching a surface when its life expires.
		DecalTarget dt = getProjectileDecalTarget(ent, 32.0f);
		te_decal(dt.pos, dt.ent, shoot_opts.explode_decal);
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
		if (options.die_event == PROJ_ACT_EXPLODE)
		{
			explode_custom_projectile(ent, shoot_opts);
		}
		g_EntityFuncs.Remove(ent);
	}
	if (sprite)
	{
		CBaseEntity@ ent = sprite;
		g_EntityFuncs.Remove(ent);
	}
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
void te_usertracer(Vector pos, Vector dir, float speed=6000.0f, uint8 life=32, uint color=4, uint8 length=12, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { Vector velocity = dir*speed;NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_USERTRACER);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteCoord(velocity.x);m.WriteCoord(velocity.y);m.WriteCoord(velocity.z);m.WriteByte(life);m.WriteByte(color);m.WriteByte(length);m.End();}
void te_tracer(Vector start, Vector end, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_TRACER);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.End(); }
void te_spritetrail(Vector start, Vector end, string sprite="sprites/hotglow.spr", uint8 count=2, uint8 life=0, uint8 scale=1, uint8 speed=16, uint8 speedNoise=8, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_SPRITETRAIL);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(count);m.WriteByte(life);m.WriteByte(scale);m.WriteByte(speedNoise);m.WriteByte(speed);m.End(); }
void te_streaksplash(Vector start, Vector dir, uint8 color=250, uint16 count=256, uint16 speed=2048, uint16 speedNoise=128, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_STREAK_SPLASH);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(dir.x);m.WriteCoord(dir.y);m.WriteCoord(dir.z);m.WriteByte(color);m.WriteShort(count);m.WriteShort(speed);m.WriteShort(speedNoise);m.End(); }
void te_glowsprite(Vector pos, string sprite="sprites/glow01.spr", uint8 life=1, uint8 scale=10, uint8 alpha=255, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_GLOWSPRITE);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(life);m.WriteByte(scale);m.WriteByte(alpha);m.End(); }
