enum Mp5Animation
{
	MP5_LONGIDLE = 0,
	MP5_IDLE1,
	MP5_LAUNCH,
	MP5_RELOAD,
	MP5_DEPLOY,
	MP5_FIRE1,
	MP5_FIRE2,
	MP5_FIRE3,
};

class WeaponCustomBase : ScriptBasePlayerWeaponEntity
{
	float m_flNextAnimTime;
	int m_iShell;
	int	m_iSecondaryAmmo;
	int lastButton; // last player button state
	int lastSequence;
	weapon_custom@ settings;
	
	array< array<CBeam@> > beams = {{null}, {null}};
	array<CSprite@> beamHits; // beam impact sprites
	float beamStartTime = 0;
	float minBeamTime = 0;
	
	float lastBeamDamage = 0;
	bool first_beam_shoot = false;
	
	bool beam_active = false;
	bool canShootAgain = true;
	
	bool meleeHit = false;
	bool healedTarget = true;
	bool abortAttack = false;
	
	bool burstFiring = false;
	float nextBurstFire = 0;
	int numBurstFires = 0;
	
	bool windingUp = false;
	bool windupSoundActive = false;
	bool windingDown = false;
	bool windupHeld = false;
	bool windupFinished = false;
	float windupStart = 0;
	float lastWindupInc = 0;
	float nextWindupShoot = 0;
	float windupMultiplier = 1.0f;
	int windupAmmoUsed = 0;
	
	int active_fire = -1;
	int active_ammo_type = -1;
	weapon_custom_shoot@ active_opts; // active shoot opts
	
	
	void Spawn()
	{
		if (settings is null) {
			@settings = cast<weapon_custom>( custom_weapons[self.pev.classname] );
		}
		
		Precache();
		g_EntityFuncs.SetModel( self, settings.wpn_w_model );

		self.m_iDefaultAmmo = settings.clip_size();

		self.m_iSecondaryAmmoType = 0;
		self.FallInit();
		SetThink( ThinkFunction( WeaponThink ) );
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		
		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );

		g_Game.PrecacheModel( "models/w_9mmARclip.mdl" );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );              

		//These are played by the model, needs changing there (TODO: Are they really used?)
		g_SoundSystem.PrecacheSound( "hl/items/clipinsert1.wav" );
		g_SoundSystem.PrecacheSound( "hl/items/cliprelease1.wav" );
		g_SoundSystem.PrecacheSound( "hl/items/guncock1.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		
		if (settings is null) {
			@settings = cast<weapon_custom>( custom_weapons[self.pev.classname] );
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
	
	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			g_SoundSystem.EmitSoundDyn( self.m_pPlayer.edict(), CHAN_WEAPON, "hl/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( settings.wpn_v_model ), self.GetP_Model( settings.wpn_p_model ), 
								   settings.deploy_anim, settings.getPlayerAnimExt() );
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
		Vector perfectAim = self.m_pPlayer.GetAutoaimVector(0);
		Vector vecAiming = spreadDir(perfectAim, active_opts.bullet_spread, active_opts.bullet_spread_func);
		
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
		
		meleeHit = tr.flFraction < 1.0;
		
		// do all the fancy bullet effects
		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit !is null ) 
				{
					int dmgType = DMG_BULLET | DMG_NEVERGIB;
					if (active_opts.shoot_type == SHOOT_MELEE)
						dmgType = DMG_CLUB;
					
					// damage done before hitgroup multipliers
					float baseDamage = active_opts.bullet_damage*windupMultiplier;
					baseDamage = applyDamageModifiers(baseDamage, pHit, self.m_pPlayer, active_opts);
					
					if (baseDamage < 0)
					{	
						// avoid TraceAttack so scis don't think we're shooting at them
						heal(pHit, active_opts, -baseDamage);
					}
					else
					{
						if (active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0)
						{
							abortAttack = true;
							return;
						}
						g_WeaponFuncs.ClearMultiDamage(); // fixes TraceAttack() crash for some reason
						pHit.TraceAttack(self.m_pPlayer.pev, baseDamage, vecAiming, tr, dmgType);
						g_WeaponFuncs.ApplyMultiDamage(pHit.pev, self.m_pPlayer.pev);
					}
					
					string decal = getBulletDecalOverride(pHit, getDecal(active_opts.bullet_decal));
					if (pHit.IsBSPModel()) {
						if (active_opts.bullet_impact == BULLET_IMPACT_STANDARD)
							te_gunshotdecal(tr.vecEndPos, pHit, decal);
						if (active_opts.bullet_impact == BULLET_IMPACT_MELEE)
							te_decal(tr.vecEndPos, pHit, decal);
					}
					
					knockBack(pHit, vecAiming * active_opts.knockback);
					
					bool playDefaultMeleeSnd = active_opts.shoot_type == SHOOT_MELEE;
					bool playDefaultMeleeSndQuietly = isBreakableEntity(pHit); // only SC does this
					if (pHit.IsMonster() or pHit.IsPlayer())
					{
						if (!pHit.IsMachine())
						{
							// impact sound
							WeaponSound@ snd = active_opts.getRandomMeleeFleshSound();
							if (snd !is null)
								snd.play(self.m_pPlayer, CHAN_STATIC);
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
							snd.play(self.m_pPlayer, CHAN_STATIC, volume);
					}
				}
			}
		}
		else // Bullet didn't hit anything
		{
			if (active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_MISS != 0)
			{
				abortAttack = true;
				return;
			}
						
			bool meleeSkip = active_opts.shoot_type == SHOOT_MELEE;
			meleeSkip = meleeSkip and (active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP != 0);
			// melee weapons are special and only play shoot sounds when they miss
			if (meleeSkip)
			{
				WeaponSound@ snd = active_opts.getRandomShootSound();
				if (snd !is null)
					snd.play(self.m_pPlayer, CHAN_WEAPON);
			}
		}
		
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
	
	CBaseEntity@ ShootCustomProjectile(string classname)
	{
		ProjectileOptions@ options = active_opts.projectile;
		
		dictionary keys;
		Vector boltOri = self.m_pPlayer.pev.origin + self.m_pPlayer.pev.view_ofs;
		Vector boltAngles = self.m_pPlayer.pev.v_angle * Vector(-1, 1, 1);
		Vector projectile_velocity = g_Engine.v_forward * options.speed;
		keys["origin"] = boltOri.ToString();
		keys["angles"] = boltAngles.ToString();
		keys["velocity"] = projectile_velocity.ToString();
		
		// replace model or use error.mdl if no model specified and not a standard entity
		string model = options.model.Length() > 0 ? options.model : "models/error.mdl";
		if (options.type == PROJECTILE_CUSTOM or options.type == PROJECTILE_OTHER and options.model.Length() > 0) 
			keys["model"] = model;
		if (options.type == PROJECTILE_WEAPON)
			keys["model"] = settings.wpn_w_model;
			
		CBaseEntity@ shootEnt = g_EntityFuncs.CreateEntity(classname, keys, false);	
		WeaponCustomProjectile@ shootEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(shootEnt));
		@shootEnt.pev.owner = self.m_pPlayer.edict(); // do this or else crash		
		@shootEnt_c.shoot_opts = active_opts;
		shootEnt_c.pickup_classname = settings.weapon_classname;
		
		g_EntityFuncs.DispatchSpawn(shootEnt.edict());
		
		EHandle mdlHandle = @shootEnt;
		EHandle sprHandle;
		
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
		
		return shootEnt;
	}
	
	void ShootProjectile()
	{		
		Math.MakeVectors( self.m_pPlayer.pev.v_angle + self.m_pPlayer.pev.punchangle );
		
		ProjectileOptions@ options = active_opts.projectile;
		Vector projectile_velocity = g_Engine.v_forward * options.speed;
		Vector projectile_ori = self.m_pPlayer.pev.origin + g_Engine.v_forward * 16 + g_Engine.v_right * 6;
		projectile_ori = projectile_ori + self.m_pPlayer.pev.view_ofs * 0.5;
		float grenadeTime = options.life != 0 ? options.life : 3.5f; // timed grenades only
		
		CGrenade@ nade = null;
		CBaseEntity@ shootEnt = null;
		if (options.type == PROJECTILE_ARGRENADE)
			@nade = g_EntityFuncs.ShootContact( self.m_pPlayer.pev, projectile_ori, projectile_velocity );
		else if (options.type == PROJECTILE_BANANA)
			@nade = g_EntityFuncs.ShootBananaCluster( self.m_pPlayer.pev, projectile_ori, projectile_velocity );
		else if (options.type == PROJECTILE_BOLT)
			ShootCustomProjectile("crossbow_bolt");
		else if (options.type == PROJECTILE_HVR)
			ShootCustomProjectile("hvr_rocket");
		else if (options.type == PROJECTILE_SHOCK)
			ShootCustomProjectile("shock_beam");
		else if (options.type == PROJECTILE_HORNET)
			ShootCustomProjectile("playerhornet");
		else if (options.type == PROJECTILE_DISPLACER)
			@shootEnt = g_EntityFuncs.CreateDisplacerPortal( projectile_ori, projectile_velocity, self.m_pPlayer.edict(), 250, 250 );
		else if (options.type == PROJECTILE_GRENADE)
			@nade = g_EntityFuncs.ShootTimed( self.m_pPlayer.pev, projectile_ori, projectile_velocity, grenadeTime );
		else if (options.type == PROJECTILE_MORTAR)
			@nade = g_EntityFuncs.ShootMortar( self.m_pPlayer.pev, projectile_ori, projectile_velocity );
		else if (options.type == PROJECTILE_RPG)
			@shootEnt = g_EntityFuncs.CreateRPGRocket(projectile_ori, self.m_pPlayer.pev.v_angle, self.m_pPlayer.edict());
		else if (options.type == PROJECTILE_WEAPON)
			ShootCustomProjectile("custom_projectile");
		else if (options.type == PROJECTILE_CUSTOM)
			ShootCustomProjectile("custom_projectile");
		else if (options.type == PROJECTILE_OTHER)
			ShootCustomProjectile(options.entity_class);
		else
			println("Unknown projectile type: " + options.type);
			
		if (nade !is null)
			@shootEnt = cast<CBaseEntity@>(nade);
			
		if (shootEnt !is null and false)
		{
			if (active_opts.pev.spawnflags & FL_SHOOT_PROJ_NO_GRAV != 0) // disable gravity on projectile
				shootEnt.pev.movetype = MOVETYPE_FLY;
			else if (nade !is null or true)
				shootEnt.pev.movetype = MOVETYPE_BOUNCE;
			//else
				//shootEnt.pev.movetype = MOVETYPE_TOSS;
		}
		
		if (options.type == PROJECTILE_WEAPON)
		{
			g_Scheduler.SetTimeout( "removeWeapon", 0, @self );
		}
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
	}
	
	void DetonateSatchels()
	{
		if (active_opts.pev.spawnflags & FL_SHOOT_DETONATE_SATCHELS == 0)
			return;
		g_EntityFuncs.UseSatchelCharges(self.m_pPlayer.pev, SATCHEL_DETONATE);
	}
	
	// calculates beams, end sprite locations, and damage
	bool UpdateBeam(int beamId)
	{
		BeamOptions@ beam_opts = active_opts.beams[beamId];
		
		if (beam_opts.time > 0 and beamStartTime + beam_opts.time < g_Engine.time)
		{
			DestroyBeam(beamId);
			return false;
		}
		if (beam_opts.type == BEAM_DISABLED)
			return false;
			
		bool doDamage = lastBeamDamage + 0.1 < g_Engine.time;
		if (doDamage)
			lastBeamDamage = g_Engine.time;
			
		Vector vecSrc = self.m_pPlayer.GetGunPosition();
		Vector perfectAim = self.m_pPlayer.GetAutoaimVector(0);
		Vector vecEnd = vecSrc + perfectAim*active_opts.max_range;

		edict_t@ traceEnt = self.m_pPlayer.edict();
		
		array<BeamImpact> impacts(active_opts.beam_ricochet_limit+1);
		
		int numRicochets = 1;
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{
			CBeam@ ricobeam = beams[beamId][i];
			
			// initial beam is special
			if (i == 0)
			{
				if (ricobeam is null)
				{
					@ricobeam = @beams[beamId][i] = g_EntityFuncs.CreateBeam( beam_opts.sprite, 16 );
					ricobeam.SetType(BEAM_ENTPOINT);
					ricobeam.SetEndEntity(self.m_pPlayer);
					ricobeam.SetEndAttachment(1);
					if (beam_opts.type == BEAM_SPIRAL)
						ricobeam.SetFlags( BEAM_FSINE );
					ricobeam.SetNoise(beam_opts.noise);
					ricobeam.SetWidth(beam_opts.width);
					ricobeam.SetColor(beam_opts.color.r, beam_opts.color.g, beam_opts.color.b);
					ricobeam.SetBrightness(beam_opts.color.a);
					ricobeam.SetScrollRate(beam_opts.scrollRate);
				}
				ricobeam.SetStartPos(vecEnd);
				continue;
			}
			
			TraceResult tr;
			Vector dir = (vecEnd - vecSrc).Normalize();
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, traceEnt, tr );
			
			if (tr.flFraction < 1.0)
			{
				CBaseEntity@ ent = null;
				if (tr.pHit !is null) 
					@ent = g_EntityFuncs.Instance( tr.pHit );
				
				impacts[i].pos = tr.vecEndPos;
				
				if (ent !is null)
				{
					if (ent.ReflectGauss()) 
						@impacts[i].ent = ent; // don't ricochet of things that take damage
					if (!ent.ReflectGauss())
					{
						if (ent.IsMonster()) {
							ent.pev.velocity = ent.pev.velocity + dir*active_opts.knockback;
						}						
						break;
					}
				}
				
				// Calculate reflection vector
				Vector n = tr.vecPlaneNormal;
				float dotdir = DotProduct(dir, n);
				float ricAngle = -dotdir * 90;
				if (ricAngle > active_opts.rico_angle)
					break;
				
				Vector r = (dir - 2*(dotdir)*n);
				vecSrc = tr.vecEndPos;
				vecEnd = vecSrc + r*active_opts.max_range;
				
				if (ricobeam is null)
				{
					@ricobeam = @beams[beamId][i] = g_EntityFuncs.CreateBeam( beam_opts.sprite, 16 );
					if (beam_opts.type == BEAM_SPIRAL)
						ricobeam.SetFlags( BEAM_FSINE );
					ricobeam.SetNoise(beam_opts.noise);
					ricobeam.SetWidth(beam_opts.width);
					ricobeam.SetColor(beam_opts.color.r, beam_opts.color.g, beam_opts.color.b);
					ricobeam.SetBrightness(beam_opts.color.a);
					ricobeam.SetScrollRate(beam_opts.scrollRate);
				}
				ricobeam.PointsInit(vecEnd, vecSrc);
				@traceEnt = ricobeam.edict(); // all beams after this one can collide with owner
				if (i > 0)
				{
					beams[beamId][i-1].SetStartPos(tr.vecEndPos);
					
					if (minBeamTime > 0 or doDamage)
						custom_ricochet(tr.vecEndPos, n, active_opts, beams[beamId][i-1], ent);
				}

				numRicochets = i+1;
			}
			else
			{
				numRicochets = i;
				break;
			}
		}
		
		// clip final beam
		TraceResult tr;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, traceEnt, tr );
		CBeam@ lastBeam = beams[beamId][numRicochets-1];
		lastBeam.SetStartPos(tr.vecEndPos);
		
		// last impact check
		if (tr.flFraction < 1.0)
		{
			if (tr.pHit !is null) 
			{
				CBaseEntity@ ent = g_EntityFuncs.Instance( tr.pHit );
				impacts[numRicochets-1].pos = tr.vecEndPos;
				if (ent.entindex() != 0)
				{
					@impacts[numRicochets-1].ent = ent;
				}
			}
		}

		// draw impact sprites
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{
			if (minBeamTime == 0) // constant beams have animated sprites (like egon)
			{
				if (impacts[i].ent !is null)
				{
					if (beamHits[i] is null)
					{
						@beamHits[i] = g_EntityFuncs.CreateSprite( active_opts.beam_impact_spr, impacts[i].pos, true, 10 );
						beamHits[i].pev.rendermode = kRenderGlow;
						beamHits[i].pev.renderamt = 255;
						beamHits[i].pev.renderfx = kRenderFxNoDissipation;
					}
					beamHits[i].pev.origin = impacts[i].pos;
				}
				else if (beamHits[i] !is null)
				{
					g_EntityFuncs.Remove( beamHits[i] );
					@beamHits[i] = null;
				}
			} 
			else if (i == numRicochets-1) // temporary beams get glow sprites (like gauss)
			{
				// don't show impact sprites on monsters
				if (impacts[i].ent is null or impacts[i].ent.IsBSPModel())
					te_glowsprite(impacts[i].pos, active_opts.beam_impact_spr, int(minBeamTime*10), 10, 200);
			}
		}
		
		// kill previous ricochet beams
		for (int i = numRicochets; i < active_opts.beam_ricochet_limit+1; i++)
		{
			if (beams[beamId][i] !is null)
			{
				g_EntityFuncs.Remove( beams[beamId][i] );
				@beams[beamId][i] = null;
			}
		}
		
		return true;
	}
	
	void DestroyBeams()
	{
		if (!beam_active)
			return;
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{
			for (uint k = 0; k < beams.length(); k++)
			{
				if (beams[k][i] !is null)
				{
					g_EntityFuncs.Remove( beams[k][i] );
					@beams[k][i] = null;
				}
			}
			if (beamHits[i] !is null)
			{
				g_EntityFuncs.Remove( beamHits[i] );
				@beamHits[i] = null;
			}
		}
	}
	
	// draw another beam on top of the primary one (skip all the ricochet and damage math)
	void AddBeam(int beamId)
	{
		BeamOptions@ beam_opts = active_opts.beams[beamId];
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{
			CBeam@ copybeam = beams[0][i];
			if (copybeam is null)
			{
				g_EntityFuncs.Remove( beams[beamId][i] );
				@beams[beamId][i] = null;
				continue;
			}
			
			CBeam@ ricobeam = beams[beamId][i];
			if (ricobeam is null)
			{
				@ricobeam = @beams[beamId][i] = g_EntityFuncs.CreateBeam( beam_opts.sprite, 16 );
				if (beam_opts.type == BEAM_SPIRAL)
					ricobeam.SetFlags( BEAM_FSINE );
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
			}
			if (i == 0)
				ricobeam.SetStartPos(copybeam.GetStartPos());
			else
				ricobeam.PointsInit(copybeam.GetStartPos(), copybeam.GetEndPos());
		}
	}
	
	void DestroyBeam(int beamId)
	{
		for (int i = 0; i < active_opts.beam_ricochet_limit+1; i++)
		{
			if (beams[beamId][i] !is null)
			{
				g_EntityFuncs.Remove( beams[beamId][i] );
				@beams[beamId][i] = null;
			}
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
						windupSoundActive = false;
						windingDown = false;
						windupFinished = false;
						windupAmmoUsed = 0;
						active_opts.windup_snd.stop(self.m_pPlayer, CHAN_STATIC);
					}
					else
					{
						p = WindupEase(p, q, active_opts.windup_easing, true);
						float delta = active_opts.windup_pitch_end - active_opts.windup_pitch_start;
						int newPitch = active_opts.windup_pitch_start + int(delta*p + 0.5f);
						//println("T : " + newPitch);
						
						if (active_opts.windup_snd.file.Length() > 0)
							g_SoundSystem.EmitSoundDyn( self.m_pPlayer.edict(), CHAN_STATIC, active_opts.windup_snd.file, 
														1.0, ATTN_NORM, SND_CHANGE_PITCH, newPitch);
					}
					
				}
			} 
			else // fire a bullet at the current windup and stop
			{
				windingUp = false;
				windupSoundActive = false;
				windingDown = false;
				windupFinished = false;
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
				
				if (active_opts.windup_snd.file.Length() > 0)
					g_SoundSystem.EmitSoundDyn( self.m_pPlayer.edict(), CHAN_STATIC, active_opts.windup_snd.file, 
												1.0, ATTN_NORM, 0, 512 );
											
				windupSoundActive = true;
			}
			else if (timePassed < active_opts.windup_time)
			{
				p = WindupEase(p, q, active_opts.windup_easing, false);
				
				windupMultiplier = 1.0f + p*(active_opts.windup_mult-1.0f);
				float delta = active_opts.windup_pitch_end - active_opts.windup_pitch_start;
				debugln("Windup Multiplier: " + windupMultiplier);
				int newPitch = active_opts.windup_pitch_start + int(delta*p + 0.5f);
				//println("T : " + newPitch);
				
				if (active_opts.windup_snd.file.Length() > 0)
					g_SoundSystem.EmitSoundDyn( self.m_pPlayer.edict(), CHAN_STATIC, active_opts.windup_snd.file, 
												1.0, ATTN_NORM, SND_CHANGE_PITCH, newPitch);
											
				int ammoUsedNow = int(p*active_opts.windup_cost + 0.5f);
				DepleteAmmo(Math.max(0, ammoUsedNow - windupAmmoUsed));
				windupAmmoUsed = ammoUsedNow;
			}
			else if (timePassed > active_opts.windup_time)
			{		
				windupMultiplier = active_opts.windup_mult;
				if (!windupFinished)
					debugln("Windup Multiplier: " + windupMultiplier);
				windupFinished = true;
				if (active_opts.windup_action == WINDUP_SHOOT_ONCE)
				{
					windingUp = false;
					windupSoundActive = false;
					if (active_opts.windup_snd.file.Length() > 0)
						g_SoundSystem.StopSound( self.m_pPlayer.edict(), CHAN_STATIC, active_opts.windup_snd.file);
					if (AllowedToShoot())
						DoAttack(true);
						
				}
				if (active_opts.windup_action == WINDUP_SHOOT_CONSTANT)
				{
					if (AllowedToShoot() and windupHeld)
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
							windupFinished = false;
							windupSoundActive = true;
							windupAmmoUsed = 0;
							windupMultiplier = 1.0f;
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
			
		if (beam_active)
		{
			if (self.m_pPlayer.pev.button & 1 != 0 and minBeamTime == 0 or first_beam_shoot) 
			{
				UpdateBeam(0);
				AddBeam(1);	
				first_beam_shoot = false;			
			}
			else if (beamStartTime + minBeamTime > g_Engine.time)
			{
				// kill beams with durations less than the total beam duration
				for (uint k = 0; k < active_opts.beams.length(); k++)
				{
					if (beams[k][0] is null)
						continue;
					BeamOptions@ beam_opts = active_opts.beams[k];
					if (beamStartTime + beam_opts.time < g_Engine.time)
						DestroyBeam(k);
				}
			}
			else
			{
				DestroyBeams();
				beam_active = false;
			}
		}
		else if (burstFiring)
		{
			if (!AllowedToShoot())
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
		else if (!canShootAgain)
		{
			// wait for user to stop holding trigger
			if (self.m_pPlayer.pev.button & 1 == 0) {
				canShootAgain = true;
			}	
		}
		else
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
		return nextAttack <= g_Engine.time;
	}
	
	// do everything except actually shooting something
	void AttackEffects(bool windupAttack=false)
	{
		// kickback
		Vector kickVel = self.m_pPlayer.GetAutoaimVector(0) * -active_opts.kickback;
		self.m_pPlayer.pev.velocity = self.m_pPlayer.pev.velocity + kickVel;
		
		// play random first-person weapon animation
		self.SendWeaponAnim( meleeHit ? getRandomMeleeAnim() : getRandomShootAnim(), 0, 0 );
		
		// thirperson animation
		if (!windupAttack)
			self.m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		else
		{
			// Manually set wrench windup attack animation
			self.m_pPlayer.m_Activity = ACT_RELOAD;
			self.m_pPlayer.pev.frame = 0;
			self.m_pPlayer.pev.sequence = 27;
			self.m_pPlayer.ResetSequenceInfo();
			//self.m_pPlayer.pev.framerate = 0.5f;
		}
		
		// recoil
		self.m_pPlayer.pev.punchangle.x = 0;//Math.RandomLong(-180, 180);
		self.m_pPlayer.pev.punchangle.y = 0;//Math.RandomLong(-180, 180);
		self.m_pPlayer.pev.punchangle.z = 0;//Math.RandomLong(-180, 180);
		//self.m_pPlayer.pev.punchangle.y = 0;
		
		// idle random time after shooting
		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( self.m_pPlayer.random_seed,  10, 15 );
		
		// random shoot sound
		
		bool meleeSkip = active_opts.shoot_type == SHOOT_MELEE;
		meleeSkip = meleeSkip and (active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP != 0);
		if (!meleeSkip)
		{
			WeaponSound@ snd = active_opts.getRandomShootSound();
			if (snd !is null)
				snd.play(self.m_pPlayer, CHAN_WEAPON);
		}
		
		// monster reactions to shooting or danger
		int hmode = active_opts.heal_mode;
		bool harmlessWep = hmode == HEAL_ALL or active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0;
		if (!healedTarget and !harmlessWep)
		{
			// get a little spooked
			self.m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;
			self.m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
			self.m_pPlayer.m_iExtraSoundTypes = bits_SOUND_COMBAT;//bits_SOUND_DANGER;
			self.m_pPlayer.m_flStopExtraSoundTime = WeaponTimeBase() + 0.2;
		}
			
		DepleteAmmo(active_opts.ammo_cost);
			
		// cooldown
		if (windingUp) 
		{
			// no cooldown during windups or else we don't know if the button is still pressed
			nextWindupShoot = WeaponTimeBase() + active_opts.cooldown;
		}
		else
		{
			float cooldownVal = active_opts.cooldown;
			if (active_opts.shoot_type == SHOOT_MELEE and !meleeHit)
				cooldownVal = active_opts.melee_miss_cooldown;
			self.m_flNextPrimaryAttack = WeaponTimeBase() + cooldownVal;
			self.m_flNextSecondaryAttack = WeaponTimeBase() + cooldownVal;
			self.m_flNextTertiaryAttack = WeaponTimeBase() + cooldownVal;
		}
	}
	
	bool AttackButtonPressed()
	{
		if (active_fire == 0) return self.m_pPlayer.pev.button & 1 != 0;
		if (active_fire == 1) return self.m_pPlayer.pev.button & 2048 != 0;
		return false;
	}
	
	void DoAttack(bool windupAttack=false)
	{		
		healedTarget = false;
		abortAttack = false;
		
		// shoot stuff
		switch(active_opts.shoot_type)
		{
			case SHOOT_MELEE:
			case SHOOT_BULLETS: ShootBullets(); break;
			case SHOOT_PROJECTILE: ShootProjectile(); break;
			case SHOOT_BEAM: ShootBeam(); break;
		}
		DetonateSatchels();
		
		if (!abortAttack)
			AttackEffects(windupAttack);
	}
	
	void DepleteAmmo(int amt)
	{
		if (active_ammo_type == -1) return;
		if (self.m_iClip > 0) 
			self.m_iClip -= amt;
		else // gun doesn't use a clip
			self.m_pPlayer.m_rgAmmo( active_ammo_type, AmmoLeft()-amt);
			
		if( self.m_pPlayer.m_rgAmmo(active_ammo_type) <= 0 )
			// HEV suit - indicate out of ammo condition
			self.m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
	}
	
	int AmmoLeft()
	{
		if (active_ammo_type == -1) return -1; // doesn't use ammo
		return Math.max(0, self.m_pPlayer.m_rgAmmo( active_ammo_type ));
	}
	
	// returns true if a windup was started
	bool DoWindup()
	{
		if (active_opts.windup_time > 0 and !windingUp)
		{
			windingUp = true;
			windingDown = false;
			windupFinished = false;
			windupHeld = true;
			windupMultiplier = 1.0f;
			windupStart = g_Engine.time;
			self.pev.nextthink = g_Engine.time;
			
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
	
	bool CanStartAttack(weapon_custom_shoot@ opts)
	{
		if (windingUp)
		{
			windupHeld = true;
			return false;
		}
		
		if (opts.pev.spawnflags & FL_SHOOT_NO_AUTOFIRE != 0)
		{
			if (!canShootAgain) {
				return false;
			}
			canShootAgain = false;
			self.pev.nextthink = g_Engine.time;
		}
		
		return AllowedToShoot();
	}
	
	bool AllowedToShoot()
	{
		// don't fire underwater
		if( self.m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD and !active_opts.can_fire_underwater())
		{
			self.PlayEmptySound( );
			SetNextAttack(WeaponTimeBase() + 0.15);
			return false;
		}
		
		if( self.m_iClip <= 0 )
		{
			if (settings.clip_size() > 0 or AmmoLeft() == 0) {
				self.PlayEmptySound();
				SetNextAttack(WeaponTimeBase() + 0.15);
				return false;
			}
		}
		
		return true;
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
	
	void CommonAttack(int attackNum)
	{
		int next_fire = attackNum;
		weapon_custom_shoot@ next_opts = settings.fire_settings[next_fire];
	
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
			if (settings.tertiary_ammo_type == 1)
				active_ammo_type = self.m_iPrimaryAmmoType;
			if (settings.tertiary_ammo_type == 2) 
				active_ammo_type = self.m_iSecondaryAmmoType;
		}
		
		if (DoWindup())
			return;
		
		DoAttack();
	}
	
	void PrimaryAttack()   { CommonAttack(0); }
	void SecondaryAttack() { CommonAttack(1); }
	void TertiaryAttack()  { CommonAttack(2); }
	
	void Reload()
	{
		self.DefaultReload( settings.clip_size(), MP5_RELOAD, 1.5, 0 );

		//Set 3rd person reloading animation -Sniper
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		if (beamStartTime + minBeamTime < g_Engine.time)
		{
			DestroyBeams();
			beam_active = false;
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