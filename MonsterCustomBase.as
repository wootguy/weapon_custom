#include "utils"
#include "attack"

namespace WeaponCustom {

enum MOVE_STATES {
	MOVE_WAIT,
	MOVE_WALK,
	MOVE_RUN
}

class MonsterCustomBase : ScriptBaseMonsterEntity
{
	monster_custom@ settings;
	string monster_classname;
	string displayname;
	int bloodcolor = 0;
	array<WeaponSound> sounds;
	Vector pushVel;  // For some reason, pushing the monster only works during a Think
	
	WeaponState state;

	float next_idle_sound;
	
	EHandle m_hGoalEnt = null;
	EHandle h_enemy = null;
	int m_Activity;
	int m_IdealActivity;
	int move_state = MOVE_WAIT;
	float walk_speed = 10;
	float run_speed = 20;
	float last_think = 0;
	float next_ai_think = 0;
	float next_fade_out = 0;
	int fade_step = 0;
	int gib_mode = GIB_NORMAL;
	
	bool can_cancel_attack = false; // can cancel attack animation?
	
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
	
	int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
	{
		for (uint i = 0; i < settings.damages.length(); i++)
		{
			monster_custom_damage@ dmg_handler = settings.damages[i];
			if (dmg_handler.dmgType == -1 || (dmg_handler.dmgType & bitsDamageType) == dmg_handler.dmgType)
			{
				flDamage *= dmg_handler.pev.scale;
				
				if (dmg_handler.knockback != Vector(0,0,0))
				{
					Vector vecDir = self.pev.origin - (pevAttacker.absmin + pevAttacker.absmax) * 0.5;
					Vector angles = Math.VecToAngles(vecDir.Normalize());
					Math.MakeVectors(angles);
					Vector knockVel = g_Engine.v_forward*dmg_handler.knockback.z +
									  g_Engine.v_up*dmg_handler.knockback.y +
									  g_Engine.v_right*dmg_handler.knockback.x;
					
					float flForce = self.DamageForce(flDamage);
					pushVel = knockVel * flForce;
					pev.nextthink = g_Engine.time; // apply the push now
				}
			}	
		}
		CBaseEntity@ ent_attacker = g_EntityFuncs.Instance(pevAttacker);
		ent_attacker.pev.frags += flDamage * 0.01f;
		
		if (self.IsAlive())
			PainSound();
		
		int ret = BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );
		
		if (gib_mode == GIB_ALWAYS || self.pev.health <= -50)
		{
			// TODO: Custom gib sound
			g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "common/bodysplat.wav", Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 93 + Math.RandomLong(0, 0xf));
			g_EntityFuncs.SpawnRandomGibs(self.pev, 1, 1);
			g_EntityFuncs.Remove(self);
		}
			
		return ret;
	}
	
	void FadeOut()
	{
		if (fade_step == 0)
		{
			// TODO: Fade from whatever rendermode what set. Don't assume Normal/Texture rendermode was used.
			pev.rendermode = kRenderTransTexture;
			pev.renderamt = 255;
		}
		if (fade_step++ >= (255/7))
			g_EntityFuncs.Remove(self);
		
		pev.renderamt -= 7;
		if (pev.renderamt < 0)
			pev.renderamt = 0;
	}
	
	void MonsterThink()
	{
		AttackThink(state);
		
		if (pushVel != Vector(0,0,0))
		{
			knockBack(self, pushVel);
			pushVel = Vector(0,0,0);
		}

		if (self.IsAlive())
		{
			IdleSounds();
		}
		
		if (pev.deadflag == DEAD_DEAD)
		{
			if (next_fade_out > 0 and next_fade_out < g_Engine.time)
			{
				FadeOut();
			}
		}
		
		if (pev.deadflag == DEAD_DYING)
		{
			if (pev.frame >= 255) // wait for animation to finish
			{
				pev.deadflag = DEAD_DEAD;
				self.pev.takedamage = DAMAGE_YES;
				self.pev.solid = SOLID_NOT;
				if (self.pev.spawnflags & 512 == 0) // Make sure "Don't Fade Corpse" isn't enabled
					next_fade_out = g_Engine.time + 15; // TODO: Customize this
			}
		}
		
		if (g_Engine.time >= next_ai_think)
		{
			// animate
			float flInterval = self.StudioFrameAdvance(0.099);
			if (self.IsAlive() && self.m_fSequenceFinished) {
				self.ResetSequenceInfo();
			}
			self.DispatchAnimEvents(flInterval);

			// AI
			switch (self.m_MonsterState) 
			{
				case MONSTERSTATE_COMBAT: Combat(); break;
				case MONSTERSTATE_NONE:
				case MONSTERSTATE_IDLE: Idle(); break;
			}
			next_ai_think = g_Engine.time + 0.1f;
		}
		
		if (next_ai_think > g_Engine.time)
		{
			self.pev.nextthink = next_ai_think;
		}
		else
		{
			self.pev.nextthink = g_Engine.time + 0.1f;
		}
	}
	
	void Killed(entvars_t@ pevAttacker, int iGib) 
	{
		if (pev.deadflag != DEAD_NO)
			return;
		CBaseEntity@ ent_attacker = g_EntityFuncs.Instance(pevAttacker);
		ent_attacker.pev.frags += 1;
		
		if (m_Activity != ACT_DIESIMPLE)
			SetActivity(ACT_DIESIMPLE);
		
		self.m_MonsterState = MONSTERSTATE_DEAD;
		self.pev.takedamage = DAMAGE_NO;
		self.pev.deadflag = DEAD_DYING;
	}
	
	bool canRun()
	{
		return self.LookupActivity(ACT_RUN) != -1;
	}
	
	// returns true if activity is either finished or can be cancelled
	bool WaitActFinished()
	{
		if (m_Activity == ACT_MELEE_ATTACK1 and not can_cancel_attack and pev.frame < 255)
			return false;
		return true;
	}
	
	void Combat() 
	{
		if (!h_enemy)
		{
			self.m_MonsterState = MONSTERSTATE_IDLE;
			h_enemy = null;
			Idle();
			return;
		}
		CBaseEntity@ enemy = h_enemy;
		
		if (!ValidEnemy(enemy))
		{
			self.m_MonsterState = MONSTERSTATE_IDLE;
			h_enemy = null;
			Idle();
			return;
		}
		
		self.pev.ideal_yaw = Math.VecToYaw(enemy.pev.origin - self.pev.origin);		
		g_EngineFuncs.ChangeYaw(self.edict());
		
		float yawDiff = Math.AngleDiff(self.pev.angles.y, self.pev.ideal_yaw);
		
		if (!WaitActFinished())
			return;
			
		if (abs(yawDiff) > pev.yaw_speed)
		{
			// Need to turn around before moving towards target
			move_state = MOVE_WAIT;
			if (yawDiff < -pev.yaw_speed*4)
			{
				if (m_Activity != ACT_TURN_LEFT)
					SetActivity(ACT_TURN_LEFT);
			} 
			else if (yawDiff > pev.yaw_speed*4)
			{
				if (m_Activity != ACT_TURN_RIGHT)
					SetActivity(ACT_TURN_RIGHT);
			}
			else if (m_Activity != ACT_IDLE)
				SetActivity(ACT_IDLE);
		}
		else // facing enemy
		{
			// check if enemy is close enough
			float dist = (pev.origin - enemy.pev.origin).Length();
			Vector enemySize = enemy.pev.absmax - enemy.pev.absmin;
			enemySize.z = 0;
			Vector selfSize = pev.absmax - pev.absmin;
			selfSize.z = 0;
			dist -= (enemySize.Length() + selfSize.Length()) * 0.5f;
			bool closeEnough = dist < 32; // TODO: this should be some attack range						
			
			if (closeEnough)
			{
				bool finishedAttack = pev.frame >= 255;
				
				move_state = MOVE_WAIT;
				if (finishedAttack or m_Activity != ACT_MELEE_ATTACK1)
					SetActivity(ACT_MELEE_ATTACK1);
			} 
			else
			{
				// Try getting to enemy
				bool blocked = false;
				float speed = (canRun() ? run_speed : walk_speed);
				
				if (!closeEnough)
					blocked = g_EngineFuncs.WalkMove(self.edict(), self.pev.angles.y, speed, WALKMOVE_NORMAL) == 0;
				
				if (blocked)
				{
					// try to find some path to the target
					// TODO: Implement navigation from scratch since the API isn't available...
				}
			
				move_state = blocked ? MOVE_WAIT : (canRun() ? MOVE_RUN : MOVE_WALK);
				
				if (move_state == MOVE_WAIT)
					if (m_Activity != ACT_IDLE)
						SetActivity(ACT_IDLE);
				if (move_state == MOVE_WALK)
					if (m_Activity != ACT_WALK)
						SetActivity(ACT_WALK);
				if (move_state == MOVE_RUN)
					if (m_Activity != ACT_RUN)
						SetActivity(ACT_RUN);
			}
		}
	}
	
	void Idle()
	{
		if (FindEnemy()) 
		{
			self.m_MonsterState = MONSTERSTATE_COMBAT;
			return;
		}
		if (m_Activity != ACT_IDLE)
			SetActivity(ACT_IDLE);
	}
	
	bool CanSee(CBaseEntity@ ent)
	{
		// in FOV?
		Math.MakeVectors(self.pev.angles);
		Vector dir = (ent.pev.origin - self.pev.origin).Normalize();
		float flDot = DotProduct(dir, g_Engine.v_forward);
		//println("DOT: " + flDot + " " + self.m_flFieldOfView);
		if (flDot < self.m_flFieldOfView)
			return false;
		
		// eye contact?
		Vector vec1 = self.EyePosition();
		Vector vec2 = ent.EyePosition();
		TraceResult tr;
		g_Utility.TraceLine(vec1, vec2, ignore_monsters, ignore_glass, self.edict(), tr);
		if (tr.fInOpen != 0 && tr.fInWater != 0)
			return false;
		return tr.flFraction > 0.99;
	}
	
	bool ValidEnemy(CBaseEntity@ ent)
	{
		if (ent is null or !ent.IsMonster() or !ent.IsAlive() or ent.pev.FlagBitSet(FL_NOTARGET))
			return false;
		if (ent.pev.classname == "squadmaker" or ent.pev.classname == "monster_custom_generic")
			return false;
			
		int rel = self.IRelationship(ent);
		bool isFriendly = rel == R_AL or rel == R_NO;
		if (isFriendly)
			return false;
		
		return true;
	}
	
	bool FindEnemy() 
	{
		CBaseEntity@ pTarget = null;
		
		// Search PVS
		edict_t@ pvs = g_EngineFuncs.EntitiesInPVS(self.edict());
		CBaseEntity@ bestTarget = null;
		do {
			if (pvs is null)
				break;
				
			CBaseEntity@ ent = g_EntityFuncs.Instance(pvs);

			if (!ValidEnemy(ent) or !CanSee(ent))
				continue;
				
			// TODO: Ignore if too far away
			// TODO: Prioritize targets based on distance and threat level
			
			@bestTarget = @ent;
			
		} while ((@pvs = @pvs.vars.chain) !is null);
		
		if (bestTarget !is null)
		{
			h_enemy = bestTarget;
			println("SELECTED ENEMY: " + bestTarget.pev.classname);
			return true;
		}
		
		return false;
	}
	
	void SetActivity(Activity newActivity)
	{
		int iSeq = self.LookupActivity(newActivity);
		if (iSeq > -1) 
		{
			if (self.pev.sequence != iSeq || !self.m_fSequenceLoops)
				if (!(m_Activity == ACT_WALK || m_Activity == ACT_RUN) || !(newActivity == ACT_WALK || newActivity == ACT_RUN))
					self.pev.frame = 0;
			self.pev.sequence = iSeq;
			self.ResetSequenceInfo();
		} else {
			self.pev.sequence = 0;
		}
		m_Activity = newActivity;
		m_IdealActivity = newActivity;
	}
	
	void DoEvent(monster_custom_event@ event)
	{
		if (event.shoot_settings !is null)
		{
			@state.active_opts = @event.shoot_settings;
			
			DoAttack(state);
		}
		
		WeaponSound@ snd = event.getRandomSound();
		if (snd !is null)
		{
			snd.play(self, CHAN_ITEM);
			next_idle_sound = g_Engine.time + settings.idle_sound_freq; // try not to overlap sounds
		}
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
	
	void IdleSounds()
	{
		if (next_idle_sound < g_Engine.time)
		{
			if (self.m_MonsterState == MONSTERSTATE_IDLE)
				IdleSound();
			else
				AlertSound();
		}
	}
	
	void IdleSound()
	{
		next_idle_sound = g_Engine.time + settings.idle_sound_freq;
		WeaponSound@ snd = settings.getRandomIdleSound();
		if (snd !is null)
			snd.play(self, CHAN_ITEM);
	}
	
	void AlertSound()
	{
		next_idle_sound = g_Engine.time + settings.alert_sound_freq;
		WeaponSound@ snd = settings.getRandomAlertSound();
		if (snd !is null)
			snd.play(self, CHAN_ITEM);
	}
	
	void PainSound()
	{
		WeaponSound@ snd = settings.getRandomPainSound();
		if (snd !is null)
			snd.play(self, CHAN_ITEM);
	}
	
	Schedule@ GetSchedule( void )
	{
		println("GET SCHEDULE FOR STATE: " + self.m_MonsterState);
		return BaseClass.GetSchedule();
	}
}

}