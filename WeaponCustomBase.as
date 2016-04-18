
class WeaponCustomBase : ScriptBasePlayerWeaponEntity
{
	float m_flNextAnimTime;
	int m_iShell;
	int	m_iSecondaryAmmo;
	int lastButton; // last player button state
	int lastSequence;
	weapon_custom@ settings;
	
	array< array<EHandle> > beams = {{null}, {null}}; // CBeam handles
	array<EHandle> beamHits; // beam impact sprites (CSprite handles)
	float beamStartTime = 0;
	float minBeamTime = 0;
	float nextBeamAttack = 0; // constant beam attack delay
	
	float lastBeamDamage = 0;
	bool first_beam_shoot = false;
	
	bool beam_active = false;
	bool canShootAgain = true;
	
	bool meleeHit = false;
	bool healedTarget = true;
	bool abortAttack = false;
	float partialAmmoModifier = 1.0f; // scale damage by how much ammo was used
	int partialAmmoUsage; // reduce ammo usage if damage amount was less than expected (e.g. heal past max health)
	
	bool burstFiring = false;
	float nextBurstFire = 0;
	int numBurstFires = 0;
	
	bool windingUp = false;
	bool windupSoundActive = false;
	bool windingDown = false;
	bool windupHeld = false;
	bool windupFinished = false;
	bool windupLoopEntered = false;
	bool windupOvercharged = false;
	float windupStart = 0;
	float lastWindupInc = 0;
	float nextWindupShoot = 0;
	float windupMultiplier = 1.0f;
	float windupKickbackMultiplier = 1.0f;
	int windupAmmoUsed = 0;
	
	float lastPrimaryRegen = 0;
	float lastSecondaryRegen = 0;
	
	float nextShootTime = 0;
	float nextActionTime = 0;
	float unhideLaserTime = 0;
	float ejectShellTime = 0;
	float nextCooldownSound = 0;
	float nextReload = 0;
	float nextReloadEnd = 0;
	bool needShellEject = false;
	int reloading = 0; // continous reload state
	
	WeaponSound@ lastCooldownSnd;
	WeaponSound@ lastShootSnd;
	
	int active_fire = -1;
	int active_ammo_type = -1;
	weapon_custom_shoot@ active_opts; // active shoot opts
	
	EHandle hook_ent;
	EHandle hook_beam;
	bool shootingHook = false;
	bool hookAnimStarted = false;
	float hookAnimStartTime = 0;
	
	bool primaryAlt = false;
	
	EHandle laser_spr;
	
	int shootCount = 0;
	int liveProjectiles = 0;
	
	void Spawn()
	{
		if (settings is null) {
			@settings = cast<weapon_custom>( @custom_weapons[self.pev.classname] );
		}		
		
		Precache();
		g_EntityFuncs.SetModel( self, settings.wpn_w_model );

		self.m_iDefaultAmmo = settings.clip_size();
		
		self.FallInit();
		SetThink( ThinkFunction( WeaponThink ) );
	}

	void Precache()
	{
		self.PrecacheCustomModels();
	}

	void RegenAmmo(int ammoType)
	{
		if (self.m_pPlayer is null)
			return;
		int ammoLeft = self.m_pPlayer.m_rgAmmo(ammoType);
		int maxAmmo = self.m_pPlayer.GetMaxAmmo(ammoType);
		ammoLeft += settings.primary_regen_amt;
		
		if (ammoLeft < 0) 
			ammoLeft = 0;
		if (ammoLeft > maxAmmo) 
			ammoLeft = maxAmmo;
			
		self.m_pPlayer.m_rgAmmo(ammoType, ammoLeft);
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		if (settings is null) {
			@settings = cast<weapon_custom>( @custom_weapons[self.pev.classname] );
		}
		
		info.iMaxAmmo1 	= 1; // doesn't even matter??
		info.iMaxAmmo2 	= 1; // ^
		info.iMaxClip 	= settings.clip_size();
		if (info.iMaxClip < 1)
			self.m_iClip = -1;
		
		//self.m_iClip2 = 2; // secondary clip not working? :<
		info.iSlot 		= settings.slot;
		info.iPosition 	= settings.slotPosition;
		info.iFlags 	= settings.pev.spawnflags & 0x1F;
		info.iWeight 	= settings.priority;

		// ammo regeneration
		if (settings.primary_regen_amt != 0 and lastPrimaryRegen < g_Engine.time)
		{
			lastPrimaryRegen = g_Engine.time + settings.primary_regen_time;
			RegenAmmo(self.m_iPrimaryAmmoType);
			
		}
		if (settings.secondary_regen_amt != 0 and lastSecondaryRegen < g_Engine.time)
		{
			lastSecondaryRegen = g_Engine.time + settings.secondary_regen_time;
			RegenAmmo(self.m_iPrimaryAmmoType);
		}
		
		if (settings.pev.spawnflags & FL_WEP_HIDE_SECONDARY_AMMO != 0 and settings.matchingAmmoTypes)
			self.m_iSecondaryAmmoType = self.m_iPrimaryAmmoType;
		
		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( BaseClass.AddToPlayer( pPlayer ) )
		{
			NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
				message.WriteLong( self.m_iId );
			message.End();
			return true;
		}
		
		return false;
	}
	
	bool PlayEmptySound(weapon_custom_shoot@ opts)
	{
		if( self.m_bPlayEmptySound or true )
		{
			self.m_bPlayEmptySound = false;
			if (opts.isPrimary())
				settings.primary_empty_snd.play(self.m_pPlayer, CHAN_WEAPON);
			else if (opts.isSecondary())
				settings.secondary_empty_snd.play(self.m_pPlayer, CHAN_WEAPON);
			else
				settings.tertiary_empty_snd.play(self.m_pPlayer, CHAN_WEAPON);
		}
		
		return false;
	}

	bool Deploy()
	{
		if (settings.pev.spawnflags & FL_WEP_LASER_SIGHT != 0 and !primaryAlt)
		{
			ShowLaser();
			unhideLaserTime = g_Engine.time + 0.5;
		}
		bool ret = self.DefaultDeploy( self.GetV_Model( settings.wpn_v_model ), self.GetP_Model( settings.wpn_p_model ), 
								   settings.deploy_anim, settings.getPlayerAnimExt() );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + settings.deploy_time;					   
		return ret;
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time; //g_WeaponFuncs.WeaponTimeBase();
	}
		
	// may actually be sequential if the flag for that is enabled
	int getRandomShootAnim()
	{
		return getRandomAnim(active_opts.shoot_anims);
	}
	
	int getRandomMeleeAnim()
	{
		return getRandomAnim(active_opts.melee_anims);
	}
	
	int getRandomAnim(const array<string>& anims)
	{
		if (anims.length() == 0)
			return 0;
	
		if (true)
			lastSequence = (lastSequence+1) % anims.length();
		else
			lastSequence = Math.RandomLong(0, anims.length()-1);
		//return self.LookupSequence(active_opts.shoot_anims[lastSequence]);  // I wish this worked :<
		return atoi( anims[lastSequence] );
	}
	
	void ShootOneBullet()
	{
		Vector vecSrc	 = self.m_pPlayer.GetGunPosition();
		Math.MakeVectors( self.m_pPlayer.pev.v_angle );
		Vector vecAiming = spreadDir(g_Engine.v_forward, active_opts.bullet_spread, active_opts.bullet_spread_func);
		
		// Do the bullet collision
		TraceResult tr;
		Vector vecEnd = vecSrc + vecAiming * active_opts.max_range;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, self.m_pPlayer.edict(), tr );
		//te_beampoints(vecSrc, vecEnd);
		
		if ( tr.flFraction >= 1.0 and active_opts.shoot_type == SHOOT_MELEE)
		{
			// This does a trace in the form of a box so there is a much higher chance of hitting something
			// From crowbar.cpp in the hlsdk:
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, self.m_pPlayer.edict(), tr );
			if ( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null or pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, self.m_pPlayer.edict() );
				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}
		
		meleeHit = active_opts.shoot_type == SHOOT_MELEE and tr.flFraction < 1.0;
		
		bool revivedSomething = false;
		bool reviveOnly = active_opts.heal_mode >= HEAL_REVIVE_FRIENDS;
		if (reviveOnly)
		{
			CBaseEntity@ revTarget = getReviveTarget(tr.vecEndPos, REVIVE_RADIUS, self.m_pPlayer, active_opts);
			if (revTarget !is null)
			{
				float revPoints = revive(revTarget, active_opts);
				revivedSomething = true;
				
				// revive attacks are special and always play melee hit sounds
				if (active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP == 0)
				{
					WeaponSound@ snd = active_opts.getRandomMeleeHitSound();
					if (snd !is null)
						snd.play(self.m_pPlayer, CHAN_VOICE);
				}
			}
		}
		
		water_bullet_effects(vecSrc, tr.vecEndPos);
		
		// do more fancy effects
		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit !is null ) 
				{					
					if (!AttackMonster(vecSrc, tr))
					{
						abortAttack = !revivedSomething;
						return;
					}
					
					string decal = getBulletDecalOverride(pHit, getDecal(active_opts.bullet_decal));
					if (pHit.IsBSPModel()) {
						if (active_opts.bullet_impact == BULLET_IMPACT_STANDARD)
							te_gunshotdecal(tr.vecEndPos, pHit, decal);
						if (active_opts.bullet_impact == BULLET_IMPACT_MELEE)
							te_decal(tr.vecEndPos, pHit, decal);
					}
					
					bool playDefaultMeleeSnd = active_opts.shoot_type == SHOOT_MELEE;
					bool playDefaultMeleeSndQuietly = isBreakableEntity(pHit); // only SC does this
					if (pHit.IsMonster() or pHit.IsPlayer())
					{
						if (!pHit.IsMachine())
						{
							// impact sound
							WeaponSound@ snd = active_opts.getRandomMeleeFleshSound();
							if (snd !is null)
								snd.play(self.m_pPlayer, CHAN_VOICE);
							playDefaultMeleeSnd = false;
						}
						else
							playDefaultMeleeSndQuietly = true;
					} 
				
					if (playDefaultMeleeSnd)
					{
						float volume = playDefaultMeleeSndQuietly ? 0.5f : 1.0f;
						WeaponSound@ snd = active_opts.getRandomMeleeHitSound();
						if (snd !is null)
							snd.play(self.m_pPlayer, CHAN_VOICE, volume);
					}
				}
			}
		}
		else // Bullet didn't hit anything
		{
			if (active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_MISS != 0)
			{
				abortAttack = !revivedSomething;
				return;
			}
						
			bool meleeSkip = active_opts.shoot_type == SHOOT_MELEE;
			meleeSkip = meleeSkip and (active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP != 0);
			// melee weapons are special and only play shoot sounds when they miss
			if (meleeSkip and !shootingHook)
			{
				WeaponSound@ snd = active_opts.getRandomShootSound();
				snd.play(self.m_pPlayer, CHAN_WEAPON);
			}
		}
		
		// bullet tracer effects
		if (active_opts.bullet_color != -1)
		{
			if (active_opts.bullet_color == 4)
			{
				// default tracer, no special calculations needed
				te_tracer(vecSrc, tr.vecEndPos);
			}
			else
			{
				// no way to prevent usertracer going through walls, but we can at least minimize that.
				float len = tr.flFraction*active_opts.max_range;
				int life = int(len / 600.0f) + 1;
				te_usertracer(vecSrc, vecAiming, 6000.0f, life, active_opts.bullet_color, 12);
			}
		}
		
		if (active_opts.bullet_impact == BULLET_IMPACT_EXPLODE)
		{
			// move the explosion away from the surface so the sprite doesn't clip through it
			Vector expPos = tr.vecEndPos + tr.vecPlaneNormal*16.0f;
			g_EntityFuncs.CreateExplosion(expPos, Vector(0,0,0), self.m_pPlayer.edict(), 50, true);
			//te_explosion(expPos, "sprites/zerogxplode.spr", 10, 15, 0);
		}
	}
		
	void ShootBullets()
	{
		if (active_opts.bullet_delay > 0 and active_opts.bullets > 1)
		{
			burstFiring = true;
			ShootOneBullet();
			numBurstFires = 1;
			nextBurstFire = g_Engine.time + active_opts.bullet_delay;
			self.pev.nextthink = g_Engine.time;
			return;
		}
		for (int i = 0; i < active_opts.bullets; i++)
			ShootOneBullet();
	}
	
	CBaseEntity@ ShootCustomProjectile(string classname, Vector ori, Vector vel)
	{
		ProjectileOptions@ options = @active_opts.projectile;
		
		dictionary keys;
		Vector boltAngles = self.m_pPlayer.pev.v_angle * Vector(-1, 1, 1);
		keys["origin"] = ori.ToString();
		keys["angles"] = boltAngles.ToString();
		keys["velocity"] = vel.ToString();
		
		// replace model or use error.mdl if no model specified and not a standard entity
		string model = options.model.Length() > 0 ? options.model : "models/error.mdl";
		if (options.type == PROJECTILE_CUSTOM or options.type == PROJECTILE_OTHER and options.model.Length() > 0) 
			keys["model"] = model;
		if (options.type == PROJECTILE_WEAPON)
			keys["model"] = settings.wpn_w_model;
		if (options.type == PROJECTILE_CUSTOM and options.model.Length() == 0)
			keys["rendermode"] = "1"; // don't render the model
			
		CBaseEntity@ shootEnt = g_EntityFuncs.CreateEntity(classname, keys, false);	
		@shootEnt.pev.owner = self.m_pPlayer.edict(); // do this or else crash	
		WeaponCustomProjectile@ shootEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(shootEnt));
		if (shootEnt_c !is null)
		{
			@shootEnt_c.shoot_opts = @active_opts;
			shootEnt_c.pickup_classname = settings.weapon_classname;
		}
		
		g_EntityFuncs.DispatchSpawn(shootEnt.edict());
		
		return shootEnt;
	}
	
	CBaseEntity@ ShootProjectile()
	{
		Math.MakeVectors( self.m_pPlayer.pev.v_angle );
		
		ProjectileOptions@ options = active_opts.projectile;
		
		// Get amount of velocity to add to projectile. Velocity axes are scaled relative to aim direction
		Vector inf = options.player_vel_inf;
		Vector pvel = self.m_pPlayer.pev.velocity;
		pvel = g_Engine.v_right * DotProduct(g_Engine.v_right, pvel)*inf.x +
			   g_Engine.v_up * DotProduct(g_Engine.v_up, pvel)*inf.y +
			   g_Engine.v_forward * DotProduct(g_Engine.v_forward, pvel)*inf.z;
			   
		Vector projectile_velocity = g_Engine.v_forward * options.speed + pvel;
		
		Vector ofs = g_Engine.v_right*options.offset.x + g_Engine.v_up*options.offset.y + g_Engine.v_forward*options.offset.z;
		Vector projectile_ori = self.m_pPlayer.GetGunPosition() + ofs;
		float grenadeTime = options.life != 0 ? options.life : 3.5f; // timed grenades only
		
		CGrenade@ nade = null;
		CBaseEntity@ shootEnt = null;
		if (options.type == PROJECTILE_ARGRENADE)
			@nade = g_EntityFuncs.ShootContact( self.m_pPlayer.pev, projectile_ori, projectile_velocity );
		else if (options.type == PROJECTILE_BANANA)
			@nade = g_EntityFuncs.ShootBananaCluster( self.m_pPlayer.pev, projectile_ori, projectile_velocity );
		else if (options.type == PROJECTILE_BOLT)
			ShootCustomProjectile("crossbow_bolt", projectile_ori, projectile_velocity);
		else if (options.type == PROJECTILE_HVR)
			ShootCustomProjectile("hvr_rocket", projectile_ori, projectile_velocity);
		else if (options.type == PROJECTILE_SHOCK)
			ShootCustomProjectile("shock_beam", projectile_ori, projectile_velocity);
		else if (options.type == PROJECTILE_HORNET)
			ShootCustomProjectile("playerhornet", projectile_ori, projectile_velocity);
		else if (options.type == PROJECTILE_DISPLACER)
			@shootEnt = g_EntityFuncs.CreateDisplacerPortal( projectile_ori, projectile_velocity, self.m_pPlayer.edict(), 250, 250 );
		else if (options.type == PROJECTILE_GRENADE)
			@nade = g_EntityFuncs.ShootTimed( self.m_pPlayer.pev, projectile_ori, projectile_velocity, grenadeTime );
		else if (options.type == PROJECTILE_MORTAR)
			@nade = g_EntityFuncs.ShootMortar( self.m_pPlayer.pev, projectile_ori, projectile_velocity );
		else if (options.type == PROJECTILE_RPG)
		{
			@shootEnt = g_EntityFuncs.CreateRPGRocket(projectile_ori, self.m_pPlayer.pev.v_angle, self.m_pPlayer.edict());
			shootEnt.pev.velocity = shootEnt.pev.velocity + projectile_velocity;
		}
		else if (options.type == PROJECTILE_WEAPON)
			@shootEnt = ShootCustomProjectile("custom_projectile", projectile_ori, projectile_velocity);
		else if (options.type == PROJECTILE_CUSTOM)
			@shootEnt = ShootCustomProjectile("custom_projectile", projectile_ori, projectile_velocity);
		else if (options.type == PROJECTILE_OTHER)
			@shootEnt = ShootCustomProjectile(options.entity_class, projectile_ori, projectile_velocity);
		else
			println("Unknown projectile type: " + options.type);
			
		if (nade !is null)
			@shootEnt = cast<CBaseEntity@>(nade);
			
		if (shootEnt !is null)
		{
			if (active_opts.pev.spawnflags & FL_SHOOT_PROJ_NO_GRAV != 0) // disable gravity on projectile
				shootEnt.pev.movetype = MOVETYPE_FLY;
				
			if (options.follow_mode != FOLLOW_NONE)
			{
				EHandle h_plr = self.m_pPlayer;
				EHandle h_proj = shootEnt;
				float dur = options.follow_time.y;
				g_Scheduler.SetTimeout("projectile_follow_aim", options.follow_time.x, h_plr, h_proj, @active_opts, dur);
			}
			
			EHandle mdlHandle = @shootEnt;
			EHandle sprHandle;
			
			// TODO: Kill this when follow target dies (and its not a custom entity)
			if (options.sprite.Length() > 0)
			{
				dictionary keyvalues;
				keyvalues["origin"] = shootEnt.pev.origin.ToString();
				keyvalues["model"] = options.sprite;
				keyvalues["rendermode"] = "5";
				keyvalues["renderamt"] = "255";
				CBaseEntity@ spr = g_EntityFuncs.CreateEntity( "env_sprite", keyvalues, true );
				spr.pev.movetype = MOVETYPE_FOLLOW;
				@spr.pev.aiment = shootEnt.edict();
				spr.pev.skin = shootEnt.entindex();
				spr.pev.body = 0; // attachement point
				sprHandle = @spr;
			}
			
			WeaponCustomProjectile@ shootEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(shootEnt));
			if (shootEnt_c !is null)
				shootEnt_c.spriteAttachment = sprHandle;
			
			// attach a trail
			if (options.trail_spr.Length() > 0)
			{
				NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
					message.WriteByte(TE_BEAMFOLLOW);
					message.WriteShort(shootEnt.entindex());
					message.WriteShort(options.trail_sprId);
					message.WriteByte(options.trail_life);
					message.WriteByte(options.trail_width);
					message.WriteByte(options.trail_color.r);
					message.WriteByte(options.trail_color.g);
					message.WriteByte(options.trail_color.b);
					message.WriteByte(options.trail_color.a);
				message.End();
			}
			
			if (options.life > 0)
				g_Scheduler.SetTimeout("killProjectile", options.life, mdlHandle, sprHandle, active_opts);
				
			if (settings.max_live_projectiles > 0)
			{
				liveProjectiles++;
				MonitorProjectileLife(mdlHandle);
			}
		}
		
		// remove weapon from player if they threw it
		if (options.type == PROJECTILE_WEAPON)
			g_Scheduler.SetTimeout( "removeWeapon", 0, @self );
		
		return shootEnt;
	}
	
	void MonitorProjectileLife(EHandle h_proj)
	{
		bool dead = false;
		if (!h_proj)
			dead = true;
			
		CBaseEntity@ proj = h_proj;
		if (proj is null)
			dead = true;
		
		if (dead)
			liveProjectiles--;
		else
			g_Scheduler.SetTimeout(@this, "MonitorProjectileLife", 0.1, h_proj);
	}
	
	// Returns false if attack should be aborted (medkit logic)
	bool AttackMonster(Vector vecSrc, TraceResult tr)
	{
		CBaseEntity@ ent = g_EntityFuncs.Instance( tr.pHit );
		if (ent is null)
			return true;
			
		Vector attackDir = (tr.vecEndPos - vecSrc).Normalize();
			
		int dmgType = active_opts.shoot_type == SHOOT_MELEE ? DMG_CLUB : DMG_BULLET;
		dmgType = active_opts.damageType(dmgType);
			
		// damage done before hitgroup multipliers
		float attackDamage = active_opts.damage*windupMultiplier*partialAmmoModifier;
		float baseDamage = applyDamageModifiers(attackDamage, ent, self.m_pPlayer, active_opts);
		
		if (baseDamage < 0)
		{	
			// avoid TraceAttack so scis don't think we're shooting at them
			float healPoints = -heal(ent, active_opts, -baseDamage);
			if (healPoints == 0 and active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0)
				return false;

			if (active_opts.pev.spawnflags & FL_SHOOT_PARTIAL_AMMO_SHOOT != 0)
			{
				// don't use all ammo if we were only able to heal a small amount
				if (healPoints < attackDamage and attackDamage > 0)
				{
					float ammoScale = healPoints / attackDamage;
					partialAmmoUsage = int(ammoScale * active_opts.ammo_cost);
				}
			}	
		}
		else
		{
			if (active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0)
				return false;

			g_WeaponFuncs.ClearMultiDamage(); // fixes TraceAttack() crash for some reason
			
			ent.TraceAttack(self.m_pPlayer.pev, baseDamage, attackDir, tr, dmgType);
			g_WeaponFuncs.ApplyMultiDamage(ent.pev, self.m_pPlayer.pev);
		}
		
		knockBack(ent, attackDir * active_opts.knockback);
		
		return true;
	}
	
	void ShootBeam()
	{
		if (beam_active)
			return;
		
		BeamOptions@ beam_opts = active_opts.beams[0];
		
		for (uint i = 0; i < beams.size(); i++)
			beams[i].resize(active_opts.beam_ricochet_limit+1);
		beamHits.resize(active_opts.beam_ricochet_limit+1);
		
		beam_active = true;
		first_beam_shoot = true;
		beamStartTime = g_Engine.time;
		minBeamTime = Math.max(active_opts.beams[0].time, active_opts.beams[1].time);
		self.pev.nextthink = g_Engine.time;
		
		// constant beam sounds
		hookAnimStarted = false;
		hookAnimStartTime = g_Engine.time + active_opts.hook_delay;
	}
	
	// Calculate beam ricochets
	array<BeamShot> CalcBeamShots()
	{
		array<BeamShot> shots;
					
		Math.MakeVectors( self.m_pPlayer.pev.v_angle );
		//Vector vecAiming = spreadDir(g_Engine.v_forward, active_opts.bullet_spread, active_opts.bullet_spread_func);
			
		Vector vecSrc = self.m_pPlayer.GetGunPosition();
		Vector vecEnd = vecSrc + g_Engine.v_forward*active_opts.max_range;

		edict_t@ traceEnt = self.m_pPlayer.edict();
		
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{			
			TraceResult tr;
			edict_t@ ignoreEnt = i == 0 ? self.m_pPlayer.edict() : self.edict();
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, ignoreEnt, tr );
			CBaseEntity@ ent = g_EntityFuncs.Instance( tr.pHit );
			
			BeamShot shot;
			shot.startPos = vecSrc;
			shot.tr = tr;
			@shot.ent = @ent;
			shots.insertLast(shot);
			
			if (tr.flFraction < 1.0 and tr.pHit !is null)
			{
				Vector dir = (vecEnd - vecSrc).Normalize();
				
				if (ent !is null and !ent.IsBSPModel())	
					break; // don't ricochet off monsters
				
				// Calculate reflection vector
				Vector n = tr.vecPlaneNormal;
				float dotdir = DotProduct(dir, n);
				float ricAngle = -dotdir * 90;
				if (ricAngle > active_opts.rico_angle)
					break;
				Vector r = (dir - 2*(dotdir)*n);
				
				// set up trace points for next iteration
				vecSrc = tr.vecEndPos;
				vecEnd = vecSrc + r*active_opts.max_range;
			}
			else
				break;
		}
		
		return shots;
	}
		
	// calculates beams, end sprite locations, and damage
	void UpdateBeams()
	{			
		bool doDamage = lastBeamDamage + active_opts.beam_impact_speed < g_Engine.time;
		if (doDamage)
			lastBeamDamage = g_Engine.time;
		
		int MAX_BEAMS = 2;
		
		array<BeamShot> beamShots = CalcBeamShots();
		
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{
			// create or update a beam
			if (i < int(beamShots.length()))
			{
				BeamShot@ shot = @beamShots[i];
				
				// impact damages and effects
				if (shot.tr.flFraction < 1.0)
				{				
					if (shot.ent !is null)
					{
						if (doDamage)
							AttackMonster(shot.startPos, shot.tr);	
					}
									
					EHandle h_plr = self.m_pPlayer;
					EHandle h_ent = shot.ent;
					if (minBeamTime > 0 or doDamage)
					{
						DecalTarget dt = getProjectileDecalTarget(null, shot.tr.vecEndPos, 32);
						weapon_custom_effect@ ef;
						@ef = i == int(beamShots.length()-1) ? @active_opts.effect1 : @active_opts.effect2;
						custom_effect(shot.tr.vecEndPos, ef, null, h_ent, h_plr, dt);
					}
				}
				
				// create or update beam ents
				for (int k = 0; k < MAX_BEAMS; k++)
				{
					BeamOptions@ beam_opts = active_opts.beams[k];
		
					if (beam_opts.type == BEAM_DISABLED)
						continue;
					
					CBeam@ ricobeam;
					
					// create beam for current slot, if needed
					if (!beams[k][i])
					{
						@ricobeam = g_EntityFuncs.CreateBeam( beam_opts.sprite, 16 );
						int flags = 0;
						if (beam_opts.type == BEAM_SPIRAL or beam_opts.type == BEAM_SPIRAL_OPAQUE)
							flags |= BEAM_FSINE;
						if (beam_opts.type == BEAM_LINEAR_OPAQUE or beam_opts.type == BEAM_SPIRAL_OPAQUE)
							flags |= BEAM_FSOLID;
						ricobeam.SetFlags( flags );
						
						// First beam is attached to player weapon bone
						if (i == 0)
						{
							ricobeam.SetType(BEAM_ENTPOINT);
							ricobeam.SetEndEntity(self.m_pPlayer);
							ricobeam.SetEndAttachment(1);
						}
						
						ricobeam.SetNoise(beam_opts.noise);
						ricobeam.SetWidth(beam_opts.width);
						ricobeam.SetColor(beam_opts.color.r, beam_opts.color.g, beam_opts.color.b);
						ricobeam.SetBrightness(beam_opts.color.a);
						ricobeam.SetScrollRate(beam_opts.scrollRate);
						
						beams[k][i] = ricobeam;
					}
					
					CBaseEntity@ ricobeamEnt = beams[k][i];
					@ricobeam = cast<CBeam@>(@ricobeamEnt);
					
					// Update position of beam
					if (i == 0)
						ricobeam.SetStartPos(shot.tr.vecEndPos);
					else
						ricobeam.PointsInit(shot.tr.vecEndPos, shot.startPos);
				}
				
				// create or update impact sprites
				if (active_opts.beam_impact_spr.Length() > 0)
				{
					bool shouldImpact = shot.ent !is null;
					shouldImpact = shouldImpact ;
					
					if (shot.ent !is null and (shot.ent.IsMonster() or isBreakableEntity(shot.ent)))
					{
						// kill sprite if it's currently expanding
						CBaseEntity@ beamEnt = beamHits[i];
						if (beamHits[i] and beamEnt.pev.deadflag != 0)
							g_EntityFuncs.Remove( beamHits[i] );
						
						CSprite@ impact;
						if (!beamHits[i])
						{
							@impact = g_EntityFuncs.CreateSprite( active_opts.beam_impact_spr, 
																	   shot.tr.vecEndPos, true, 10 );
							impact.pev.rendermode = kRenderGlow;
							impact.pev.renderamt = active_opts.beam_impact_spr_opacity;
							impact.pev.scale = active_opts.beam_impact_spr_scale;
							impact.pev.framerate = 0;
							impact.pev.renderfx = kRenderFxNoDissipation;
							impact.pev.movetype = MOVETYPE_NONE;
							beamHits[i] = impact;
						}
						@beamEnt = beamHits[i];
						@impact = cast<CSprite@>(@beamEnt);
						
						impact.pev.origin = shot.tr.vecEndPos;
						
						// manual frame increments since framerate is broken (stutter if not multiple of 5)
						impact.pev.frame += active_opts.beam_impact_spr_fps*g_Engine.frametime;
						impact.pev.frame = impact.pev.frame % impact.Frames();
					}
					else if (beamHits[i])
						g_EntityFuncs.Remove( beamHits[i] );
				}
			}
			else 
			{
				// destroy beams that are no longer active
				for (int k = 0; k < MAX_BEAMS; k++)
				{
					if (beams[k][i])
						g_EntityFuncs.Remove( beams[k][i] );
				}
				// destroy the impact sprites too
				if (beamHits[i])
					g_EntityFuncs.Remove( beamHits[i] );
			}
			
		}
	}
	
	void DestroyBeams()
	{
		if (!beam_active)
			return;
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{
			for (uint k = 0; k < beams.length(); k++)
			{
				if (beams[k][i])
					g_EntityFuncs.Remove( beams[k][i] );
			}
			if (beamHits[i])
			{
				CBaseEntity@ beamEnt = beamHits[i];
				CSprite@ beam = cast<CSprite@>(@beamEnt);
			
				beam.Expand(16.0f, 512.0f); // autokills the sprite when renderamt <= 0
				beam.pev.deadflag = 1; // indicate that this sprite should be dead soon
				
			}
		}
	}
		
	void DestroyBeam(int beamId)
	{
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
			if (beams[beamId][i])
				g_EntityFuncs.Remove( beams[beamId][i] );
	}
	
	void CancelBeam()
	{
		DestroyBeams();
		beam_active = false;
		
		if (minBeamTime == 0)
		{
			if (lastShootSnd !is null)
				lastShootSnd.stop(self.m_pPlayer, CHAN_WEAPON);
			active_opts.hook_snd.stop(self.m_pPlayer, CHAN_WEAPON);
			active_opts.hook_snd2.play(self.m_pPlayer, CHAN_WEAPON);
			self.SendWeaponAnim( settings.getRandomIdleAnim() );
			//self.SendWeaponAnim( active_opts.hook_anim2, 0, 0 );
			//self.m_flTimeWeaponIdle = g_Engine.time + active_opts.hook_delay2; // idle after this	
		}	
	}
	
	void DetonateSatchels()
	{
		if (active_opts.pev.spawnflags & FL_SHOOT_DETONATE_SATCHELS == 0)
			return;
		g_EntityFuncs.UseSatchelCharges(self.m_pPlayer.pev, SATCHEL_DETONATE);
	}
	
	void ShootHook()
	{
		if (!shootingHook)
		{
			shootingHook = true;
			windupHeld = true;
			hookAnimStarted = false;
			hookAnimStartTime = g_Engine.time + active_opts.hook_delay;
			
			hook_ent = ShootProjectile();
			
			CBeam@ beam;
			if (!hook_beam)
			{
				BeamOptions@ beam_opts = active_opts.beams[0];
				@beam = g_EntityFuncs.CreateBeam( beam_opts.sprite, 16 );
				beam.SetType(BEAM_ENTS);
				beam.SetEndEntity(self.m_pPlayer);
				beam.SetEndAttachment(1);
				beam.SetStartEntity(hook_ent);
				int flags = 0;
				if (beam_opts.type == BEAM_SPIRAL or beam_opts.type == BEAM_SPIRAL_OPAQUE)
					flags |= BEAM_FSINE;
				if (beam_opts.type == BEAM_LINEAR_OPAQUE or beam_opts.type == BEAM_SPIRAL_OPAQUE)
					flags |= BEAM_FSOLID;
				beam.SetFlags( flags );
				beam.SetNoise(beam_opts.noise);
				beam.SetWidth(beam_opts.width);
				beam.SetColor(beam_opts.color.r, beam_opts.color.g, beam_opts.color.b);
				beam.SetBrightness(beam_opts.color.a);
				beam.SetScrollRate(beam_opts.scrollRate);
				hook_beam = beam;
			}
			
			CBaseEntity@ beamEnt = hook_beam;
			@beam = cast<CBeam@>(@beamEnt);
			
			self.pev.nextthink = g_Engine.time;
		}
	}
	
	float WindupEase(float p, float q, int func, bool inverse)
	{
		if (inverse)
		{
			// easing functions are reveresed for smooth transitions in the middle of a windup
			p = 1.0f - p;
			q = 1.0f - q;
		}
		switch(func)
		{
			case EASE_IN:          p = p*p;                     break;
			case EASE_OUT:         p = 1.0f - q*q;              break;
			case EASE_INOUT:       p = p*p / (p*p + q*q);       break;
			case EASE_IN_HEAVY:    p = p*p*p;                   break;
			case EASE_OUT_HEAVY:   p = 1.0f - q*q*q;            break;
			case EASE_INOUT_HEAVY: p = p*p*p / (p*p*p + q*q*q); break;
		}
		return p;
	}
	
	void WindupThink()
	{
		float timePassed = g_Engine.time - windupStart;
		bool shouldWindDown = active_opts.wind_down_time > 0;
		bool responsiveWindup = active_opts.pev.spawnflags & FL_SHOOT_RESPONSIVE_WINDUP != 0; 
		bool minWindupDone = timePassed >= active_opts.windup_min_time;
		
		if (!windupHeld and (responsiveWindup and minWindupDone or windupFinished) or 
			(windingDown and !responsiveWindup))
		{		
			if (shouldWindDown)
			{
				float p = Math.min(1.0f, timePassed / active_opts.wind_down_time); // progress
				float q = 1.0f - p; // inverse progress
				if (!windingDown)
				{
					windingDown = true;
					float ip = 1.0f - Math.min(1.0f, timePassed / active_opts.windup_time);
					windupStart = g_Engine.time - ip*active_opts.wind_down_time;
					self.SendWeaponAnim( active_opts.wind_down_anim, 0, 0 );
				}
				else // winding down
				{
					if (timePassed >= active_opts.wind_down_time)
					{
						// wind down finished
						windingUp = false;
						windupLoopEntered = false;
						windupSoundActive = false;
						windingDown = false;
						windupFinished = false;
						windupAmmoUsed = 0;
						active_opts.windup_snd.stop(self.m_pPlayer, CHAN_VOICE);
					}
					else
					{
						p = WindupEase(p, q, active_opts.windup_easing, true);
						float delta = active_opts.windup_pitch_end - active_opts.windup_pitch_start;
						int newPitch = active_opts.windup_pitch_start + int(delta*p + 0.5f);
						//println("T : " + newPitch);
						
						if (active_opts.windup_snd.file.Length() > 0)
							g_SoundSystem.EmitSoundDyn( self.m_pPlayer.edict(), CHAN_VOICE, active_opts.windup_snd.file, 
														1.0, ATTN_NORM, SND_CHANGE_PITCH, newPitch);
					}
					
				}
			} 
			else // fire a bullet at the current windup and stop
			{
				windingUp = false;
				windupLoopEntered = false;
				windupSoundActive = false;
				windingDown = false;
				windupFinished = false;
				
				active_opts.windup_snd.stop(self.m_pPlayer, CHAN_VOICE);
				
				if (active_opts.windup_action != WINDUP_SHOOT_ONCE_IF_HELD or windupHeld)
					if (AllowedToShoot(active_opts))
						DoAttack(true);
			}
		}
		else
		{
			if (settings.player_anims == ANIM_REF_CROWBAR)
			{
				bool correctAnim = self.m_pPlayer.pev.sequence == 26 or self.m_pPlayer.pev.sequence == 25;
				bool longJumping = self.m_pPlayer.m_Activity == ACT_LEAP;
				if (self.m_pPlayer.m_fSequenceFinished or (!correctAnim and !longJumping)) 
				{
					// Manually set wrench windup loop animation
					self.m_pPlayer.m_Activity = ACT_RELOAD;
					self.m_pPlayer.pev.frame = 0;
					self.m_pPlayer.pev.sequence = 26;
					self.m_pPlayer.ResetSequenceInfo();
				}
			}
			
			// switch to looped windup animation when the time is right
			if (!windupLoopEntered)
			{
				if (windupStart + active_opts.windup_anim_time < g_Engine.time)
				{
					if (active_opts.windup_anim_loop != -1)
						self.SendWeaponAnim( active_opts.windup_anim_loop, 0, 0 );
					windupLoopEntered = true;
				}
			}
			
			if (!windupOvercharged and active_opts.windup_overcharge_time > 0)
			{
				if (windupStart + active_opts.windup_overcharge_time < g_Engine.time)
				{
					windupOvercharged = true;
					
					custom_user_effect(self.m_pPlayer, active_opts.user_effect2);
					
					if (active_opts.windup_overcharge_anim >= 0)
						self.SendWeaponAnim( active_opts.windup_overcharge_anim, 0, 0 );	
					
					if (active_opts.windup_overcharge_action != OVERCHARGE_CONTINUE)
					{
						windingUp = false;
						windupLoopEntered = false;
						windupSoundActive = false;
						windingDown = false;
						windupFinished = false;
						windupHeld = false;
						
						if (active_opts.windup_overcharge_action == OVERCHARGE_SHOOT)
							if (AllowedToShoot(active_opts))
								DoAttack(true);
						
						if (active_opts.windup_overcharge_anim <= 0)
							self.SendWeaponAnim( settings.getRandomIdleAnim() );
						
						Cooldown(active_opts);
						active_opts.windup_snd.stop(self.m_pPlayer, CHAN_VOICE);
						
						return;
					}
				}
			}
			
			float p = Math.min(1.0f, timePassed / active_opts.windup_time); // progress
			float q = 1.0f - p; // inverse progress
			bool playWindupDuringShoot = true;
			
			if (windingDown)
			{
				windingDown = false;
				float ip = 1.0f - Math.min(1.0f, timePassed / active_opts.wind_down_time);
				windupStart = g_Engine.time - ip*active_opts.windup_time;
			}
			else if (!windupSoundActive)
			{
				self.SendWeaponAnim( active_opts.windup_anim, 0, 0 );
				
				active_opts.windup_snd.play(self.m_pPlayer, CHAN_VOICE, 1.0f, active_opts.windup_pitch_start);											
				windupSoundActive = true;
			}
			else if (timePassed < active_opts.windup_time)
			{
				p = WindupEase(p, q, active_opts.windup_easing, false);
				
				windupMultiplier = 1.0f + p*(active_opts.windup_mult-1.0f);
				windupKickbackMultiplier = 1.0f + p*(active_opts.windup_kick_mult-1.0f);
				float delta = active_opts.windup_pitch_end - active_opts.windup_pitch_start;
				debugln("Windup Damage Multiplier: " + windupMultiplier);
				int newPitch = active_opts.windup_pitch_start + int(delta*p + 0.5f);
				//println("T : " + newPitch);
				
				if (newPitch != active_opts.windup_pitch_start)
					active_opts.windup_snd.play(self.m_pPlayer, CHAN_VOICE, 1.0f, newPitch, SND_CHANGE_PITCH);
				
				int ammoUsedNow = int(p*active_opts.windup_cost + 0.5f);
				DepleteAmmo(Math.max(0, ammoUsedNow - windupAmmoUsed));
				windupAmmoUsed = Math.max(windupAmmoUsed, ammoUsedNow);
			}
			else if (timePassed > active_opts.windup_time)
			{		
				windupMultiplier = active_opts.windup_mult;
				windupKickbackMultiplier = active_opts.windup_kick_mult;
				if (!windupFinished)
					debugln("Windup Damage Multiplier: " + windupMultiplier);
				windupFinished = true;
				
				bool onceHeld = active_opts.windup_action == WINDUP_SHOOT_ONCE_IF_HELD and windupHeld;
				if (active_opts.windup_action == WINDUP_SHOOT_ONCE or onceHeld)
				{
					windingUp = false;
					windupSoundActive = false;
					if (active_opts.windup_snd.file.Length() > 0)
						g_SoundSystem.StopSound( self.m_pPlayer.edict(), CHAN_VOICE, active_opts.windup_snd.file);
					if (AllowedToShoot(active_opts))
						DoAttack(true);
						
				}
				if (active_opts.windup_action == WINDUP_SHOOT_CONSTANT)
				{
					if (AllowedToShoot(active_opts) and windupHeld)
					{
						if (cooldownFinished())
						{
							DoAttack(true);
						}
					}
					else
					{
						if (!shouldWindDown)
						{
							windingUp = false;
							windupLoopEntered = false;
							windupFinished = false;
							windupSoundActive = true;
							windupAmmoUsed = 0;
							windupMultiplier = 1.0f;
							windupKickbackMultiplier = 1.0f;
						}
					}
				}
			}
			
			windupHeld = false;
		}
	}
	
	void WeaponThink()
	{	
		if (self.m_pPlayer is null)
			return;
			
		if (laser_spr)
		{
			CBaseEntity@ ent = laser_spr;
			if (unhideLaserTime > g_Engine.time)
			{
				// temporarily hide the laser
				ent.pev.effects |= EF_NODRAW;
			}
			else
			{
				if (ent.pev.effects & EF_NODRAW != 0)
					ent.pev.effects &= ~EF_NODRAW;
				
				Vector vecSrc	 = self.m_pPlayer.GetGunPosition();
				Math.MakeVectors( self.m_pPlayer.pev.v_angle );
				
				TraceResult tr;
				Vector vecEnd = vecSrc + g_Engine.v_forward * 65536;
				g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, self.m_pPlayer.edict(), tr );
				
				ent.pev.origin = tr.vecEndPos;
			}
		}
		
		if (needShellEject and ejectShellTime < g_Engine.time)
		{
			EjectShell();
			needShellEject = false;
		}
		
		if (reloading > 0)
		{
			if (nextReload < g_Engine.time)
			{
				if (reloading == 2)
				{
					self.SendWeaponAnim( settings.reload_end_anim );
					settings.reload_end_snd.play(self.m_pPlayer, CHAN_VOICE);
					nextShootTime = g_Engine.time + settings.reload_end_time;
					self.m_flTimeWeaponIdle = nextShootTime + 1; // I can't bear adding another keyvalue for this delay
					reloading = 0;
				}
				else
				{
					if (reloading == 1 and ReloadContinuous())
						reloading = 2;

					BaseClass.Reload();
					self.SendWeaponAnim( settings.reload_anim );
					settings.reload_snd.play(self.m_pPlayer, CHAN_VOICE);
					nextReload = g_Engine.time + settings.reload_time;
					nextShootTime = nextReload;
				}
				
			}
		}
			
		if (beam_active)
		{
			if (windupHeld and minBeamTime == 0 or first_beam_shoot) 
			{
				UpdateBeams();	
				first_beam_shoot = false;

				// hook anim vars shared with constant beam (basically the same thing)
				if (minBeamTime == 0 and !hookAnimStarted and hookAnimStartTime <= g_Engine.time)
				{
					hookAnimStarted = true;
					active_opts.hook_snd.play(self.m_pPlayer, CHAN_WEAPON);
					self.SendWeaponAnim( active_opts.hook_anim, 0, 0 );
				}				
			}
			else if (beamStartTime + minBeamTime > g_Engine.time)
			{
				// kill beams with durations less than the total beam duration
				for (uint k = 0; k < active_opts.beams.length(); k++)
				{
					if (!beams[k][0])
						continue;
					BeamOptions@ beam_opts = active_opts.beams[k];
					if (beam_opts.time > 0 and beamStartTime + beam_opts.time < g_Engine.time)
						DestroyBeam(k);
				}
			}
			else
			{
				CancelBeam();			
			}
			
		}
		else if (burstFiring)
		{
			if (!AllowedToShoot(active_opts))
				burstFiring = false;
			else if (g_Engine.time > nextBurstFire)
			{
				ShootOneBullet();
				numBurstFires += 1;
				nextBurstFire = g_Engine.time + active_opts.bullet_delay;
				AttackEffects();
				if (numBurstFires >= active_opts.bullets)
					burstFiring = false;
			}
		}
		else if (windingUp)
		{
			WindupThink();
		}
		else if (shootingHook)
		{
			if (windupHeld and hook_ent)
			{
				if (!hookAnimStarted and hookAnimStartTime <= g_Engine.time)
				{
					hookAnimStarted = true;
					active_opts.hook_snd.play(self.m_pPlayer, CHAN_WEAPON);
					self.SendWeaponAnim( active_opts.hook_anim, 0, 0 );
				}
			}
			else
			{
				shootingHook = false;
				if (hook_ent)
				{
					CBaseEntity@ hookEnt = hook_ent;
					WeaponCustomProjectile@ hookEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(hookEnt));
					hookEnt_c.uninstall_steam_and_kill_yourself();
				}
				
				active_opts.hook_snd.stop(self.m_pPlayer, CHAN_WEAPON);
				active_opts.hook_snd2.play(self.m_pPlayer, CHAN_WEAPON);
				self.SendWeaponAnim( active_opts.hook_anim2, 0, 0 );
				self.m_flTimeWeaponIdle = g_Engine.time + active_opts.hook_delay2; // idle after this
				
				if (hook_beam)
					g_EntityFuncs.Remove( hook_beam );
				hook_beam = null;
			}
			windupHeld = false;
		}
		else if (!canShootAgain)
		{
			// wait for user to stop holding trigger
			if (self.m_pPlayer.pev.button & 1 == 0) {
				canShootAgain = true;
			}	
		}
		else if (!laser_spr and !needShellEject and reloading == 0)
			return;
		self.pev.nextthink = g_Engine.time;
	}
	
	bool cooldownFinished()
	{
		float nextAttack;
		if (windingUp) nextAttack = nextWindupShoot;
		else if (active_fire == 0) nextAttack = self.m_flNextPrimaryAttack;
		else if (active_fire == 1) nextAttack = self.m_flNextSecondaryAttack;
		else if (active_fire == 2) nextAttack = self.m_flNextTertiaryAttack;
		nextAttack = nextShootTime; // TODO: Remove above code
		return nextAttack <= g_Engine.time;
	}
	
	void Cooldown(weapon_custom_shoot@ opts)
	{
		// cooldown
		if (windingUp) 
		{
			// no cooldown during windups or else we don't know if the button is still pressed
			nextWindupShoot = WeaponTimeBase() + opts.cooldown;
		}
		else
		{
			float cooldownVal = opts.cooldown;
			if (opts.shoot_type == SHOOT_MELEE and (!meleeHit or abortAttack))
				cooldownVal = opts.melee_miss_cooldown;
			if (windupOvercharged)
				cooldownVal = opts.windup_overcharge_cooldown;
			//self.m_flNextPrimaryAttack = WeaponTimeBase() + cooldownVal;
			//self.m_flNextSecondaryAttack = WeaponTimeBase() + cooldownVal;
			//self.m_flNextTertiaryAttack = WeaponTimeBase() + cooldownVal;
			nextShootTime = WeaponTimeBase() + cooldownVal;
		}
	}
	
	bool FailAttack(weapon_custom_shoot@ opts)
	{
		if (!abortAttack)
			return false;

		WeaponSound@ snd = opts.getRandomShootFailSound();
		if (snd !is null)
			snd.play(self.m_pPlayer, CHAN_WEAPON);
			
		Cooldown(opts);
		return true;
	}
	
	void EjectShell()
	{
		if (active_opts.shell_delay > 0)
			active_opts.shell_delay_snd.play(self.m_pPlayer, CHAN_ITEM);
			
		Math.MakeVectors( self.m_pPlayer.pev.v_angle );
							  
		Vector ofs = active_opts.shell_offset;
		Vector vel = active_opts.shell_vel;
		ofs = ofs.x*g_Engine.v_right + ofs.y*g_Engine.v_up + ofs.z*g_Engine.v_forward;
		vel = vel.x*g_Engine.v_right + vel.y*g_Engine.v_up + vel.z*g_Engine.v_forward;
		float speed = vel.Length();
		float spread = active_opts.shell_spread;
		vel = resizeVector(spreadDir(vel, spread), speed + Math.RandomFloat(-spread, spread));
		
		Vector shellOri = self.m_pPlayer.GetGunPosition() + ofs;
		Vector shellVel = self.m_pPlayer.pev.velocity + vel;
		float shellRot = 1000; // has no effect... broken paramater?
		TE_BOUNCE bounceSnd = active_opts.shell_type == SHELL_SHOTGUN ? TE_BOUNCE_SHOTSHELL : TE_BOUNCE_SHELL;
		
		g_EntityFuncs.EjectBrass(shellOri, shellVel, shellRot, active_opts.shell_idx, bounceSnd);
		if (debug_mode)
			te_beampoints(shellOri, shellOri + resizeVector(shellVel, 32));
	}
	
	// do everything except actually shooting something
	void AttackEffects(bool windupAttack=false)
	{
		if (FailAttack(active_opts))
			return;
		
		// kickback
		Math.MakeVectors( self.m_pPlayer.pev.v_angle );
		
		Vector kickVel = g_Engine.v_forward * -active_opts.kickback*windupKickbackMultiplier;
		self.m_pPlayer.pev.velocity = self.m_pPlayer.pev.velocity + kickVel;
		
		int ammo_cost = partialAmmoUsage != -1 ? partialAmmoUsage : active_opts.ammo_cost;
		DepleteAmmo(ammo_cost);
		
		if (active_opts.pev.spawnflags & FL_SHOOT_QUAKE_MUZZLEFLASH != 0)
			self.m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		
		bool constantBeamStarted = minBeamTime == 0 and first_beam_shoot;
		bool shouldPlayAttackAnim = active_opts.shoot_type != SHOOT_BEAM or constantBeamStarted;
		
		// play random first-person weapon animation
		if ((!hookAnimStarted or meleeHit) and shouldPlayAttackAnim)
		{
			int anim = meleeHit ? getRandomMeleeAnim() : active_opts.shoot_empty_anim;
			if (!meleeHit and (!EmptyShoot() or anim < 0))
				anim = getRandomShootAnim();
			self.SendWeaponAnim( anim, 0, 0 );
		}

		// thirperson animation
		if (windupAttack and settings.player_anims == ANIM_REF_CROWBAR)
		{
			// Manually set wrench windup attack animation
			self.m_pPlayer.m_Activity = ACT_RELOAD;
			self.m_pPlayer.pev.frame = 0;
			self.m_pPlayer.pev.sequence = 27;
			self.m_pPlayer.ResetSequenceInfo();
			//self.m_pPlayer.pev.framerate = 0.5f;
		}
		else if (shouldPlayAttackAnim)
			self.m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		
		// recoil
		self.m_pPlayer.pev.punchangle.x = -Math.RandomFloat(active_opts.recoil.x, active_opts.recoil.y);
		self.m_pPlayer.pev.punchangle.y = 0;//Math.RandomLong(-180, 180);
		self.m_pPlayer.pev.punchangle.z = 0;//Math.RandomLong(-180, 180);
		//self.m_pPlayer.pev.punchangle.y = 0;
		
		// idle random time after shooting
		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( self.m_pPlayer.random_seed,  10, 15 );
		
		// random shoot sound
		shootCount++;
		bool meleeSkip = active_opts.shoot_type == SHOOT_MELEE;
		bool noSndOverlap = active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP != 0;
		bool constantBeaming = beam_active and minBeamTime == 0 and !first_beam_shoot;
		meleeSkip = meleeSkip and noSndOverlap;
		if (!meleeSkip and !shootingHook and !constantBeaming)
		{
			WeaponSound@ snd = active_opts.getRandomShootSound();
			if (EmptyShoot() and active_opts.shoot_empty_snd.file.Length() > 0)
				@snd = @active_opts.shoot_empty_snd;
			SOUND_CHANNEL channel = shootCount % 2 == 0 or noSndOverlap ? CHAN_WEAPON : CHAN_VOICE;
			if (active_opts.shoot_type == SHOOT_MELEE)
				channel = CHAN_WEAPON;
			if (snd !is null)
				snd.play(self.m_pPlayer, channel);
			@lastShootSnd = @snd;
		}
		
		// monster reactions to shooting or danger
		int hmode = active_opts.heal_mode;
		bool harmlessWep = hmode == HEAL_ALL or active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0;
		if (!healedTarget and !harmlessWep)
		{
			// get spooked
			self.m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;
			self.m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
			self.m_pPlayer.m_iExtraSoundTypes = bits_SOUND_COMBAT;//bits_SOUND_DANGER;
			self.m_pPlayer.m_flStopExtraSoundTime = WeaponTimeBase() + 0.2;
		}
		
		// eject shell
		if (active_opts.shell_type != SHELL_NONE)
		{
			if (active_opts.shell_delay == 0)
				EjectShell();
			else
			{
				needShellEject = true;
				ejectShellTime = WeaponTimeBase() + active_opts.shell_delay;
				self.pev.nextthink = g_Engine.time;
			}
		}
		
		// muzzle flash
		int flash_size = int(active_opts.muzzle_flash_adv.x);
		int flash_life = int(active_opts.muzzle_flash_adv.y);
		int flash_decay = int(active_opts.muzzle_flash_adv.z);
		Color flash_color = Color(active_opts.muzzle_flash_color);
		bool isBlack = flash_color.r == 0 and flash_color.g == 0 and flash_color.b == 0;
		if (flash_life > 0 and flash_size > 0 and !isBlack)
		{
			Vector lpos = self.m_pPlayer.pev.origin + g_Engine.v_forward * 50;
			te_dlight(lpos, flash_size, flash_color, flash_life, flash_decay);
		}
		
		custom_user_effect(@self.m_pPlayer, @active_opts.user_effect1);
		
		if (noSndOverlap)
		{
			if (lastCooldownSnd !is null)
				lastCooldownSnd.stop(self.m_pPlayer, CHAN_VOICE);
		}
		nextCooldownSound = g_Engine.time + active_opts.cooldown_sound_delay;
		
		Cooldown(active_opts);
	}
		
	void DoAttack(bool windupAttack=false)
	{	
		reloading = 0;
		healedTarget = false;
		abortAttack = false;
		partialAmmoUsage = -1;
		
		if (!windupAttack)
		{
			windupMultiplier = 1.0f;
			partialAmmoModifier = 1.0f;
		}
		if (active_opts.pev.spawnflags & FL_SHOOT_PARTIAL_AMMO_SHOOT != 0)
		{
			if (settings.clip_size() > 0)
				partialAmmoModifier = float(self.m_iClip) / float(active_opts.ammo_cost);
			else
				partialAmmoModifier = AmmoLeft(active_ammo_type) / float(active_opts.ammo_cost);
			partialAmmoModifier = Math.min(1.0f, partialAmmoModifier);
		}
		
		// shoot stuff
		switch(active_opts.shoot_type)
		{
			case SHOOT_MELEE:
			case SHOOT_BULLETS: ShootBullets(); break;
			case SHOOT_PROJECTILE: ShootProjectile(); break;
			case SHOOT_BEAM: ShootBeam(); break;
		}
		if (active_opts.hook_type != HOOK_DISABLED)
			ShootHook();
		DetonateSatchels();
		
		AttackEffects(windupAttack);
	}
	
	// special logic for stopping revive windup if no revive target in range
	bool PreventReviveStart(weapon_custom_shoot@ opts)
	{	
		bool reviveOnly = opts.heal_mode >= HEAL_REVIVE_FRIENDS;
		
		if (!reviveOnly or opts.shoot_type == SHOOT_PROJECTILE)
			return false;
		
		Vector vecSrc	 = self.m_pPlayer.GetGunPosition();
		
		Math.MakeVectors( self.m_pPlayer.pev.v_angle );
		
		Vector vecAiming = spreadDir(g_Engine.v_forward, opts.bullet_spread, opts.bullet_spread_func);
		
		// Do the bullet collision
		TraceResult tr;
		Vector vecEnd = vecSrc + vecAiming * opts.max_range;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, self.m_pPlayer.edict(), tr );
		//te_beampoints(vecSrc, vecEnd);
		
		if ( tr.flFraction >= 1.0 and opts.shoot_type == SHOOT_MELEE)
		{
			// This does a trace in the form of a box so there is a much higher chance of hitting something
			// From crowbar.cpp in the hlsdk:
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, self.m_pPlayer.edict(), tr );
			if ( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null or pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, self.m_pPlayer.edict() );
				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}
		
		bool revivedSomething = false;
		
		if (reviveOnly)
		{
			CBaseEntity@ revTarget = getReviveTarget(tr.vecEndPos, REVIVE_RADIUS, self.m_pPlayer, opts);
			if (revTarget !is null)
			{
				// prevent the corpse from fading before windup finishes
				revTarget.BeginRevive(opts.windup_time);
				return false;
			}
		}
		return true;
	}
	
	// Returns true when finished
	bool ReloadContinuous()
	{
		if (settings.clip_size() <= 0)
			return true;
		if (AmmoLeft(active_ammo_type) < settings.reload_ammo_amt)
			return true;
		
		int reloadAmt = Math.min(settings.clip_size() - self.m_iClip, settings.reload_ammo_amt);
		self.m_iClip += reloadAmt;
		self.m_pPlayer.m_rgAmmo( active_ammo_type, Math.max(0, AmmoLeft(active_ammo_type)-reloadAmt));
		return self.m_iClip >= settings.clip_size();
	}
	
	void DepleteAmmo(int amt)
	{
		if (active_ammo_type == -1) return;
		
		bool shouldUseClip = active_opts.isPrimary() or active_ammo_type == self.m_iPrimaryAmmoType;
		if (self.m_iClip > 0 and shouldUseClip) 
			self.m_iClip -= amt;
		else // gun doesn't use a clip
			self.m_pPlayer.m_rgAmmo( active_ammo_type, Math.max(0, AmmoLeft(active_ammo_type)-amt));
			
		if( self.m_pPlayer.m_rgAmmo(active_ammo_type) <= 0 )
			// HEV suit - indicate out of ammo condition
			self.m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
	}
	
	int AmmoLeft(int ammoType)
	{
		if (ammoType == -1) return -1; // doesn't use ammo
		return Math.max(0, self.m_pPlayer.m_rgAmmo( ammoType ));
	}
	
	// returns true if a windup was started
	bool DoWindup()
	{
		if (active_opts.windup_time > 0 and !windingUp)
		{
			windingUp = true;
			windupLoopEntered = false;
			windingDown = false;
			windupFinished = false;
			windupHeld = true;
			windupSoundActive = false;
			windupOvercharged = false;
			windupMultiplier = 1.0f;
			windupKickbackMultiplier = 1.0f;
			windupStart = g_Engine.time;
			self.pev.nextthink = g_Engine.time;
			
			if (active_opts.windup_cost > 0)
			{
				windupAmmoUsed = 1;
				DepleteAmmo(1); // don't let user get away with free shots
			}
			
			if (settings.player_anims == ANIM_REF_CROWBAR)
			{
				// Manually set wrench windup animation
				self.m_pPlayer.m_Activity = ACT_RELOAD;
				self.m_pPlayer.pev.frame = 0;
				self.m_pPlayer.pev.sequence = 25;
				self.m_pPlayer.ResetSequenceInfo();
				//self.m_pPlayer.pev.framerate = 0.5f;
			}
			
			return true;
		}
		return false;
	}
	
	void ShowLaser()
	{
		if (!laser_spr)
		{
			CSprite@ dot = g_EntityFuncs.CreateSprite( settings.laser_sprite, self.m_pPlayer.pev.origin, true, 10 );
			dot.pev.rendermode = kRenderGlow;
			dot.pev.renderamt = 255;
			dot.pev.renderfx = kRenderFxNoDissipation;
			dot.pev.movetype = MOVETYPE_NONE;
			laser_spr = dot;
			self.pev.nextthink = g_Engine.time;
		} 
	}
	
	void HideLaser()
	{
		if (laser_spr)
		{
			CBaseEntity@ ent = laser_spr;
			g_EntityFuncs.Remove( ent );
		}
	}
	
	bool CanStartAttack(weapon_custom_shoot@ opts)
	{			
		if (windingUp)
		{
			windupHeld = true;
			return false;
		}
		
		if (shootingHook or beam_active)
		{
			windupHeld = true;
		}
		
		if (!cooldownFinished())
			return false;
		
		if (opts.pev.spawnflags & FL_SHOOT_NO_AUTOFIRE != 0)
		{
			if (!canShootAgain) {
				return false;
			}
			canShootAgain = false;
			self.pev.nextthink = g_Engine.time;
		}
		
		if (PreventReviveStart(opts))
		{
			abortAttack = true;
			FailAttack(opts);
			return false;
		}
		
		return AllowedToShoot(opts);
	}
	
	bool AllowedToShoot(weapon_custom_shoot@ opts)
	{
		bool canshoot = true;
		bool emptySound = false;
		
		// don't fire underwater
		if( self.m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD and !opts.can_fire_underwater())
		{
			emptySound = true;
			canshoot = false;
		}
		
		int ammoType = self.m_iPrimaryAmmoType;
		if (opts.isSecondary() or (opts.isTertiary() and opts.weapon.tertiary_ammo_type == TAMMO_SAME_AS_SECONDARY))
			ammoType = self.m_iSecondaryAmmoType;
			
		if (ammoType != -1) // ammo used at all?
		{
			bool partialAmmoShoot = (opts.pev.spawnflags & FL_SHOOT_PARTIAL_AMMO_SHOOT) != 0;
			bool shouldUseClip = opts.isPrimary() or ammoType == self.m_iPrimaryAmmoType;
			bool emptyClip = (settings.clip_size() > 0 and self.m_iClip < opts.ammo_cost);
			bool emptyAmmo = AmmoLeft(ammoType) < opts.ammo_cost;
			emptyClip = emptyClip and (!partialAmmoShoot or self.m_iClip <= 0);
			emptyAmmo = emptyAmmo and (!partialAmmoShoot or AmmoLeft(ammoType) <= 0);
			if ((emptyClip and shouldUseClip) or (!shouldUseClip and emptyAmmo))
			{
				emptySound = true;
				canshoot = false;
			}
		}
		
		if (opts.shoot_type == SHOOT_PROJECTILE and settings.max_live_projectiles > 0 and
				liveProjectiles >= settings.max_live_projectiles)
			canshoot = false;
		
		if (!canshoot)
		{
			abortAttack = true;
			if (emptySound)
				self.PlayEmptySound();
			FailAttack(opts);
		}
		
		return canshoot;
	}
	
	float GetNextAttack()
	{
		if (active_fire == 0) return self.m_flNextPrimaryAttack;
		if (active_fire == 1) return self.m_flNextSecondaryAttack;
		if (active_fire == 2) return self.m_flNextTertiaryAttack;
		return 0;
	}
	
	void SetNextAttack(float time)
	{
		if (active_fire == 0) self.m_flNextPrimaryAttack = time;
		if (active_fire == 1) self.m_flNextSecondaryAttack = time;
		if (active_fire == 2) self.m_flNextTertiaryAttack = time;
	}
	
	void CancelZoom()
	{
		self.SetFOV(0);
		self.m_fInZoom = false;
		if (settings.player_anims == ANIM_REF_BOW)
			self.m_pPlayer.set_m_szAnimExtension("bow");
	}
	
	void CommonAttack(int attackNum)
	{
		int next_fire = attackNum;
		weapon_custom_shoot@ next_opts = @settings.fire_settings[next_fire];
		weapon_custom_shoot@ alt_opts = @settings.alt_fire_settings[next_fire];
		
		int fireAct = next_fire == 1 ? settings.secondary_action : settings.tertiary_action;
		if (fireAct != FIRE_ACT_SHOOT)
		{
			if (nextActionTime > g_Engine.time)
				return;
			if (fireAct == FIRE_ACT_LASER)
			{
				if (!laser_spr)
					ShowLaser();
				else
					HideLaser();
			}
			if (fireAct == FIRE_ACT_ZOOM)
			{
				self.SetFOV(primaryAlt ? 0 : settings.zoom_fov);
				self.m_fInZoom = !self.m_fInZoom;
				if (settings.player_anims == ANIM_REF_BOW)
					self.m_pPlayer.set_m_szAnimExtension(self.m_fInZoom ? "bowscope" : "bow");
				
			}
			primaryAlt = !primaryAlt;
			
			weapon_custom_shoot@ p_opts = @settings.fire_settings[0];
			weapon_custom_shoot@ p_alt_opts = @settings.alt_fire_settings[0];
			
			weapon_custom_shoot@ next_p_opts = primaryAlt ? @p_alt_opts : @p_opts;
			next_p_opts.toggle_snd.play(self.m_pPlayer, CHAN_VOICE);
			if (next_p_opts.toggle_txt.Length() > 0)
				g_PlayerFuncs.PrintKeyBindingString(self.m_pPlayer, next_p_opts.toggle_txt);
			
			nextActionTime = WeaponTimeBase() + 0.5;
			
			return;
		}
		
		if (next_fire == 0 and primaryAlt and settings.primary_alt_fire.Length() > 0)
			@next_opts = @alt_opts;
	
		if (next_opts.pev is null or !CanStartAttack(next_opts))
			return;
			
		@active_opts = next_opts;
		active_fire = next_fire;
		active_ammo_type = -1;
		if (next_fire == 0) 
		{
			active_ammo_type = self.m_iPrimaryAmmoType;
		} 
		else if (next_fire == 1)
		{
			active_ammo_type = self.m_iSecondaryAmmoType;
		}
		else if (next_fire == 2)
		{
			if (settings.tertiary_ammo_type == TAMMO_SAME_AS_PRIMARY)
				active_ammo_type = self.m_iPrimaryAmmoType;
			if (settings.tertiary_ammo_type == TAMMO_SAME_AS_SECONDARY) 
				active_ammo_type = self.m_iSecondaryAmmoType;
		}
		
		if (DoWindup())
			return;
		
		DoAttack();
	}
	
	void PrimaryAttack()   { CommonAttack(0); }
	void SecondaryAttack() { CommonAttack(1); }
	void TertiaryAttack()  { CommonAttack(2); }
	
	bool EmptyShoot()
	{
		return (settings.clip_size() > 0 and self.m_iClip == 0) or 
				(settings.clip_size() == 0 and AmmoLeft(active_ammo_type) == 0);
	}
	
	void Reload()
	{
		if (!cooldownFinished() or reloading > 0)
			return;
			
		if (liveProjectiles > 0 and active_opts.projectile.follow_mode == FOLLOW_CROSSHAIRS)
			return; // don't reload if we're controlling a projectile
		
		if (settings.pev.spawnflags & FL_WEP_CONTINUOUS_RELOAD != 0 and 
			self.m_iClip < settings.clip_size() and AmmoLeft(active_ammo_type) >= settings.reload_ammo_amt)
		{
			self.SendWeaponAnim( settings.reload_start_anim );
			reloading = 1;
			nextReload = WeaponTimeBase() + settings.reload_start_time;
			nextShootTime = nextReload;
			self.pev.nextthink = g_Engine.time;
			settings.reload_start_snd.play(self.m_pPlayer, CHAN_VOICE);
			CancelZoom();
			return;
		}
		
		int reloadAnim = settings.reload_empty_anim;
		if (reloadAnim < 0 or !EmptyShoot())
			reloadAnim = settings.reload_anim;
			
		bool reloaded = self.DefaultReload( settings.clip_size(), reloadAnim, settings.reload_time, 0 );
		
		if (reloaded)
		{
			CancelZoom();
			settings.reload_snd.play(self.m_pPlayer, CHAN_VOICE);
			unhideLaserTime = WeaponTimeBase() + settings.reload_time;
		}
		
		//Set 3rd person reloading animation -Sniper
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		if (beam_active and beamStartTime + minBeamTime < g_Engine.time)
		{
			CancelBeam();
		}
		
		if (nextCooldownSound != 0 and nextCooldownSound < g_Engine.time)
		{
			nextCooldownSound = 0;
			
			WeaponSound@ snd = active_opts.getRandomCooldownSound();
			@lastCooldownSnd = @snd;
			if (lastCooldownSnd !is null)
				snd.play(self.m_pPlayer, CHAN_VOICE);
		}
		
		//println("FRAMERATE: " + self.pev.animtime);
		//self.pev.framerate = 500;
		//float wow = self.StudioFrameAdvance(0.0f);
		
		self.ResetEmptySound();
		
		if( self.m_flTimeWeaponIdle > WeaponTimeBase() or windingUp )
			return;

		if (settings.idle_time > 0) {
			self.SendWeaponAnim( settings.getRandomIdleAnim() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + settings.idle_time; // how long till we do this again.
		}
	}
}