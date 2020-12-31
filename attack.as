
namespace WeaponCustom {

// State shared between weapons and monsters
class WeaponState
{
	// weapon ent (players only)
	WeaponCustomBase@ c_wep = null;
	CBasePlayerWeapon@ wep = null;
	
	// Monster ent (mosnters only)
	MonsterCustomBase@ c_mon = null;
	
	CBaseEntity@ user; // owner of the weapon
	weapon_custom_shoot@ active_opts; // active shoot opts
	bool shootingHook = false;
	bool meleeHit = false;
	bool abortAttack = false;
	bool healedTarget = true;
	bool needShellEject = false;
	bool canShootAgain = true;
	bool burstFiring = false;
	float nextBurstFire = 0;
	int numBurstFires = 0;
	float ejectShellTime = 0;
	
	float nextCooldownEffect = 0;
	
	array< array<EHandle> > beams = {{null}, {null}}; // CBeam handles
	array<EHandle> beamHits; // beam impact sprites (CSprite handles)
	array<EHandle> ubeams; // user effect beams
	bool beam_active = false;
	bool first_beam_shoot = false;
	float minBeamTime = 0;
	float beamStartTime = 0;
	float nextBeamAttack = 0; // constant beam attack delay
	float lastBeamDamage = 0;
	
	bool windingUp = false;
	bool windupSoundActive = false;
	bool windingDown = false;
	bool windupHeld = false;
	bool windupFinished = false;
	bool windupLoopEntered = false;
	bool windupOvercharged = false;
	bool windupShooting = false; // true if finished windup and currently shooting
	bool windupOnly = false; // current fire held is for windup only
	bool idleShot = false; // set to true after firing from an idle windup state
	float windupStart = 0;
	float lastWindupInc = 0;
	int windupAmmoUsed = 0;
	float lastWindupHeld = 0; // Don't winddown immediately or else laggy players won't be able to hold a windup
	
	float windupMultiplier = 1.0f;
	float windupKickbackMultiplier = 1.0f;
	
	EHandle hook_ent;
	EHandle hook_beam;
	float hookAnimStartTime = 0;
	bool hookAnimStarted = false;
	
	EHandle laser_spr;
	
	float partialAmmoModifier = 1.0f; // scale damage by how much ammo was used
	int partialAmmoUsage; // reduce ammo usage if damage amount was less than expected (e.g. heal past max health)
	int shootCount = 0;
	int active_ammo_type = -1;
	int liveProjectiles = 0;
	int reloading = 0; // continous reload state
	int reloading2 = 0; // secondary reload state
	bool reloadSecondary = false;
	
	float lastPrimaryRegen = 0;
	float lastSecondaryRegen = 0;
	
	float deployTime = 0;
	float nextShootTime = 0;
	float nextActionTime = 0;
	float unhideLaserTime = 0;
	float reloadFinishTime = 0;
	
	float nextReload = 0;
	float nextReloadEnd = 0;
	
	float deathTime;
	
	WeaponSound@ lastCooldownSnd;
	WeaponSound@ lastShootSnd;
}

// For attacks that last longer than 1 frame
void AttackThink(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	
	if (attacker is null)
		return;
			
	if (state.laser_spr)
	{
		CBaseEntity@ ent = state.laser_spr;
		if (state.unhideLaserTime > g_Engine.time)
		{
			// temporarily hide the laser
			ent.pev.effects |= EF_NODRAW;
		}
		else
		{
			if (ent.pev.effects & EF_NODRAW != 0)
				ent.pev.effects &= ~EF_NODRAW;
			
			Vector vecSrc	 = getGunPos(attacker);
			Math.MakeVectors( attacker.pev.v_angle ); // todo: monster angles
			
			TraceResult tr;
			Vector vecEnd = vecSrc + g_Engine.v_forward * 65536;
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, attacker.edict(), tr );
			
			ent.pev.origin = tr.vecEndPos;
		}
	}
	
	if (state.needShellEject and state.ejectShellTime < g_Engine.time)
	{
		EjectShell(state);
		state.needShellEject = false;
	}
	
	if (state.reloading > 0)
	{
		bool emptyClip = state.c_wep.settings.clip_size() > 0 and state.wep.m_iClip <= 0;
		bool cancelReload = (state.windupHeld and !emptyClip);
		bool responsiveCancel = state.reloading == 2 and cancelReload and state.c_wep.settings.reload_mode == RELOAD_STAGED_RESPONSIVE;
		
		if (state.nextReload < g_Engine.time or responsiveCancel)
		{
			bool noCancelDelay = state.c_wep.settings.reload_cancel_time <= 0;
			
			// reload clip at the end of the animation
			if (!noCancelDelay and state.nextReload < g_Engine.time)
			{
				if (state.reloading == 2 and ReloadContinuous(state, true))
					state.reloading = 3;
			}
			
			if (state.reloading == 3 or cancelReload) // either we finished or player wants to shoot
			{
				if (cancelReload)
				{
					state.wep.SendWeaponAnim(state.c_wep.settings.reload_cancel_anim, 0, state.c_wep.w_body());
					state.c_wep.settings.reload_cancel_snd.play(attacker, CHAN_VOICE);
					state.nextShootTime = g_Engine.time + state.c_wep.settings.reload_cancel_time;
				}
				else
				{
					state.wep.SendWeaponAnim(state.c_wep.settings.reload_end_anim, 0, state.c_wep.w_body() );
					state.c_wep.settings.reload_end_snd.play(attacker, CHAN_VOICE);
					state.nextShootTime = g_Engine.time + state.c_wep.settings.reload_end_time;
				}
				state.wep.m_flTimeWeaponIdle = state.nextShootTime + 1; // I can't bear adding another keyvalue for this delay
				state.reloading = 0;
			}
			else
			{
				state.reloading = 2;
				
				if (noCancelDelay)
				{
					// reload clip at the beginning of the animation
					if (state.reloading == 2 and ReloadContinuous(state, true))
						state.reloading = 3;
				}

				state.c_wep.BaseClass.Reload();
				state.wep.SendWeaponAnim( state.c_wep.settings.reload_anim, 0, state.c_wep.w_body() );
				state.c_wep.settings.reload_snd.play(attacker, CHAN_VOICE);
				state.nextReload = g_Engine.time + state.c_wep.settings.reload_time;
				state.nextShootTime = state.nextReload;
			}
			
		}
	}
	
	// finish a simple reload
	if ((state.reloading < 0 or state.reloading2 < 0) and state.reloadFinishTime < g_Engine.time and attacker.IsPlayer())
	{
		CBasePlayer@ plr = cast<CBasePlayer@>(attacker);
		bool reloadedSecondary = state.reloading2 < 0;
		int clip_size = reloadedSecondary ? state.c_wep.settings.clip_size2 : state.c_wep.settings.clip_size();
		int clip = reloadedSecondary ? state.wep.m_iClip2 : state.wep.m_iClip;
		
		int ammoType = reloadedSecondary ? state.wep.m_iSecondaryAmmoType : state.wep.m_iPrimaryAmmoType;
		int ammoLeft = plr.m_rgAmmo(ammoType);
		int clipNeeded = clip_size - clip;
		int reloadAmt = Math.min(clipNeeded, ammoLeft);
		plr.m_rgAmmo(ammoType, ammoLeft-reloadAmt);
		if (reloadedSecondary)
			state.wep.m_iClip2 += reloadAmt;
		else
			state.wep.m_iClip += reloadAmt;
		state.reloading = state.reloading2 = 0;
	}
	
	bool monitorBeams = false;
	for (int i = 0; i < int(state.ubeams.length()); i++)
	{
		if (state.ubeams[i]) 
		{
			CBaseEntity@ beamEnt = state.ubeams[i];
			if (beamEnt.pev.max_health < g_Engine.time)
			{
				g_EntityFuncs.Remove(beamEnt);
				state.ubeams.removeAt(i); i--;
			}
			
			if (beamEnt.pev.max_health > 0) // beam has a life time set
				monitorBeams = true;
		}
		else // beam killed itelf somehow?
		{	
			state.ubeams.removeAt(i); i--;
		}
	}
		
	if (state.beam_active)
	{
		if (AllowedToShoot(state, state.active_opts) and state.windupHeld and state.minBeamTime == 0 or state.first_beam_shoot) 
		{
			UpdateBeams(state);	
			state.first_beam_shoot = false;

			// hook anim vars shared with constant beam (basically the same thing)
			if (state.minBeamTime == 0 and !state.hookAnimStarted and state.hookAnimStartTime <= g_Engine.time)
			{
				state.hookAnimStarted = true;
				state.active_opts.hook_snd.play(attacker, CHAN_VOICE);
				state.wep.SendWeaponAnim( state.active_opts.hook_anim, 0, state.c_wep.w_body() );
			}				
		}
		else if (state.beamStartTime + state.minBeamTime > g_Engine.time)
		{
			// kill beams with durations less than the total beam duration
			for (uint k = 0; k < state.active_opts.beams.length(); k++)
			{
				if (!state.beams[k][0])
					continue;
				BeamOptions@ beam_opts = state.active_opts.beams[k];
				if (beam_opts.time > 0 and state.beamStartTime + beam_opts.time < g_Engine.time)
					DestroyBeam(state, k);
			}
		}
		else
		{
			CancelBeam(state);			
		}
		cancelWindupTimeout(state);
	}
	else if (state.burstFiring)
	{
		if (!AllowedToShoot(state, state.active_opts))
			state.burstFiring = false;
		else if (g_Engine.time > state.nextBurstFire)
		{
			ShootOneBullet(state);
			state.numBurstFires += 1;
			state.nextBurstFire = g_Engine.time + state.active_opts.bullet_delay;
			AttackEffects(state);
			if (state.numBurstFires >= state.active_opts.bullets)
				state.burstFiring = false;
		}
	}
	else if (state.windingUp)
	{
		WindupThink(state);
	}
	else if (state.shootingHook)
	{
		if (state.windupHeld and state.hook_ent)
		{
			if (!state.hookAnimStarted and state.hookAnimStartTime <= g_Engine.time)
			{
				state.hookAnimStarted = true;
				state.active_opts.hook_snd.play(attacker, CHAN_VOICE);
				state.wep.SendWeaponAnim( state.active_opts.hook_anim, 0, state.c_wep.w_body() );
			}
		}
		else
		{
			state.shootingHook = false;
			if (state.hook_ent)
			{
				CBaseEntity@ hookEnt = state.hook_ent;
				WeaponCustomProjectile@ hookEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(hookEnt));
				hookEnt_c.uninstall_steam_and_kill_yourself();
			}
			
			state.active_opts.hook_snd.stop(attacker, CHAN_VOICE);
			state.active_opts.hook_snd2.play(attacker, CHAN_VOICE);
			state.wep.SendWeaponAnim( state.active_opts.hook_anim2, 0, state.c_wep.w_body() );
			state.wep.m_flTimeWeaponIdle = g_Engine.time + state.active_opts.hook_delay2; // idle after this
			
			if (state.hook_beam)
				g_EntityFuncs.Remove( state.hook_beam );
			state.hook_beam = null;
		}
		cancelWindupTimeout(state);
	}
	else if (!state.canShootAgain)
	{
		// wait for user to stop holding trigger
		if (attacker.pev.button & 1 == 0) {
			state.canShootAgain = true;
		}	
	}
	else if (!state.laser_spr and !state.needShellEject and state.reloading == 0 and state.reloading2 == 0 and !monitorBeams)
		return;
	setNextAttackThink(state, g_Engine.time);
}

void setNextAttackThink(WeaponState& state, float nextthink)
{
	if (state.user.IsPlayer())
	{
		state.wep.pev.nextthink = nextthink;
	}
	else
	{
		MonsterCustomBase@ mon = cast<MonsterCustomBase@>(CastToScriptClass(state.user));
		mon.pev.nextthink = nextthink;
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

void WindupThink(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	float timePassed = g_Engine.time - state.windupStart;
	bool shouldWindDown = state.active_opts.wind_down_time > 0;
	bool responsiveWindup = state.active_opts.pev.spawnflags & FL_SHOOT_RESPONSIVE_WINDUP != 0; 
	bool minWindupDone = timePassed >= state.active_opts.windup_min_time;
	
	bool minWindDownDone = timePassed >= state.active_opts.wind_down_cancel_time;
	bool windDownCancel = minWindDownDone and state.windupHeld;
	state.windupShooting = false;
	
	if (!state.windupHeld and (responsiveWindup and minWindupDone or state.windupFinished) or 
		(state.windingDown and !(responsiveWindup and state.windupHeld) and !windDownCancel ))
	{		
		if (shouldWindDown)
		{
					
			float p = Math.min(1.0f, timePassed / state.active_opts.wind_down_time); // progress
			float q = 1.0f - p; // inverse progress
			if (!state.windingDown)
			{
				state.windingDown = true;
				float ip = 1.0f - Math.min(1.0f, timePassed / state.active_opts.windup_time);
				state.windupStart = g_Engine.time - ip*state.active_opts.wind_down_time;
				state.wep.SendWeaponAnim( state.active_opts.wind_down_anim, 0, state.c_wep.w_body() );
				
				WeaponSound@ snd = state.active_opts.windup_snd;
				if (state.active_opts.wind_down_snd.file.Length() > 0)
					@snd = @state.active_opts.wind_down_snd;
						
				// Play Once sounds are not pitch shifted because there is no way 
				// to determine how long a sound is. Changing pitch causes sound to play again.
				bool playSoundOnce = snd.options !is null and snd.options.pev.renderfx == 2;
				if (snd.file.Length() > 0 and playSoundOnce)
					snd.play(attacker, CHAN_VOICE, 1.0f);
					
				state.c_wep.applyPlayerSpeedMult();
			}
			else // winding down
			{
				if (timePassed >= state.active_opts.wind_down_time)
				{
					// wind down finished
					state.windingUp = false;
					state.windupLoopEntered = false;
					state.windupSoundActive = false;
					state.windingDown = false;
					state.windupFinished = false;
					state.windupAmmoUsed = 0;
					state.c_wep.applyPlayerSpeedMult();
					state.active_opts.windup_snd.stop(attacker, CHAN_VOICE);
					state.active_opts.wind_down_snd.stop(attacker, CHAN_VOICE);
					state.active_opts.windup_loop_snd.stop(attacker, CHAN_VOICE);	
				}
				else
				{
					p = WindupEase(p, q, state.active_opts.windup_easing, true);
					float delta = state.active_opts.windup_pitch_end - state.active_opts.windup_pitch_start;
					int newPitch = state.active_opts.windup_pitch_start + int(delta*p + 0.5f);
					//println("T : " + newPitch);
					
					WeaponSound@ snd = state.active_opts.windup_snd;
					if (state.active_opts.wind_down_snd.file.Length() > 0)
						@snd = @state.active_opts.wind_down_snd;
					
					bool playSoundOnce = snd.options !is null and snd.options.pev.renderfx == 2;
					if (snd.file.Length() > 0 and !playSoundOnce)
						snd.play(attacker, CHAN_VOICE, 1.0f, newPitch, SND_CHANGE_PITCH);
				}
				
			}
		} 
		else // fire a bullet at the current windup and stop
		{
			state.windingUp = false;
			state.windupLoopEntered = false;
			state.windupSoundActive = false;
			state.windingDown = false;
			state.windupFinished = false;
			
			state.active_opts.windup_snd.stop(attacker, CHAN_VOICE);
			state.active_opts.windup_loop_snd.stop(attacker, CHAN_VOICE);	
			
			if (state.active_opts.windup_action != WINDUP_SHOOT_ONCE_IF_HELD or state.windupHeld)
				if (AllowedToShoot(state, state.active_opts))
					DoAttack(state, true);
			state.c_wep.applyPlayerSpeedMult();
		}
	}
	else
	{
		if (attacker.IsPlayer())
		{
			CBasePlayer@ plr = cast<CBasePlayer@>(attacker);
			bool longJumping = plr.m_Activity == ACT_LEAP;
			if (state.c_wep.settings.player_anims == ANIM_REF_CROWBAR)
			{
				bool correctAnim = plr.pev.sequence == 25 or plr.pev.sequence == 26;
				if (plr.m_fSequenceFinished or (!correctAnim and !longJumping)) 
				{
					// Manually set wrench windup loop animation
					plr.m_Activity = ACT_RELOAD;
					plr.pev.frame = 0;
					plr.pev.sequence = 26;
					plr.ResetSequenceInfo();
				}
			}
			if (state.c_wep.settings.player_anims == ANIM_REF_GREN)
			{
				bool correctAnim = plr.pev.sequence == 33 or plr.pev.sequence == 34;
				if (plr.m_fSequenceFinished or (!correctAnim and !longJumping)) 
				{
					// Manually set wrench windup loop animation
					plr.m_Activity = ACT_RELOAD;
					plr.pev.frame = 0;
					plr.pev.sequence = 34;
					plr.ResetSequenceInfo();
				}
			}
		}
		
		// switch to looped windup animation when the time is right
		if (!state.windupLoopEntered and state.active_opts.windup_anim_loop != -1)
		{
			if (state.windupStart + state.active_opts.windup_anim_time < g_Engine.time)
			{
				state.active_opts.windup_loop_snd.play(attacker, CHAN_VOICE);	
				state.wep.SendWeaponAnim( state.active_opts.windup_anim_loop, 0, state.c_wep.w_body() );
				state.windupLoopEntered = true;
			}
		}
		
		if (!state.windupOvercharged and state.active_opts.windup_overcharge_time > 0)
		{
			if (state.windupStart + state.active_opts.windup_overcharge_time < g_Engine.time)
			{
				state.windupOvercharged = true;
				
				EHandle h_plr = attacker;
				EHandle h_wep = cast<CBaseEntity@>(state.wep);
				custom_user_effect(h_plr, h_wep, @state.active_opts.user_effect2);
				
				if (state.active_opts.windup_overcharge_anim >= 0)
					state.wep.SendWeaponAnim( state.active_opts.windup_overcharge_anim, 0, state.c_wep.w_body() );	
				
				if (state.active_opts.windup_overcharge_action != OVERCHARGE_CONTINUE)
				{
					state.windingUp = false;
					state.windupLoopEntered = false;
					state.windupSoundActive = false;
					state.windingDown = false;
					state.windupFinished = false;
					state.windupHeld = false;
					
					if (state.active_opts.windup_overcharge_action == OVERCHARGE_SHOOT)
						if (AllowedToShoot(state, state.active_opts))
							DoAttack(state, true);
					
					if (state.active_opts.windup_overcharge_anim <= 0)
						state.wep.SendWeaponAnim( state.c_wep.settings.getRandomIdleAnim(), 0, state.c_wep.w_body() );
					
					Cooldown(state, state.active_opts);
					state.active_opts.windup_snd.stop(attacker, CHAN_VOICE);
					
					state.c_wep.applyPlayerSpeedMult();
					
					return;
				}
			}
		}
		
		float p = Math.min(1.0f, timePassed / state.active_opts.windup_time); // progress
		float q = 1.0f - p; // inverse progress
		bool playWindupDuringShoot = true;
		
		if (state.windingDown)
		{
			state.windingDown = false;
			state.windupFinished = false;
			float ip = 1.0f - Math.min(1.0f, timePassed / state.active_opts.wind_down_time);
			state.windupStart = g_Engine.time - ip*state.active_opts.windup_time;
			
			if (windDownCancel and !responsiveWindup)
			{
				state.windupLoopEntered = false;
				state.windupStart = g_Engine.time; // start over if not responsive
			}
			
			if (!state.windupLoopEntered)
				state.wep.SendWeaponAnim( state.active_opts.windup_anim, 0, state.c_wep.w_body() );
			if (state.active_opts.wind_down_snd.file.Length() > 0)
			{
				state.active_opts.wind_down_snd.stop(attacker, CHAN_VOICE);
				state.active_opts.windup_snd.play(attacker, CHAN_VOICE, 1.0f, state.active_opts.windup_pitch_start);	
			}
			
			state.c_wep.applyPlayerSpeedMult();
		}
		else if (!state.windupSoundActive)
		{
			state.wep.SendWeaponAnim( state.active_opts.windup_anim, 0, state.c_wep.w_body() );
			
			state.active_opts.windup_snd.play(attacker, CHAN_VOICE, 1.0f, state.active_opts.windup_pitch_start);											
			state.windupSoundActive = true;
		}
		else if (timePassed < state.active_opts.windup_time)
		{
			p = WindupEase(p, q, state.active_opts.windup_easing, false);
			
			state.windupMultiplier = 1.0f + p*(state.active_opts.windup_mult-1.0f);
			state.windupKickbackMultiplier = 1.0f + p*(state.active_opts.windup_kick_mult-1.0f);
			float delta = state.active_opts.windup_pitch_end - state.active_opts.windup_pitch_start;
			debugln("Windup Damage Multiplier: " + state.windupMultiplier);
			int newPitch = state.active_opts.windup_pitch_start + int(delta*p + 0.5f);
			//println("T : " + newPitch);
			
			if (newPitch != state.active_opts.windup_pitch_start)
				state.active_opts.windup_snd.play(attacker, CHAN_VOICE, 1.0f, newPitch, SND_CHANGE_PITCH);
			
			int ammoUsedNow = int(p*state.active_opts.windup_cost + 0.5f);
			DepleteAmmo(state, Math.max(0, ammoUsedNow - state.windupAmmoUsed));
			state.windupAmmoUsed = Math.max(state.windupAmmoUsed, ammoUsedNow);
		}
		else if (timePassed > state.active_opts.windup_time)
		{		
			state.windupMultiplier = state.active_opts.windup_mult;
			state.windupKickbackMultiplier = state.active_opts.windup_kick_mult;
			if (!state.windupFinished)
			{
				debugln("Windup Damage Multiplier: " + state.windupMultiplier);
			}
			state.windupFinished = true;
		
			// TODO: This isn't a good way to check and will never work with tertiary windups
			bool dontShootOnWindup = state.windupOnly and (attacker.pev.button & IN_ATTACK == 0) 
									 or !AllowedToShoot(state, state.active_opts);
			
			if (!dontShootOnWindup)
			{
				state.idleShot = true;
				bool onceHeld = state.active_opts.windup_action == WINDUP_SHOOT_ONCE_IF_HELD and state.windupHeld;
				if (state.active_opts.windup_action == WINDUP_SHOOT_ONCE or onceHeld)
				{
					state.windingUp = false;
					state.windupSoundActive = false;
					if (state.active_opts.windup_snd.file.Length() > 0)
						g_SoundSystem.StopSound( attacker.edict(), CHAN_VOICE, state.active_opts.windup_snd.file);
					DoAttack(state, true);
					state.c_wep.applyPlayerSpeedMult();
				}
				if (state.active_opts.windup_action == WINDUP_SHOOT_CONSTANT)
				{
					if (state.windupHeld)
					{
						state.windupShooting = true;
						if (cooldownFinished(state))
						{
							DoAttack(state, true);
						}
					}
					else
					{
						if (!shouldWindDown)
						{
							state.windingUp = false;
							state.windupLoopEntered = false;
							state.windupFinished = false;
							state.windupSoundActive = true;
							state.windupAmmoUsed = 0;
							state.windupMultiplier = 1.0f;
							state.windupKickbackMultiplier = 1.0f;
							state.c_wep.applyPlayerSpeedMult();
						}
					}
				}
			}
			else if (state.idleShot)
			{
				state.idleShot = false;
				// go back to idling
				if (state.active_opts.windup_anim_loop != -1)
					state.wep.SendWeaponAnim( state.active_opts.windup_anim_loop, 0, state.c_wep.w_body() );
			}
		}
		
		state.c_wep.applyPlayerSpeedMult();
		cancelWindupTimeout(state);
	}
}

void cancelWindupTimeout(WeaponState& state)
{
	// only cancel if we haven't gotten an update from the player in a while (low fps and/or dropped packets)
	// 100ms delay handles 20fps with 20% dropped packets, but makes windups less responsive
	if (state.lastWindupHeld + 0.1f < g_Engine.time)
		state.windupHeld = false;
}

// Returns true when finished
bool ReloadContinuous(WeaponState& state, bool doReload=true)
{
	CBaseEntity@ attacker = state.user;
	if (state.c_wep.settings.clip_size() <= 0)
		return true;
	if (AmmoLeft(state, state.active_ammo_type) < state.c_wep.settings.reload_ammo_amt)
		return true;
	
	int reloadAmt = Math.min(state.c_wep.settings.clip_size() - state.wep.m_iClip, state.c_wep.settings.reload_ammo_amt);
	int ammoLeft = AmmoLeft(state, state.active_ammo_type);
	reloadAmt = Math.min(ammoLeft, reloadAmt);
	
	if (doReload)
	{
		state.wep.m_iClip += reloadAmt;
		ammoLeft -= reloadAmt;
		if (attacker.IsPlayer())
		{
			CBasePlayer@ plr = cast<CBasePlayer@>(attacker);
			plr.m_rgAmmo( state.active_ammo_type, ammoLeft);
		}
	}
	
	return state.wep.m_iClip >= state.c_wep.settings.clip_size() or ammoLeft < 1;
}

// do everything except actually shooting something
void AttackEffects(WeaponState& state, bool windupAttack=false)
{
	CBaseEntity@ attacker = state.user;
	
	if (FailAttack(state, state.active_opts))
		return;
	
	// kickback
	if (attacker.IsPlayer())
		Math.MakeVectors( attacker.pev.v_angle );
	else
		Math.MakeAimVectors( attacker.pev.angles );
	
	float kickScale = state.windupKickbackMultiplier;
	Vector kickVel = g_Engine.v_forward*state.active_opts.kickback.z*kickScale + 
					 g_Engine.v_up*state.active_opts.kickback.y*kickScale + 
					 g_Engine.v_right*state.active_opts.kickback.x*kickScale;
	attacker.pev.velocity = attacker.pev.velocity + kickVel;
	
	if (state.active_opts.pev.spawnflags & FL_SHOOT_QUAKE_MUZZLEFLASH != 0)
		attacker.pev.effects |= EF_MUZZLEFLASH;
	
	bool constantBeamStarted = state.minBeamTime == 0 and state.first_beam_shoot;
	bool shouldPlayAttackAnim = state.active_opts.shoot_type != SHOOT_BEAM or state.minBeamTime != 0 or constantBeamStarted;
	
	// thirperson animation
	if (attacker.IsPlayer())
	{
		CBasePlayer@ plr = cast<CBasePlayer@>(attacker);
		// play random first-person weapon animation
		if ((!state.hookAnimStarted or state.meleeHit) and shouldPlayAttackAnim)
		{
			int anim = state.meleeHit ? state.c_wep.getRandomMeleeAnim() : state.active_opts.shoot_empty_anim;
			if (!state.meleeHit and (!EmptyShoot(state) or anim < 0))
				anim = state.c_wep.getRandomShootAnim();
			state.wep.SendWeaponAnim( anim, 0, state.c_wep.w_body() ); // POSSIBLE BAWAN
		}
	
		if (windupAttack and state.c_wep.settings.player_anims == ANIM_REF_CROWBAR)
		{
			// Manually set wrench windup attack animation
			plr.m_Activity = ACT_RELOAD;
			plr.pev.frame = 0;
			plr.pev.sequence = 27;
			plr.ResetSequenceInfo();
			//plr.pev.framerate = 0.5f;
		}
		else if (shouldPlayAttackAnim)
		{
			if (state.c_wep.settings.player_anims == ANIM_REF_UZIS)
			{
				// For some reason the dual uzi shooting animation uses a different reference set.
				plr.m_Activity = ACT_RELOAD;
				plr.pev.frame = 0;
				plr.pev.sequence = 132;
				plr.ResetSequenceInfo();
				//plr.pev.framerate = 0.5f;
			}
			else
				plr.SetAnimation( PLAYER_ATTACK1 );
		}
		
		// recoil
		plr.pev.punchangle.x = -Math.RandomFloat(state.active_opts.recoil.x, state.active_opts.recoil.y);
		plr.pev.punchangle.y = 0;//Math.RandomLong(-180, 180);
		plr.pev.punchangle.z = 0;//Math.RandomLong(-180, 180);
		//plr.pev.punchangle.y = 0;
		
		// idle random time after shooting
		state.wep.m_flTimeWeaponIdle = state.c_wep.WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( plr.random_seed,  10, 15 );
		
		// monster reactions to shooting or danger
		int hmode = state.active_opts.heal_mode;
		bool harmlessWep = hmode == HEAL_ALL or state.active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0;
		if (!state.healedTarget and !harmlessWep)
		{
			// get spooked
			plr.m_iWeaponFlash = BRIGHT_GUN_FLASH;
			plr.m_iWeaponVolume = NORMAL_GUN_VOLUME;
			plr.m_iExtraSoundTypes = bits_SOUND_COMBAT;//bits_SOUND_DANGER;
			plr.m_flStopExtraSoundTime = state.c_wep.WeaponTimeBase() + 0.2;
		}
	}
	
	// random shoot sound
	state.shootCount++;
	bool meleeSkip = state.active_opts.shoot_type == SHOOT_MELEE;
	bool noSndOverlap = state.active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP != 0;
	bool constantBeaming = state.beam_active and state.minBeamTime == 0 and !state.first_beam_shoot;
	meleeSkip = meleeSkip and noSndOverlap;
	if (!meleeSkip and !state.shootingHook and !constantBeaming)
	{
		WeaponSound@ snd = state.active_opts.getRandomShootSound();
		if (EmptyShoot(state) and state.active_opts.shoot_empty_snd.file.Length() > 0)
			@snd = @state.active_opts.shoot_empty_snd;
		SOUND_CHANNEL channel = state.shootCount % 2 == 0 or noSndOverlap ? CHAN_WEAPON : CHAN_VOICE;
		if (state.active_opts.shoot_type == SHOOT_MELEE or (state.active_opts.shoot_type == SHOOT_BEAM and state.minBeamTime == 0))
			channel = CHAN_WEAPON;
		if (snd !is null)
			snd.play(attacker, channel);
		@state.lastShootSnd = @snd;
	}
	
	// eject shell
	if (state.active_opts.shell_type != SHELL_NONE)
	{
		// TODO: Monster shell delay
		if (state.active_opts.shell_delay == 0 || !attacker.IsPlayer())
			EjectShell(state);
		else
		{
			state.needShellEject = true;
			state.ejectShellTime = state.c_wep.WeaponTimeBase() + state.active_opts.shell_delay;
			setNextAttackThink(state, g_Engine.time);
		}
	}
	
	// muzzle flash
	int flash_size = int(state.active_opts.muzzle_flash_adv.x);
	int flash_life = int(state.active_opts.muzzle_flash_adv.y);
	int flash_decay = int(state.active_opts.muzzle_flash_adv.z);
	Color flash_color = Color(state.active_opts.muzzle_flash_color);
	bool isBlack = flash_color.r == 0 and flash_color.g == 0 and flash_color.b == 0;
	if (flash_life > 0 and flash_size > 0 and !isBlack)
	{
		Vector lpos = attacker.pev.origin + g_Engine.v_forward * 50;
		te_dlight(lpos, flash_size, flash_color, flash_life, flash_decay);
		if (attacker !is null)
			te_elight(attacker, lpos, flash_size*10, flash_color, flash_life, flash_decay);
	}
	
	if (noSndOverlap)
	{
		if (state.lastCooldownSnd !is null)
			state.lastCooldownSnd.stop(attacker, CHAN_VOICE);
	}
	
	// cooldown effect
	if (state.active_opts.user_effect3 !is null)
		state.nextCooldownEffect = g_Engine.time + state.active_opts.cooldown + state.active_opts.user_effect3.delay;
	
	Cooldown(state, state.active_opts);
	
	// shoot effect
	EHandle h_plr = attacker;
	EHandle h_wep = state.wep;
	custom_user_effect(h_plr, h_wep, @state.active_opts.user_effect1);
	
	int ammo_cost = state.partialAmmoUsage != -1 ? state.partialAmmoUsage : state.active_opts.ammo_cost;
	DepleteAmmo(state, ammo_cost);
	
	// remove weapon if exhaustable and ammo is empty
	if (attacker.IsPlayer())
	{
		bool emptyClip = state.c_wep.settings.clip_size() <= 0 or state.wep.m_iClip <= 0;
		if (AmmoLeft(state, state.active_ammo_type) <= 0 and emptyClip and 
			state.c_wep.settings.pev.spawnflags & FL_WEP_EXHAUSTIBLE != 0)
		{
			if (state.liveProjectiles > 0 and state.c_wep.settings.pev.spawnflags & FL_WEP_WAIT_FOR_PROJECTILES != 0)
			{
				// kill self after projectiles die
				state.deathTime = state.c_wep.WeaponTimeBase() + state.active_opts.cooldown;
			}
			else
			{
				state.wep.m_flNextPrimaryAttack = state.c_wep.WeaponTimeBase() + state.active_opts.cooldown;
				state.wep.m_flNextSecondaryAttack = state.c_wep.WeaponTimeBase() + state.active_opts.cooldown;
				state.wep.m_flNextTertiaryAttack = state.c_wep.WeaponTimeBase() + state.active_opts.cooldown;
				g_Scheduler.SetTimeout( "removeWeapon", state.active_opts.cooldown, @state.wep );
			}
		}
	}
}

void DoAttack(WeaponState& state, bool windupAttack=false)
{	
	state.reloading = 0;
	state.reloading2 = 0;
	state.healedTarget = false;
	state.abortAttack = false;
	state.partialAmmoUsage = -1;
	
	if (!windupAttack)
	{
		state.windupMultiplier = 1.0f;
		state.partialAmmoModifier = 1.0f;
	}
	if (state.active_opts.pev.spawnflags & FL_SHOOT_PARTIAL_AMMO_SHOOT != 0)
	{
		if (state.c_wep.settings.clip_size() > 0)
			state.partialAmmoModifier = float(state.wep.m_iClip) / float(state.active_opts.ammo_cost);
		else
			state.partialAmmoModifier = AmmoLeft(state, state.active_ammo_type) / float(state.active_opts.ammo_cost);
		state.partialAmmoModifier = Math.min(1.0f, state.partialAmmoModifier);
	}
	
	// shoot stuff
	switch(state.active_opts.shoot_type)
	{
		case SHOOT_MELEE:
		case SHOOT_BULLETS: ShootBullets(state); break;
		case SHOOT_PROJECTILE: ShootProjectile(state); break;
		case SHOOT_BEAM: ShootBeam(state); break;
	}
	if (state.active_opts.hook_type != HOOK_DISABLED)
		ShootHook(state);
	DetonateSatchels(state);
	
	AttackEffects(state, windupAttack);
}

void Cooldown(WeaponState& state, weapon_custom_shoot@ opts, bool failureCooldown=false)
{
	if (!state.user.IsPlayer())
		return; // TODO: Monster cooldown?
	// cooldown
	float cooldownVal = failureCooldown ? opts.cooldown_fail : opts.cooldown;
	if (opts.shoot_type == SHOOT_MELEE and (!state.meleeHit or state.abortAttack))
		cooldownVal = opts.melee_miss_cooldown;
	if (state.windupOvercharged)
		cooldownVal = opts.windup_overcharge_cooldown;
	if (state.beam_active and state.minBeamTime == 0)
		cooldownVal = opts.beam_ammo_cooldown;
	//self.m_flNextPrimaryAttack = WeaponTimeBase() + cooldownVal;
	//self.m_flNextSecondaryAttack = WeaponTimeBase() + cooldownVal;
	//self.m_flNextTertiaryAttack = WeaponTimeBase() + cooldownVal;
	state.nextShootTime = state.c_wep.WeaponTimeBase() + cooldownVal;
}

bool FailAttack(WeaponState& state, weapon_custom_shoot@ opts)
{
	if (!state.abortAttack)
		return false;

	WeaponSound@ snd = opts.getRandomShootFailSound();
	if (snd !is null)
		snd.play(state.user, CHAN_WEAPON);
		
	Cooldown(state, opts, true);
	return true;
}

Vector getGunPos(CBaseEntity@ ent)
{
	if (ent.IsPlayer())
		return cast<CBasePlayer@>(ent).GetGunPosition();
	else if (ent.IsMonster())
	{
		// assume it's a custom monster
		return cast<MonsterCustomBase@>(CastToScriptClass(ent)).attackPosition();
	}
	return ent.pev.origin;
}

bool EmptyShoot(WeaponState& state)
{
	// TODO: Monster ammo
	if (state.user.IsPlayer())
	{
		bool isPrimary = state.active_opts is null or state.active_opts.isPrimary();
		int clip_size = isPrimary ? state.c_wep.settings.clip_size() : state.c_wep.settings.clip_size2;
		int clip = isPrimary ? state.wep.m_iClip : state.wep.m_iClip2;
		
		return ((clip_size > 0 and clip == 0) or 
				(clip_size == 0 and AmmoLeft(state, state.active_ammo_type) == 0));
	}
	return false;
}

void EjectShell(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	if (state.active_opts.shell_delay > 0)
		state.active_opts.shell_delay_snd.play(attacker, CHAN_ITEM);
		
	Math.MakeVectors( attacker.pev.v_angle ); // todo: monster version
						  
	Vector ofs = state.active_opts.shell_offset;
	Vector vel = state.active_opts.shell_vel;
	ofs = ofs.x*g_Engine.v_right + ofs.y*g_Engine.v_up + ofs.z*g_Engine.v_forward;
	vel = vel.x*g_Engine.v_right + vel.y*g_Engine.v_up + vel.z*g_Engine.v_forward;
	float speed = vel.Length();
	float spread = state.active_opts.shell_spread;
	vel = resizeVector(spreadDir(vel, spread), speed + Math.RandomFloat(-spread, spread));
	
	Vector shellOri = getGunPos(attacker) + ofs;
	Vector shellVel = state.user.pev.velocity + vel;
	float shellRot = 1000; // has no effect... broken paramater?
	TE_BOUNCE bounceSnd = state.active_opts.shell_type == SHELL_SHOTGUN ? TE_BOUNCE_SHOTSHELL : TE_BOUNCE_SHELL;
	
	g_EntityFuncs.EjectBrass(shellOri, shellVel, shellRot, state.active_opts.shell_idx, bounceSnd);
	if (debug_mode)
		te_beampoints(shellOri, shellOri + resizeVector(shellVel, 32));
}

void DepleteAmmo(WeaponState& state, int amt)
{
	CBaseEntity@ attacker = state.user;
	if (state.active_ammo_type == -1) return;
	
	if (attacker.IsPlayer())
	{
		CBasePlayer@ plr = cast<CBasePlayer@>(attacker);
		bool shouldUseClip = state.active_opts.isPrimary() or state.active_ammo_type == state.wep.m_iPrimaryAmmoType;
		bool shouldUseClip2 = state.active_opts.isSecondary() or state.active_ammo_type == state.wep.m_iSecondaryAmmoType;
		if (state.wep.m_iClip > 0 and shouldUseClip) 
			state.wep.m_iClip -= amt;
		else if (state.wep.m_iClip2 > 0 and shouldUseClip2)
			state.wep.m_iClip2 -= amt;
		else // gun doesn't use a clip
			plr.m_rgAmmo( state.active_ammo_type, Math.max(0, AmmoLeft(state, state.active_ammo_type)-amt));
			
		if( plr.m_rgAmmo(state.active_ammo_type) <= 0 )
			// HEV suit - indicate out of ammo condition
			plr.SetSuitUpdate( "!HEV_AMO0", false, 0 );
	}
}

int AmmoLeft(WeaponState& state, int ammoType)
{
	if (ammoType == -1) return -1; // doesn't use ammo
	if (state.user.IsPlayer())
	{
		CBasePlayer@ plr = cast<CBasePlayer@>(state.user);
		return Math.max(0, plr.m_rgAmmo( ammoType ));
	}
	return 13378;
}

void ShootBullets(WeaponState& state)
{
	if (state.active_opts.bullet_delay > 0 and state.active_opts.bullets > 1)
	{
		state.burstFiring = true;
		ShootOneBullet(state);
		state.numBurstFires = 1;
		state.nextBurstFire = g_Engine.time + state.active_opts.bullet_delay;
		setNextAttackThink(state, g_Engine.time);
		return;
	}
	for (int i = 0; i < state.active_opts.bullets; i++)
	{
		ShootOneBullet(state);
	}
}

void ShootBeam(WeaponState& state)
{
	if (state.beam_active)
		return;
	
	BeamOptions@ beam_opts = state.active_opts.beams[0];
	
	for (uint i = 0; i < state.beams.size(); i++)
		state.beams[i].resize(state.active_opts.beam_ricochet_limit+1);
	state.beamHits.resize(state.active_opts.beam_ricochet_limit+1);
	
	state.beam_active = true;
	state.first_beam_shoot = true;
	state.beamStartTime = g_Engine.time;
	state.minBeamTime = Math.max(state.active_opts.beams[0].time, state.active_opts.beams[1].time);
	setNextAttackThink(state, g_Engine.time);
	
	// constant beam sounds
	state.hookAnimStarted = false;
	state.hookAnimStartTime = g_Engine.time + state.active_opts.hook_delay;
}

void UpdateBeams(WeaponState& state)
{			
	CBaseEntity@ attacker = state.user;
	bool doDamage = state.lastBeamDamage + state.active_opts.beam_impact_speed < g_Engine.time;
	if (doDamage)
		state.lastBeamDamage = g_Engine.time;
	
	int MAX_BEAMS = 2;
	
	array<BeamShot> beamShots = CalcBeamShots(state);
	
	for (int i = 0; i < state.active_opts.beam_ricochet_limit+1; i++)
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
						AttackMonster(state, shot.startPos, shot.tr);	
				}
								
				EHandle h_plr = attacker;
				EHandle h_ent = shot.ent;
				if (state.minBeamTime > 0 or doDamage)
				{
					DecalTarget dt = getProjectileDecalTarget(null, shot.tr.vecEndPos, 32);
					weapon_custom_effect@ ef;
					@ef = i == int(beamShots.length()-1) ? @state.active_opts.effect1 : @state.active_opts.effect2;
					Vector dir = (shot.tr.vecEndPos - shot.startPos).Normalize();
					custom_effect(shot.tr.vecEndPos, ef, EHandle(), h_ent, h_plr, dir, state.active_opts.friendly_fire ? 1 : 0, dt);
				}
			}
			
			// create or update beam ents
			for (int k = 0; k < MAX_BEAMS; k++)
			{
				BeamOptions@ beam_opts = state.active_opts.beams[k];
	
				if (beam_opts.type == BEAM_DISABLED)
					continue;
				
				CBeam@ ricobeam;
				
				// create beam for current slot, if needed
				if (!state.beams[k][i])
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
						ricobeam.SetEndEntity(attacker);
						ricobeam.SetEndAttachment(1);
					}
					
					ricobeam.SetNoise(beam_opts.noise);
					ricobeam.SetWidth(beam_opts.width);
					ricobeam.SetColor(beam_opts.color.r, beam_opts.color.g, beam_opts.color.b);
					ricobeam.SetBrightness(beam_opts.color.a);
					ricobeam.SetScrollRate(beam_opts.scrollRate);
					
					state.beams[k][i] = ricobeam;
				}
				
				CBaseEntity@ ricobeamEnt = state.beams[k][i];
				@ricobeam = cast<CBeam@>(@ricobeamEnt);
				
				// Update position of beam
				if (i == 0)
					ricobeam.SetStartPos(shot.tr.vecEndPos);
				else
					ricobeam.PointsInit(shot.tr.vecEndPos, shot.startPos);
					
				// do beam animations
				if (beam_opts.alt_mode != BEAM_ALT_DISABLED)
				{
					int t = int((g_Engine.time - state.beamStartTime) * 10000); // convert to int for modulo op later
					int freq = int(beam_opts.alt_time * 10000);  // time to alternate (half a cycle)
					float p = float(t % freq) / float(freq);    // progress
					float q = 1.0f - p; 					    // progress left
					
					switch(beam_opts.alt_mode)
					{
						case BEAM_ALT_LINEAR:
						case BEAM_ALT_LINEAR_TOGGLE: p = p; break;
						case BEAM_ALT_TOGGLE: p = (p < 0.5) ? 0 : 1; break;
						case BEAM_ALT_EASE:   p = p*p*p / (p*p*p + q*q*q); break;
						case BEAM_ALT_RANDOM: p = Math.RandomFloat(0, 1);; break;
					}
					if (beam_opts.alt_mode != BEAM_ALT_LINEAR_TOGGLE and t % (freq*2) >= freq)
						p = 1.0f - p;
					
					
					{	// color interp
						Color A = beam_opts.color;
						Color B = beam_opts.alt_color;
						int dr = int( float( int(B.r) - int(A.r) )*p + 0.5 );
						int dg = int( float( int(B.g) - int(A.g) )*p + 0.5 );
						int db = int( float( int(B.b) - int(A.b) )*p + 0.5 );
						int da = int( float( int(B.a) - int(A.a) )*p + 0.5 );
						Color C = Color(A.r + dr, A.g + dg, A.b + db, A.a + da);
						ricobeam.SetColor(C.r, C.g, C.b);
						ricobeam.SetBrightness(C.a);
					}
					{	// width interp
						int a = beam_opts.width;
						int b = beam_opts.alt_width;
						int d = int( float(b - a)*p + 0.5 );
						ricobeam.SetWidth(a + d);
					}
					{	// noise interp
						int a = beam_opts.noise;
						int b = beam_opts.alt_noise;
						int d = int( float(b - a)*p + 0.5 );
						ricobeam.SetNoise(a + d);
					}
					{	// scroll interp
						int a = beam_opts.scrollRate;
						int b = beam_opts.alt_scrollRate;
						int d = int( float(b - a)*p + 0.5 );
						ricobeam.SetScrollRate(a + d);
					}
				}
			}
			
			// create or update impact sprites
			if (state.active_opts.beam_impact_spr.Length() > 0)
			{
				bool shouldImpact = shot.ent !is null;
				shouldImpact = shouldImpact ;
				
				if (shot.ent !is null and (shot.ent.IsMonster() or isBreakableEntity(shot.ent)))
				{
					// kill sprite if it's currently expanding
					CBaseEntity@ beamEnt = state.beamHits[i];
					if (state.beamHits[i] and beamEnt.pev.deadflag != 0)
						g_EntityFuncs.Remove( state.beamHits[i] );
					
					CSprite@ impact;
					if (!state.beamHits[i])
					{
						@impact = g_EntityFuncs.CreateSprite( state.active_opts.beam_impact_spr, 
																   shot.tr.vecEndPos, true, 10 );
						impact.pev.rendermode = kRenderGlow;
						impact.pev.renderamt = state.active_opts.beam_impact_spr_color.a;
						impact.pev.scale = state.active_opts.beam_impact_spr_scale;
						impact.pev.framerate = 0;
						impact.pev.renderfx = kRenderFxNoDissipation;
						impact.pev.movetype = MOVETYPE_NONE;
						impact.pev.rendercolor = state.active_opts.beam_impact_spr_color.getRGB();
						state.beamHits[i] = impact;
					}
					@beamEnt = state.beamHits[i];
					@impact = cast<CSprite@>(@beamEnt);
					
					impact.pev.origin = shot.tr.vecEndPos;
					
					// manual frame increments since framerate is broken (stutter if not multiple of 5)
					if (impact.Frames() > 0)
					{
						impact.pev.frame += state.active_opts.beam_impact_spr_fps*g_Engine.frametime;
						impact.pev.frame = impact.pev.frame % impact.Frames();
					}
				}
				else if (state.beamHits[i])
					g_EntityFuncs.Remove( state.beamHits[i] );
			}
		}
		else 
		{
			// destroy beams that are no longer active
			for (int k = 0; k < MAX_BEAMS; k++)
			{
				if (state.beams[k][i])
					g_EntityFuncs.Remove( state.beams[k][i] );
			}
			// destroy the impact sprites too
			if (state.beamHits[i])
				g_EntityFuncs.Remove( state.beamHits[i] );
		}
		
	}
}

void DestroyBeams(WeaponState& state)
{
	if (!state.beam_active)
		return;
	for (int i = 0; i < state.active_opts.beam_ricochet_limit+1; i++)
	{
		for (uint k = 0; k < state.beams.length(); k++)
		{
			if (state.beams[k][i])
				g_EntityFuncs.Remove( state.beams[k][i] );
		}
		if (state.beamHits[i])
		{
			CBaseEntity@ beamEnt = state.beamHits[i];
			CSprite@ beam = cast<CSprite@>(@beamEnt);
		
			beam.Expand(16.0f, 512.0f); // autokills the sprite when renderamt <= 0
			beam.pev.deadflag = 1; // indicate that this sprite should be dead soon
		}
	}
}

void DestroyBeam(WeaponState& state, int beamId)
{
	for (int i = 0; i < state.active_opts.beam_ricochet_limit+1; i++)
		if (state.beams[beamId][i])
			g_EntityFuncs.Remove( state.beams[beamId][i] );
}

void CancelBeam(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	DestroyBeams(state);
	bool beamWasActive = state.beam_active;
	state.beam_active = false;
	state.hookAnimStarted = false;
	
	if (state.active_opts is null) // weapon was never fired
		return;
	
	if (beamWasActive and state.minBeamTime == 0)
	{
		if (state.lastShootSnd !is null)
			state.lastShootSnd.stop(attacker, CHAN_VOICE);
		state.active_opts.hook_snd.stop(attacker, CHAN_VOICE);
		state.active_opts.hook_snd2.play(attacker, CHAN_VOICE);
		if (attacker.IsPlayer())
			state.wep.SendWeaponAnim( state.c_wep.settings.getRandomIdleAnim(), 0, state.c_wep.w_body() );
		//self.SendWeaponAnim( state.active_opts.hook_anim2, 0, 0 );
		//self.m_flTimeWeaponIdle = g_Engine.time + state.active_opts.hook_delay2; // idle after this	
		Cooldown(state, state.active_opts);
	}	
}

void CreateUserBeam(WeaponState& state, weapon_custom_user_effect@ effect)
{
	CBaseEntity@ attacker = state.user;
	CBeam@ ubeam = g_EntityFuncs.CreateBeam( effect.beam_spr, 16 );
	int flags = 0;
	if (effect.beam_type == BEAM_SPIRAL or effect.beam_type == BEAM_SPIRAL_OPAQUE)
		flags |= BEAM_FSINE;
	if (effect.beam_type == BEAM_LINEAR_OPAQUE or effect.beam_type == BEAM_SPIRAL_OPAQUE)
		flags |= BEAM_FSOLID;
	ubeam.SetFlags( flags );
	
	// calculate start/end points
	Math.MakeVectors( attacker.pev.v_angle );			  
	Vector ofs1 = effect.beam_start;
	Vector ofs2 = effect.beam_end;
	Vector gun = getGunPos(attacker);
	Vector vecStart = gun + ofs1.x*g_Engine.v_right + ofs1.y*g_Engine.v_up + ofs1.z*g_Engine.v_forward;
	Vector vecEnd   = gun + ofs2.x*g_Engine.v_right + ofs2.y*g_Engine.v_up + ofs2.z*g_Engine.v_forward;
	
	// First beam is attached to player weapon bone
	switch (effect.beam_mode)
	{
		case UBEAM_ATTACH_ATTACH:
			ubeam.SetType(BEAM_ENTS);
			ubeam.SetStartEntity(attacker);
			ubeam.SetStartAttachment(int(effect.beam_start.x));
			ubeam.SetEndEntity(attacker);
			ubeam.SetEndAttachment(int(effect.beam_end.x));
			break;
		case UBEAM_ATTACH_POINT:
			ubeam.SetType(BEAM_ENTPOINT);
			ubeam.SetStartEntity(attacker);
			ubeam.SetStartAttachment(int(effect.beam_start.x));
			ubeam.SetEndPos(vecEnd);
			break;
		case UBEAM_POINT_POINT:
			ubeam.SetType(BEAM_POINTS);
			ubeam.SetStartPos(vecStart);
			ubeam.SetEndPos(vecEnd);
			break;
	}
	
	ubeam.SetNoise(effect.beam_noise);
	ubeam.SetWidth(effect.beam_width);
	ubeam.SetColor(effect.beam_color.r, effect.beam_color.g, effect.beam_color.b);
	ubeam.SetBrightness(effect.beam_color.a);
	ubeam.SetScrollRate(effect.beam_scroll);
	
	EHandle h_ubeam = ubeam;
	state.ubeams.insertLast(h_ubeam);
	
	if (effect.beam_time > 0)
	{
		ubeam.pev.max_health = g_Engine.time + effect.beam_time;
		setNextAttackThink(state, g_Engine.time);
	}
}

// Calculate beam ricochets
array<BeamShot> CalcBeamShots(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	array<BeamShot> shots;
				
	Math.MakeVectors( attacker.pev.v_angle ); // TODO: Monster angles
	Vector vecAiming = spreadDir(g_Engine.v_forward, state.active_opts.bullet_spread, state.active_opts.bullet_spread_func);
		
	Vector vecSrc = getGunPos(attacker);
	Vector vecEnd = vecSrc + vecAiming*state.active_opts.max_range;

	edict_t@ traceEnt = attacker.edict();
	
	for (int i = 0; i < state.active_opts.beam_ricochet_limit+1; i++)
	{			
		TraceResult tr;
		edict_t@ ignoreEnt = i == 0 ? attacker.edict() : state.wep.edict();
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
			if (ricAngle > state.active_opts.rico_angle)
				break;
			Vector r = (dir - 2*(dotdir)*n);
			
			// set up trace points for next iteration
			vecSrc = tr.vecEndPos;
			vecEnd = vecSrc + r*state.active_opts.max_range;
		}
		else
			break;
	}
	
	return shots;
}

CBaseEntity@ ShootCustomProjectile(WeaponState& state, string classname, Vector ori, Vector vel, Vector angles)
{
	if (classname.Length() == 0)
		return null;
		
	ProjectileOptions@ options = @state.active_opts.projectile;
	
	dictionary keys;
	Vector boltAngles = angles * Vector(-1, 1, 1);
	keys["origin"] = ori.ToString();
	keys["angles"] = boltAngles.ToString();
	keys["velocity"] = vel.ToString();
	
	// replace model or use error.mdl if no model specified and not a standard entity
	string model = options.model.Length() > 0 ? options.model : "models/error.mdl";
	if (options.type == PROJECTILE_CUSTOM or options.type == PROJECTILE_OTHER and options.model.Length() > 0) 
		keys["model"] = model;
	if (options.type == PROJECTILE_WEAPON)
		keys["model"] = state.c_wep.settings.wpn_w_model;
	if (options.type == PROJECTILE_CUSTOM and options.model.Length() == 0)
		keys["rendermode"] = "1"; // don't render the model
		
	CBaseEntity@ shootEnt = g_EntityFuncs.CreateEntity(classname, keys, false);	
	@shootEnt.pev.owner = state.user.edict(); // do this or else crash
	WeaponCustomProjectile@ shootEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(shootEnt));
	if (shootEnt_c !is null)
	{
		@shootEnt_c.shoot_opts = @state.active_opts;
		if (state.c_wep !is null) // TODO: Monster that throws crowbars
			shootEnt_c.pickup_classname = state.c_wep.settings.weapon_classname;
	}
	
	g_EntityFuncs.DispatchSpawn(shootEnt.edict());
	
	return shootEnt;
}

CBaseEntity@ ShootProjectile(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	Math.MakeVectors( attacker.pev.v_angle ); // TODO: monster angles
	Vector vecAiming = spreadDir(g_Engine.v_forward, state.active_opts.bullet_spread, state.active_opts.bullet_spread_func);
	
	ProjectileOptions@ options = @state.active_opts.projectile;
	
	// Get amount of player velocity to add to projectile.
	Vector inf = options.player_vel_inf;
	Vector pvel = attacker.pev.velocity;
	pvel = g_Engine.v_right * DotProduct(g_Engine.v_right, pvel)*inf.x +
		   g_Engine.v_up * DotProduct(g_Engine.v_up, pvel)*inf.y +
		   g_Engine.v_forward * DotProduct(g_Engine.v_forward, pvel)*inf.z;
		   
	Vector projectile_velocity = g_Engine.v_right*options.speed*options.dir.x +
								 Vector(0,0,1)*options.speed*options.dir.y +
								 vecAiming*options.speed*options.dir.z + 
								 pvel;
	
	Vector ofs = g_Engine.v_right*options.offset.x + g_Engine.v_up*options.offset.y + g_Engine.v_forward*options.offset.z;
	Vector projectile_ori = getGunPos(attacker) + ofs;
	float grenadeTime = options.life != 0 ? options.life : 3.5f; // timed grenades only
	if (state.active_opts.windup_time > 0)
		grenadeTime = Math.max(0, grenadeTime - (g_Engine.time - state.windupStart));
	
	CGrenade@ nade = null;
	CBaseEntity@ shootEnt = null;
	if (options.type == PROJECTILE_ARGRENADE)
		@nade = g_EntityFuncs.ShootContact( attacker.pev, projectile_ori, projectile_velocity );
	else if (options.type == PROJECTILE_BANANA)
		@nade = g_EntityFuncs.ShootBananaCluster( attacker.pev, projectile_ori, projectile_velocity );
	else if (options.type == PROJECTILE_BOLT)
		ShootCustomProjectile(state, "crossbow_bolt", projectile_ori, projectile_velocity, attacker.pev.v_angle);
	else if (options.type == PROJECTILE_HVR)
		ShootCustomProjectile(state, "hvr_rocket", projectile_ori, projectile_velocity, attacker.pev.v_angle);
	else if (options.type == PROJECTILE_SHOCK)
		ShootCustomProjectile(state, "shock_beam", projectile_ori, projectile_velocity, attacker.pev.v_angle);
	else if (options.type == PROJECTILE_HORNET)
		ShootCustomProjectile(state, "playerhornet", projectile_ori, projectile_velocity, attacker.pev.v_angle);
	else if (options.type == PROJECTILE_DISPLACER)
		@shootEnt = g_EntityFuncs.CreateDisplacerPortal( projectile_ori, projectile_velocity, attacker.edict(), 250, 250 );
	else if (options.type == PROJECTILE_GRENADE)
		@nade = g_EntityFuncs.ShootTimed( attacker.pev, projectile_ori, projectile_velocity, grenadeTime );
	else if (options.type == PROJECTILE_MORTAR)
		@nade = g_EntityFuncs.ShootMortar( attacker.pev, projectile_ori, projectile_velocity );
	else if (options.type == PROJECTILE_RPG)
	{
		@shootEnt = g_EntityFuncs.CreateRPGRocket(projectile_ori, attacker.pev.v_angle, attacker.edict());
		shootEnt.pev.velocity = shootEnt.pev.velocity + projectile_velocity;
	}
	else if (options.type == PROJECTILE_WEAPON)
		@shootEnt = ShootCustomProjectile(state, "custom_projectile", projectile_ori, projectile_velocity, attacker.pev.v_angle);
	else if (options.type == PROJECTILE_TRIPMINE)
	{
		// assumes MakeVectors was already called
		Vector vecSrc	 = getGunPos(attacker);
		
		// Find a good tripmine location
		TraceResult tr;
		Vector vecEnd = vecSrc + vecAiming * state.active_opts.max_range;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, attacker.edict(), tr );
		if (tr.flFraction >= 1.0 and state.active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_MISS != 0)
		{
			state.abortAttack = true;
		}
		else
		{
			Vector tripOri = tr.vecEndPos + tr.vecPlaneNormal*8;
			Vector angles;
			g_EngineFuncs.VecToAngles(tr.vecPlaneNormal, angles);
			angles.x *= -1; // not sure why hlsdk doesn't do this
			string tripClass = options.entity_class.Length() > 0 ? options.entity_class : "monster_tripmine";
			
			@shootEnt = ShootCustomProjectile(state, tripClass, tripOri, projectile_velocity, angles);
		}
		
	}
	else if (options.type == PROJECTILE_CUSTOM)
		@shootEnt = ShootCustomProjectile(state, "custom_projectile", projectile_ori, projectile_velocity, attacker.pev.v_angle);
	else if (options.type == PROJECTILE_OTHER)
		@shootEnt = ShootCustomProjectile(state, options.entity_class, projectile_ori, projectile_velocity, attacker.pev.v_angle);
	else
		println("Unknown projectile type: " + options.type);
		
	if (nade !is null)
		@shootEnt = cast<CBaseEntity@>(nade);
		
	if (shootEnt !is null)
	{				
		if (options.follow_mode != FOLLOW_NONE)
		{
			EHandle h_plr = attacker;
			EHandle h_proj = shootEnt;
			float dur = options.follow_time.y;
			g_Scheduler.SetTimeout("projectile_follow_aim", options.follow_time.x, h_plr, h_proj, @state.active_opts, dur);
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
			keyvalues["renderamt"] = "" + options.sprite_color.a;
			keyvalues["rendercolor"] = options.sprite_color.ToString();
			keyvalues["scale"] = "" + options.sprite_scale;
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
			g_Scheduler.SetTimeout("killProjectile", options.life, mdlHandle, sprHandle, state.active_opts);
			
		// TODO: Monster projectile limits
		if (state.c_wep !is null and (state.c_wep.settings.max_live_projectiles > 0 or state.c_wep.settings.pev.spawnflags & FL_WEP_WAIT_FOR_PROJECTILES != 0))
		{
			state.liveProjectiles++;
			MonitorProjectileLife(state, mdlHandle);
		}
		
		shootEnt.pev.avelocity = options.avel;
		
		// TODO: Allow setting projectile class and ally status
		int rel = attacker.IRelationship(shootEnt);
		bool isFriendly = rel == R_AL or rel == R_NO;
		if (shootEnt.IsMonster() and !isFriendly)
			shootEnt.SetPlayerAlly(true);
			
		//shootEnt.pev.dmg = state.active_opts.damage;
		// TODO: health set here
		shootEnt.pev.friction = 1.0f - options.elasticity;
		shootEnt.pev.gravity = options.gravity;
		
		if (shootEnt.pev.gravity == 0)
		{
			if (options.world_event != PROJ_ACT_BOUNCE and options.monster_event != PROJ_ACT_BOUNCE)
				shootEnt.pev.movetype = MOVETYPE_FLY; // fixes jittering in grapple tongue shoot
			else
				shootEnt.pev.movetype = MOVETYPE_BOUNCEMISSILE;
		}
	}
	
	// remove weapon from player if they threw it
	if (options.type == PROJECTILE_WEAPON)
	{
		g_Scheduler.SetTimeout( "removeWeapon", 0, @state.wep );
	}
	
	return shootEnt;
}

void MonitorProjectileLife(WeaponState& state, EHandle h_proj)
{
	bool dead = false;
	if (!h_proj)
		dead = true;
		
	CBaseEntity@ proj = h_proj;
	if (proj is null)
		dead = true;
	
	if (dead)
	{
		state.liveProjectiles--;
		
		if (state.liveProjectiles <= 0 and AmmoLeft(state, state.active_ammo_type) <= 0 and state.wep.m_iClip < 0)
		{
			g_Scheduler.SetTimeout( "removeWeapon", Math.min(0, (state.deathTime - g_Engine.time)), @state.wep );
		}
	}
	else
		g_Scheduler.SetTimeout("MonitorProjectileLife", 0.1, @state, h_proj);
}

void DetonateSatchels(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	if (state.active_opts.pev.spawnflags & FL_SHOOT_DETONATE_SATCHELS == 0)
		return;		
	
	//g_EntityFuncs.UseSatchelCharges(attacker.pev, SATCHEL_DETONATE);
	// ^ would be nice if that actually worked
	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "monster_satchel"); 

		if (ent !is null)
		{				
			CBaseEntity@ owner = g_EntityFuncs.Instance( state.wep.pev.owner );
			if (owner.entindex() == attacker.entindex())
				ent.Use(attacker, attacker, USE_TOGGLE, 0);
		}
	} while (ent !is null);
}

void ShootHook(WeaponState& state)
{
	CBaseEntity@ attacker = state.user;
	if (!state.shootingHook)
	{
		state.shootingHook = true;
		state.windupHeld = true;
		state.lastWindupHeld = g_Engine.time;
		state.hookAnimStarted = false;
		state.hookAnimStartTime = g_Engine.time + state.active_opts.hook_delay;
		
		state.hook_ent = ShootProjectile(state);
		
		CBeam@ beam;
		if (!state.hook_beam)
		{
			BeamOptions@ beam_opts = state.active_opts.beams[0];
			@beam = g_EntityFuncs.CreateBeam( beam_opts.sprite, 16 );
			beam.SetType(BEAM_ENTS);
			beam.SetEndEntity(attacker);
			beam.SetEndAttachment(1);
			beam.SetStartEntity(state.hook_ent);
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
			state.hook_beam = beam;
		}
		
		CBaseEntity@ beamEnt = state.hook_beam;
		@beam = cast<CBeam@>(@beamEnt);
		
		setNextAttackThink(state, g_Engine.time);
	}
}	

void ShootOneBullet(WeaponState& state)
{	
	CBaseEntity@ attacker = state.user;
	Vector vecSrc = getGunPos(attacker);
	if (attacker.IsPlayer())
		Math.MakeVectors( attacker.pev.v_angle );
	else
		Math.MakeAimVectors( attacker.pev.angles );
	Vector vecAiming = spreadDir(g_Engine.v_forward, state.active_opts.bullet_spread, state.active_opts.bullet_spread_func);
	
	// Do the bullet collision
	TraceResult tr;
	Vector vecEnd = vecSrc + vecAiming * state.active_opts.max_range;
	g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, attacker.edict(), tr );
	//te_beampoints(vecSrc, vecEnd);
	
	if ( tr.flFraction >= 1.0 and state.active_opts.shoot_type == SHOOT_MELEE)
	{
		// This does a trace in the form of a box so there is a much higher chance of hitting something
		// From crowbar.cpp in the hlsdk:
		g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, attacker.edict(), tr );
		if ( tr.flFraction < 1.0 )
		{
			// Calculate the point of intersection of the line (or hull) and the object we hit
			// This is and approximation of the "best" intersection
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			if ( pHit is null or pHit.IsBSPModel() )
				g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, attacker.edict() );
			vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
		}
	}
	
	state.meleeHit = state.active_opts.shoot_type == SHOOT_MELEE and tr.flFraction < 1.0;
	
	bool revivedSomething = false;
	bool reviveOnly = state.active_opts.heal_mode >= HEAL_REVIVE_FRIENDS;
	if (reviveOnly)
	{
		CBaseEntity@ revTarget = getReviveTarget(tr.vecEndPos, REVIVE_RADIUS, attacker, state.active_opts);
		if (revTarget !is null)
		{
			float revPoints = revive(revTarget, state.active_opts);
			revivedSomething = true;
			
			// revive attacks are special and always play melee hit sounds
			if (state.active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP == 0)
			{
				WeaponSound@ snd = state.active_opts.getRandomMeleeHitSound();
				if (snd !is null)
					snd.play(attacker, CHAN_VOICE);
			}
		}
	}
	
	if (state.active_opts.pev.spawnflags & FL_SHOOT_NO_BUBBLES == 0)
		water_bullet_effects(vecSrc, tr.vecEndPos);
	
	// do more fancy effects
	if( tr.flFraction < 1.0 )
	{
		if( tr.pHit !is null )
		{
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			
			if( pHit !is null ) 
			{			
				
				if (!AttackMonster(state, vecSrc, tr))
				{
					state.abortAttack = !revivedSomething;
					return;
				}
				
				string decal = getBulletDecalOverride(pHit, getDecal(state.active_opts.bullet_decal));
				if (pHit.IsBSPModel()) {
					if (state.active_opts.shoot_type == SHOOT_BULLETS)
						te_gunshotdecal(tr.vecEndPos, pHit, decal);
					if (state.active_opts.shoot_type == SHOOT_MELEE)
						te_decal(tr.vecEndPos, pHit, decal);
				}
				
				bool playDefaultMeleeSnd = state.active_opts.shoot_type == SHOOT_MELEE;
				bool playDefaultMeleeSndQuietly = isBreakableEntity(pHit); // only SC does this
				if (pHit.IsMonster() or pHit.IsPlayer())
				{
					if (!pHit.IsMachine())
					{
						// impact sound
						WeaponSound@ snd = state.active_opts.getRandomMeleeFleshSound();
						if (snd !is null)
							snd.play(attacker, CHAN_VOICE);
						playDefaultMeleeSnd = false;
					}
					else
						playDefaultMeleeSndQuietly = true;
				} 
			
				if (playDefaultMeleeSnd)
				{
					float volume = playDefaultMeleeSndQuietly ? 0.5f : 1.0f;
					WeaponSound@ snd = state.active_opts.getRandomMeleeHitSound();
					if (snd !is null)
						snd.play(attacker, CHAN_VOICE, volume);
				}
				
				EHandle h_plr = attacker;
				EHandle h_ent = pHit;
				weapon_custom_effect@ ef = pHit.IsBSPModel() ? @state.active_opts.effect1 : @state.active_opts.effect2;
				custom_effect(tr.vecEndPos, ef, EHandle(), h_ent, h_plr, vecAiming, state.active_opts.friendly_fire ? 1 : 0);
			}
		}
	}
	else // Bullet didn't hit anything
	{
		if (state.active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_MISS != 0)
		{
			state.abortAttack = !revivedSomething;
			return;
		}
					
		bool meleeSkip = state.active_opts.shoot_type == SHOOT_MELEE;
		meleeSkip = meleeSkip and (state.active_opts.pev.spawnflags & FL_SHOOT_NO_MELEE_SOUND_OVERLAP != 0);
		// melee weapons are special and only play shoot sounds when they miss
		if (meleeSkip and !state.shootingHook)
		{
			WeaponSound@ snd = state.active_opts.getRandomShootSound();
			snd.play(attacker, CHAN_WEAPON);
		}
	}
	
	// bullet tracer effects
	if (state.active_opts.bullet_color != -1)
	{
		if (state.active_opts.bullet_color == 4)
		{
			// default tracer, no special calculations needed
			te_tracer(vecSrc, tr.vecEndPos);
		}
		else
		{
			// no way to prevent usertracer going through walls, but we can at least minimize that.
			float len = tr.flFraction*state.active_opts.max_range;
			int life = int(len / 600.0f) + 1;
			te_usertracer(vecSrc, vecAiming, 6000.0f, life, state.active_opts.bullet_color, 12);
		}
	}
}

bool CanStartAttack(WeaponState& state, weapon_custom_shoot@ opts)
{
	if (state.deployTime + state.c_wep.settings.deploy_time > g_Engine.time)
	{
		return false;
	}
		
	if (state.windingUp or state.reloading != 0 or state.reloading2 != 0)
	{
		state.windupHeld = true;
		state.lastWindupHeld = g_Engine.time;
		return false;
	}

	if (state.shootingHook or state.beam_active)
	{
		state.windupHeld = true;
		state.lastWindupHeld = g_Engine.time;
		if (@opts != @state.active_opts)
			return false;
	}
	
	if (!cooldownFinished(state))
		return false;
	
	if (opts.pev.spawnflags & FL_SHOOT_NO_AUTOFIRE != 0)
	{
		if (!state.canShootAgain) {
			return false;
		}
		state.canShootAgain = false;
		setNextAttackThink(state, g_Engine.time);
	}
	
	if (PreventReviveStart(state, opts))
	{
		state.abortAttack = true;
		FailAttack(state, opts);
		return false;
	}
	
	return AllowedToShoot(state, opts);
}

bool AllowedToShoot(WeaponState& state, weapon_custom_shoot@ opts)
{
	CBaseEntity@ attacker = state.user;
	bool canshoot = true;
	bool emptySound = false;
	
	// don't fire underwater
	if( attacker.pev.waterlevel == WATERLEVEL_HEAD and !opts.can_fire_underwater())
	{
		emptySound = true;
		canshoot = false;
	}
	
	if (attacker.IsPlayer())
	{
		int ammoType = state.wep.m_iPrimaryAmmoType;
		if (opts.isSecondary() or (opts.isTertiary() and opts.weapon.tertiary_ammo_type == TAMMO_SAME_AS_SECONDARY))
			ammoType = state.wep.m_iSecondaryAmmoType;
			
		if (ammoType != -1) // ammo used at all?
		{
			bool shootingPrimary = opts.isPrimary() or ammoType == state.wep.m_iPrimaryAmmoType;
			bool shootingSecondary = opts.isSecondary() or ammoType == state.wep.m_iSecondaryAmmoType;
			bool partialAmmoShoot = (opts.pev.spawnflags & FL_SHOOT_PARTIAL_AMMO_SHOOT) != 0;
			bool shouldUseClip = 
			(state.c_wep.settings.clip_size() > 0 and shootingPrimary) or
			(state.c_wep.settings.clip_size2 > 0 and shootingSecondary);
			bool emptyClip = 
			(state.c_wep.settings.clip_size() > 0 and state.wep.m_iClip < opts.ammo_cost and shootingPrimary) or
			(state.c_wep.settings.clip_size2 > 0 and state.wep.m_iClip2 < opts.ammo_cost and shootingSecondary);
			bool emptyAmmo = AmmoLeft(state, ammoType) < opts.ammo_cost;
			if (shootingPrimary)
				emptyClip = emptyClip and (!partialAmmoShoot or state.wep.m_iClip <= 0);
			if (shootingSecondary)
				emptyClip = emptyClip and (!partialAmmoShoot or state.wep.m_iClip2 <= 0);
			emptyAmmo = emptyAmmo and (!partialAmmoShoot or AmmoLeft(state, ammoType) <= 0);
			if ((emptyClip and shouldUseClip) or (!shouldUseClip and emptyAmmo))
			{
				emptySound = true;
				canshoot = false;
				if (opts.isSecondary() and !emptyAmmo)
				{
					emptySound = false;
					state.reloadSecondary = true;
					state.c_wep.Reload();
				}
			}
		}

		if (opts.shoot_type == SHOOT_PROJECTILE and state.c_wep.settings.max_live_projectiles > 0 and
				state.liveProjectiles >= state.c_wep.settings.max_live_projectiles)
			canshoot = false;
	}
	// TODO: Monster ammo
	
	if (!canshoot)
	{
		state.abortAttack = true;
		if (emptySound)
			PlayEmptySound(state, opts);
		FailAttack(state, opts);
	}
	
	return canshoot;
}

bool cooldownFinished(WeaponState& state)
{
	return state.nextShootTime <= g_Engine.time;
}

// special logic for stopping revive windup if no revive target in range
bool PreventReviveStart(WeaponState& state, weapon_custom_shoot@ opts)
{	
	CBaseEntity@ attacker;
	bool reviveOnly = opts.heal_mode >= HEAL_REVIVE_FRIENDS;
	
	if (!reviveOnly or opts.shoot_type == SHOOT_PROJECTILE)
		return false;

	Vector vecSrc = getGunPos(attacker);
	
	Math.MakeVectors( attacker.pev.v_angle ); // todo: monser angles
	
	Vector vecAiming = spreadDir(g_Engine.v_forward, opts.bullet_spread, opts.bullet_spread_func);
	
	// Do the bullet collision
	TraceResult tr;
	Vector vecEnd = vecSrc + vecAiming * opts.max_range;
	g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, attacker.edict(), tr );
	//te_beampoints(vecSrc, vecEnd);
	
	if ( tr.flFraction >= 1.0 and opts.shoot_type == SHOOT_MELEE)
	{
		// This does a trace in the form of a box so there is a much higher chance of hitting something
		// From crowbar.cpp in the hlsdk:
		g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, attacker.edict(), tr );
		if ( tr.flFraction < 1.0 )
		{
			// Calculate the point of intersection of the line (or hull) and the object we hit
			// This is and approximation of the "best" intersection
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			if ( pHit is null or pHit.IsBSPModel() )
				g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, attacker.edict() );
			vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
		}
	}
	
	bool revivedSomething = false;
	
	if (reviveOnly)
	{
		CBaseEntity@ revTarget = getReviveTarget(tr.vecEndPos, REVIVE_RADIUS, attacker, opts);
		if (revTarget !is null)
		{
			// prevent the corpse from fading before windup finishes
			revTarget.BeginRevive(opts.windup_time);
			return false;
		}
	}
	return true;
}

bool PlayEmptySound(WeaponState& state, weapon_custom_shoot@ opts)
{
	CBaseEntity@ attacker = state.user;
	//self.m_bPlayEmptySound = false;
	WeaponSound@ snd;
	if (opts.isPrimary())
		@snd = @state.c_wep.settings.primary_empty_snd;
	else if (opts.isSecondary())
		@snd = @state.c_wep.settings.secondary_empty_snd;
	else
		@snd = @state.c_wep.settings.tertiary_empty_snd;

	snd.play(attacker, CHAN_WEAPON);
	
	return false;
}

// Returns false if attack should be aborted (medkit logic)
bool AttackMonster(WeaponState& state, Vector vecSrc, TraceResult tr)
{
	CBaseEntity@ attacker = state.user;
	CBaseEntity@ ent = g_EntityFuncs.Instance( tr.pHit );
	if (ent is null)
		return true;
		
	Vector attackDir = (tr.vecEndPos - vecSrc).Normalize();
	Vector angles = Math.VecToAngles(attackDir);
	Math.MakeVectors(angles);
	Vector knockVel = g_Engine.v_forward*state.active_opts.knockback.z +
					  g_Engine.v_up*state.active_opts.knockback.y +
					  g_Engine.v_right*state.active_opts.knockback.x;
		
	int dmgType = state.active_opts.shoot_type == SHOOT_MELEE ? DMG_CLUB : DMG_BULLET;
	dmgType = state.active_opts.damageType(dmgType);
		
	// damage done before hitgroup multipliers
	float attackDamage = state.active_opts.damage*state.windupMultiplier*state.partialAmmoModifier;
	float baseDamage = applyDamageModifiers(attackDamage, ent, attacker, state.active_opts);
	
	if (baseDamage < 0)
	{	
		// avoid TraceAttack so scis don't think we're shooting at them
		float healPoints = -heal(ent, state.active_opts, -baseDamage);
		if (healPoints == 0 and state.active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0)
			return false;

		if (state.active_opts.pev.spawnflags & FL_SHOOT_PARTIAL_AMMO_SHOOT != 0)
		{
			// don't use all ammo if we were only able to heal a small amount
			if (healPoints < attackDamage and attackDamage > 0)
			{
				float ammoScale = healPoints / attackDamage;
				state.partialAmmoUsage = int(ammoScale * state.active_opts.ammo_cost);
			}
 		}	
	}
	else
	{
		if (state.active_opts.pev.spawnflags & FL_SHOOT_IF_NOT_DAMAGE != 0)
			return false;

		g_WeaponFuncs.ClearMultiDamage(); // fixes TraceAttack() crash for some reason
		ent.TraceAttack(attacker.pev, baseDamage, attackDir, tr, dmgType);
		
		Vector oldVel = ent.pev.velocity;
		
		if (state.active_opts.friendly_fire)
		{
			// set both classes in case this a pvp map where classes are always changing
			int oldClass1 = attacker.GetClassification(0);
			int oldClass2 = ent.GetClassification(0);
			attacker.KeyValue("classify", CLASS_PLAYER);
			ent.KeyValue("classify", CLASS_ALIEN_MILITARY);
			
			g_WeaponFuncs.ApplyMultiDamage(attacker.pev, attacker.pev);
			
			attacker.KeyValue("classify", oldClass1);
			ent.KeyValue("classify", oldClass2);
		}
		else
			g_WeaponFuncs.ApplyMultiDamage(attacker.pev, attacker.pev);
		
		
		
		if (dmgType & DMG_LAUNCH == 0) // prevent high damage from launching unless we ask for it
			ent.pev.velocity = oldVel;
	}
	
	knockBack(ent, knockVel);
	
	if (state.active_opts.user_effect6 !is null)
	{
		EHandle h_ent = ent;
		EHandle h_wep = state.wep;
		custom_user_effect(h_ent, h_wep, state.active_opts.user_effect6);
	}
	
	return true;
}

}