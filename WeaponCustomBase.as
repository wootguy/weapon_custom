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
	weapon_custom@ settings;
	
	array< array<CBeam@> > beams = {{null}, {null}};
	array<CSprite@> beamHits; // beam impact sprites
	float beamStartTime = 0;
	float minBeamTime = 0;
	
	float lastBeamDamage = 0;
	bool first_beam_shoot = false;
	
	bool beam_active = false;
	bool canShootAgain = true;
	
	bool burstFiring = false;
	float nextBurstFire = 0;
	int numBurstFires = 0;
	
	weapon_custom_shoot@ active_opts; // active shoot opts
	int active_fire = -1;
	
	void Spawn()
	{
		if (settings is null) {
			@settings = cast<weapon_custom>( custom_weapons[self.pev.classname] );
		}
		
		Precache();
		g_EntityFuncs.SetModel( self, "models/hl/w_9mmAR.mdl" );

		self.m_iDefaultAmmo = settings.clip_size();

		self.m_iSecondaryAmmoType = 0;
		self.FallInit();
		SetThink( ThinkFunction( WeaponThink ) );
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/mortarshell.mdl" );
		
		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );
		g_Game.PrecacheModel( "models/grenade.mdl" );

		g_Game.PrecacheModel( "models/w_9mmARclip.mdl" );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );              

		//These are played by the model, needs changing there
		g_SoundSystem.PrecacheSound( "hl/items/clipinsert1.wav" );
		g_SoundSystem.PrecacheSound( "hl/items/cliprelease1.wav" );
		g_SoundSystem.PrecacheSound( "hl/items/guncock1.wav" );

		g_SoundSystem.PrecacheSound( "hl/weapons/hks1.wav" );
		g_SoundSystem.PrecacheSound( "hl/weapons/hks2.wav" );
		g_SoundSystem.PrecacheSound( "hl/weapons/hks3.wav" );

		g_SoundSystem.PrecacheSound( "hl/weapons/glauncher.wav" );
		g_SoundSystem.PrecacheSound( "hl/weapons/glauncher2.wav" );

		g_SoundSystem.PrecacheSound( "hl/weapons/357_cock1.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		
		if (settings is null) {
			@settings = cast<weapon_custom>( custom_weapons[self.pev.classname] );
		}
		info.iMaxAmmo1 	= 1; // doesn't even matter??
		info.iMaxAmmo2 	= 1; // why not?
		info.iMaxClip 	= settings.clip_size();
		if (info.iMaxClip < 1)
			self.m_iClip = -1;
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
		return self.DefaultDeploy( self.GetV_Model( settings.wpn_v_model ), self.GetP_Model( settings.wpn_p_model ), MP5_DEPLOY, "mp5" );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time; //g_WeaponFuncs.WeaponTimeBase();
	}
		
	void ShootOneBullet()
	{
		Vector vecSrc	 = self.m_pPlayer.GetGunPosition();
		Vector perfectAim = self.m_pPlayer.GetAutoaimVector(0);
		
		// implement our own bullet spread. The built-in one won't let you shoot behind youself.
		Vector vecAiming = spreadDir(perfectAim, active_opts.bullet_spread, active_opts.bullet_spread_func);
	
		self.m_pPlayer.FireBullets( 1, vecSrc, vecAiming, Vector(0,0,0), 8192, BULLET_PLAYER_MP5, 0 );
		
		// bullet decal and particle effects
		if (true)
		{
			TraceResult tr;
			Vector vecEnd = vecSrc + vecAiming * 4096;
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, self.m_pPlayer.edict(), tr );
			
			if( tr.flFraction < 1.0 )
			{
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					
					if( pHit !is null ) 
					{
						if (pHit.IsBSPModel())
							g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_MP5 );
						if (pHit.IsMonster())
							pHit.pev.velocity = pHit.pev.velocity + vecAiming * active_opts.knockback;
					}
						
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
					float len = tr.flFraction*4096;
					int life = int(len / 600.0f) + 1;
					te_usertracer(vecSrc, vecAiming, 6000.0f, life, active_opts.bullet_color, 12);
				}
			}
			
			if (active_opts.pev.spawnflags & FL_SHOOT_EXPLOSIVE_BULLETS != 0)
			{
				// move the explosion away from the surface so the sprite doesn't clip through it
				Vector expPos = tr.vecEndPos + tr.vecPlaneNormal*16.0f;
				g_EntityFuncs.CreateExplosion(expPos, Vector(0,0,0), self.m_pPlayer.edict(), 50, true);
				//te_explosion(expPos, "sprites/zerogxplode.spr", 10, 15, 0);
			}
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
			
		CBaseEntity@ shootEnt = g_EntityFuncs.CreateEntity(classname, keys, false);	
		WeaponCustomProjectile@ shootEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(shootEnt));
		@shootEnt.pev.owner = self.m_pPlayer.edict(); // do this or else crash		
		@shootEnt_c.shoot_opts = active_opts;
		
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
		if (!active_opts.shoots_projectile())
			return;

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
		else if (options.type == PROJECTILE_CUSTOM)
			ShootCustomProjectile("weapon_custom_projectile");
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
	}
	
	void ShootBeam()
	{
		if (!active_opts.shoots_beam() or beam_active)
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
					if (ent.entindex() != 0) // impact if not world
						@impacts[i].ent = ent;
					if (ent.entindex() != 0)
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
					{
						if (active_opts.rico_part_count > 0)
						{
							te_spritetrail(tr.vecEndPos, tr.vecEndPos + n, active_opts.rico_part_spr, 
										   active_opts.rico_part_count, 0, active_opts.rico_part_scale, 
										   active_opts.rico_part_speed/2, active_opts.rico_part_speed);
						}
						if (active_opts.rico_trace_count > 0)
						{
							te_streaksplash(tr.vecEndPos, n, active_opts.rico_trace_color,
											active_opts.rico_trace_count, active_opts.rico_trace_speed/2, active_opts.rico_trace_speed);
						}
						if (active_opts.rico_decal.Length() > 0)
						{
							te_decal(tr.vecEndPos, ent, active_opts.rico_decal);
						}
						string rico_snd = active_opts.getRandomRicochetSound();
						if (rico_snd.Length() > 0)
						{
							g_SoundSystem.PlaySound(beams[beamId][i-1].edict(), CHAN_STATIC, rico_snd, 1.0f, 1.0f, 0, 100);
						}
					}
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
	
	// do everything except actually shooting something
	void AttackEffects()
	{
		// kickback
		Vector kickVel = self.m_pPlayer.GetAutoaimVector(0) * -active_opts.kickback;
		self.m_pPlayer.pev.velocity = self.m_pPlayer.pev.velocity + kickVel;
		
		// play random weapon animation
		switch ( g_PlayerFuncs.SharedRandomLong( self.m_pPlayer.random_seed, 0, 2 ) )
		{
			case 0: self.SendWeaponAnim( MP5_FIRE1, 0, 0 ); break;
			case 1: self.SendWeaponAnim( MP5_FIRE2, 0, 0 ); break;
			case 2: self.SendWeaponAnim( MP5_FIRE3, 0, 0 ); break;
		}
		// player "shoot" animation
		self.m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.m_pPlayer.pev.punchangle.x = 0; // recoil
		//self.SendWeaponAnim( MP5_LAUNCH );
		
		// muzzle flash (doesn't seem to do anything?)
		self.m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;
		
		// idle random time after shooting
		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( self.m_pPlayer.random_seed,  10, 15 );
		
		// random shoot sound
		self.m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		g_SoundSystem.EmitSoundDyn( self.m_pPlayer.edict(), CHAN_WEAPON, active_opts.getRandomShootSound(), 
									1.0, ATTN_NORM, 0, 95 + Math.RandomLong( 0, 10 ) );
		
		// monster reaction to sounds
		self.m_pPlayer.m_iExtraSoundTypes = bits_SOUND_DANGER;
		self.m_pPlayer.m_flStopExtraSoundTime = WeaponTimeBase() + 0.2;
			
		DepleteAmmo();
			
		// cooldown
		self.m_flNextPrimaryAttack = WeaponTimeBase() + active_opts.cooldown;
		self.m_flNextSecondaryAttack = WeaponTimeBase() + active_opts.cooldown;
	}
	
	void DoAttack()
	{
		AttackEffects();
		
		// shoot stuff
		if (active_opts.shoots_bullet())
			ShootBullets();
		ShootProjectile();
		ShootBeam();
		DetonateSatchels();
	}
	
	void DepleteAmmo()
	{
		int ammoType = active_fire == 0 ? self.m_iPrimaryAmmoType : self.m_iSecondaryAmmoType;
		if (self.m_iClip > 0) 
			--self.m_iClip;
		else // gun doesn't use a clip
			self.m_pPlayer.m_rgAmmo( ammoType, AmmoLeft()-1);
			
		if( self.m_pPlayer.m_rgAmmo(ammoType) <= 0 )
			// HEV suit - indicate out of ammo condition
			self.m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
	}
	
	int AmmoLeft()
	{
		int ammoType = active_fire == 0 ? self.m_iPrimaryAmmoType : self.m_iSecondaryAmmoType;
		return self.m_pPlayer.m_rgAmmo( ammoType );
	}
	
	bool CanStartAttack()
	{
		if (active_opts.pev.spawnflags & FL_SHOOT_NO_AUTOFIRE != 0)
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
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return false;
		}
		
		if( self.m_iClip <= 0 )
		{
			if (settings.clip_size() > 0 or AmmoLeft() <= 0) {
				self.PlayEmptySound();
				self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
				return false;
			}
		}
		
		return true;
	}
	
	void PrimaryAttack()
	{
		active_fire = 0;
		@active_opts = settings.fire_settings[0];
		
		if (!CanStartAttack())
			return;
		
		DoAttack();
	}

	void SecondaryAttack()
	{
		active_fire = 1;
		@active_opts = settings.fire_settings[1];
		
		if (!CanStartAttack())
			return;

		DoAttack();
		
		DetonateSatchels();
	}

	void TertiaryAttack()
	{
		println("LOL ATTACK 3");
	}
	
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
		
		self.ResetEmptySound();

		self.m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		int iAnim;
		switch( g_PlayerFuncs.SharedRandomLong( self.m_pPlayer.random_seed,  0, 1 ) )
		{
		case 0:	
			iAnim = MP5_LONGIDLE;	
			break;
		
		case 1:
			iAnim = MP5_IDLE1;
			break;
			
		default:
			iAnim = MP5_IDLE1;
			break;
		}

		self.SendWeaponAnim( iAnim );

		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( self.m_pPlayer.random_seed,  10, 15 );// how long till we do this again.
	}
}