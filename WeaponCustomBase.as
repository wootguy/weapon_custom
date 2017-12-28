#include "attack"

class WeaponCustomBase : ScriptBasePlayerWeaponEntity
{
	float m_flNextAnimTime;
	int m_iShell;
	int	m_iSecondaryAmmo;
	int lastButton; // last player button state
	int lastSequence;
	weapon_custom@ settings;
	
	WeaponState state;

	int active_fire = -1;
	
	bool primaryAlt = false;
	
	float nextShootUserEffect = 0; // prevent stacking user effects
	
	string v_model_override;
	string p_model_override;
	string w_model_override;
	int w_model_body_override = -1;
	
	float baseMoveSpeed = -1; // reset to this after dropping weapon
	
	bool used = false; // set to true if the weapon has just been +USEd
	
	bool shouldRespawn = false;
	
	void Spawn()
	{
		if (settings is null) {
			@settings = cast<weapon_custom>( @custom_weapons[self.pev.classname] );
		}		
		
		Precache();
		g_EntityFuncs.SetModel( self, settings.wpn_w_model );

		self.m_iDefaultAmmo = settings.default_ammo;
		if (self.m_iDefaultAmmo == -1)
			self.m_iDefaultAmmo = settings.clip_size();		
		self.m_iClip = self.m_iDefaultAmmo;
		
		self.FallInit();
		SetThink( ThinkFunction( WeaponThink ) );
		
		self.m_bExclusiveHold = settings.pev.spawnflags & FL_WEP_EXCLUSIVE_HOLD != 0;
		
		shouldRespawn = true; // flag for respawning
	}

	bool AddWeapon()
	{
		if (shouldRespawn and (pev.spawnflags & FL_DISABLE_RESPAWN) == 0)
		{
			CBaseEntity@ ent = g_EntityFuncs.Create(settings.weapon_classname, pev.origin, pev.angles, false); 
			g_SoundSystem.EmitSoundDyn( ent.edict(), CHAN_ITEM, "items/suitchargeok1.wav", 1.0, 
														ATTN_NORM, 0, 150 );
			WeaponCustomBase@ wep = cast<WeaponCustomBase@>(CastToScriptClass(ent));
			wep.shouldRespawn = true; // respawn this one, too
		}
		
		bool wasUsed = used;
		used = false;
		return pev.spawnflags & FL_USE_ONLY == 0 or wasUsed;
	}
	
	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		if (pActivator == pCaller and pCaller.IsPlayer())
		{
			used = true; // allow pickups for time frame
			self.Collect(pActivator);
		}
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
	}
	
	CBasePlayer@ getPlayer()
	{
		CBaseEntity@ e_plr = self.m_hPlayer;
		return cast<CBasePlayer@>(e_plr);
	}

	void RegenAmmo(int ammoType)
	{
		CBasePlayer@ plr = getPlayer();
		if (plr is null)
			return;
		int ammoLeft = plr.m_rgAmmo(ammoType);
		int maxAmmo = plr.GetMaxAmmo(ammoType);
		ammoLeft += settings.primary_regen_amt;
		
		if (ammoLeft < 0) 
			ammoLeft = 0;
		if (ammoLeft > maxAmmo) 
			ammoLeft = maxAmmo;
			
		plr.m_rgAmmo(ammoType, ammoLeft);
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		if (settings is null) {
			@settings = cast<weapon_custom>( @custom_weapons[self.pev.classname] );
		}
		
		// custom ammo only. Also why would you ever want inconsistent max ammo counts?
		info.iMaxAmmo1 	= 9999999;
		info.iMaxAmmo2 	= 9999999;
		
		info.iMaxClip = 9999999; // just prevents dynamic clip sizes from working
		if (settings.clip_size() < 1)
			self.m_iClip = -1;
		
		//self.m_iClip2 = 2; // secondary clip not working? :<
		info.iSlot 		= settings.slot;
		info.iPosition 	= settings.slotPosition;
		info.iFlags 	= settings.pev.spawnflags & 0x1F;
		info.iWeight 	= settings.priority;

		// ammo regeneration
		if (settings.primary_regen_amt != 0 and state.lastPrimaryRegen < g_Engine.time)
		{
			state.lastPrimaryRegen = g_Engine.time + settings.primary_regen_time;
			RegenAmmo(self.m_iPrimaryAmmoType);
			
		}
		if (settings.secondary_regen_amt != 0 and state.lastSecondaryRegen < g_Engine.time)
		{
			state.lastSecondaryRegen = g_Engine.time + settings.secondary_regen_time;
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
			
			// add to ammo if clip is not used (grenades, snarks, etc.)
			if (settings.clip_size() == 0)
			{
				int ammoType = self.m_iPrimaryAmmoType;
				if (ammoType != -1)
				{
					int ammoLeft = pPlayer.m_rgAmmo(ammoType);
					pPlayer.m_rgAmmo(ammoType, ammoLeft + self.m_iDefaultAmmo);
				}
			}
			return true;
		}
		return false;
	}
	
	bool Deploy(bool skipDelay)
	{
		CBasePlayer@ plr = getPlayer();
		@state.user = plr;
		@state.wep = self;
		@state.c_wep = this;
		
		if (settings.pev.spawnflags & FL_WEP_LASER_SIGHT != 0 and !primaryAlt)
		{
			ShowLaser();
			state.unhideLaserTime = g_Engine.time + 0.5;
		}
		
		string v_mod = v_model_override.Length() > 0 ? v_model_override : settings.wpn_v_model;
		string p_mod = p_model_override.Length() > 0 ? p_model_override : settings.wpn_p_model;
		string w_mod = w_model_override.Length() > 0 ? w_model_override : settings.wpn_w_model; // todo: this
		
		// body not used until weapon dropped
		
		bool ret = self.DefaultDeploy( self.GetV_Model( v_mod ), self.GetP_Model( p_mod ), 
								   settings.deploy_anim, settings.getPlayerAnimExt(), 0, w_body() );
		
		g_EntityFuncs.SetModel( self, w_mod );
		
		if (!skipDelay)
		{
			self.m_flTimeWeaponIdle = WeaponTimeBase() + settings.deploy_time + 0.5f;		   
			state.deployTime = g_Engine.time;
		}
		
		baseMoveSpeed = plr.pev.maxspeed;
		if (baseMoveSpeed == 0)
		{
			// 0 = use default speed. So, just set the default speed so the multiplier works.
			baseMoveSpeed = g_EngineFuncs.CVarGetPointer( "sv_maxspeed" ).value;
		}
		
		settings.deploy_snd.play(plr, CHAN_VOICE);
		
		// set max ammo counts for custom ammo
		array<string>@ keys = custom_ammos.getKeys();
		for (uint i = 0; i < keys.length(); i++)
		{
			weapon_custom_ammo@ ammo = cast<weapon_custom_ammo@>(custom_ammos[keys[i]]);
			bool isCustomAmmo = ammo.ammo_type == -1;
			
			if (isCustomAmmo and ammo.custom_ammo_type == settings.primary_ammo_type)
				plr.SetMaxAmmo(ammo.custom_ammo_type, ammo.max_ammo);
		}
		
		// delay fixes speed not working on minigum weapon switch and initial spawn
		g_Scheduler.SetTimeout(@this, "applyPlayerSpeedMult", 0);
		return ret;
	}
	
	bool Deploy()
	{
		return Deploy(false);
	}
	
	int w_body()
	{
		return w_model_body_override >= 0 ? w_model_body_override : settings.wpn_w_model_body;
	}
	
	// may actually be sequential if the flag for that is enabled
	int getRandomShootAnim()
	{
		return getRandomAnim(state.active_opts.shoot_anims);
	}

	int getRandomMeleeAnim()
	{
		return getRandomAnim(state.active_opts.melee_anims);
	}

	int getRandomAnim(const array<string>& anims)
	{
		if (anims.length() == 0)
			return 0;

		if (true)
			state.c_wep.lastSequence = (state.c_wep.lastSequence+1) % anims.length();
		else
			state.c_wep.lastSequence = Math.RandomLong(0, anims.length()-1);
		//return self.LookupSequence(state.active_opts.shoot_anims[state.c_wep.lastSequence]);  // I wish this worked :<
		return atoi( anims[state.c_wep.lastSequence] );
	}
	
	void applyPlayerSpeedMult()
	{
		CBasePlayer@ plr = getPlayer();
		float mult = settings.movespeed;
		if (state.windingUp and !state.windingDown and !state.windupShooting)
			mult *= state.active_opts.windup_movespeed;
		if (state.windupShooting)
			mult *= state.active_opts.windup_shoot_movespeed;
			
		plr.pev.maxspeed = baseMoveSpeed*mult;
		if (plr.pev.maxspeed == 0)
			plr.pev.maxspeed = 0.000000001; // 0 just resets to default
		
		if (settings.pev.spawnflags & FL_WEP_NO_JUMP != 0)
			plr.pev.fuser4 = 1;
	}
	
	CBasePlayerItem@ DropItem()
	{
		//self.pev.body = 3;
		//self.pev.sequence = 8;
		shouldRespawn = false;
		
		//CBaseEntity@ ent = cast<CBaseEntity@>(self);
		//monitorWeaponbox(@ent);
		
		//println("LE DROP ITEM");
		getPlayer().RemovePlayerItem(self);
		
		return self;
	}
	
	void Holster(int iSkipLocal = 0) 
	{
		// Cleanup beams, windups, etc.
		CBasePlayer@ plr = getPlayer();
		
		if (state.hook_ent)
		{
			CBaseEntity@ hookEnt = state.hook_ent;
			WeaponCustomProjectile@ hookEnt_c = cast<WeaponCustomProjectile@>(CastToScriptClass(hookEnt));
			hookEnt_c.uninstall_steam_and_kill_yourself();
		}
		if (state.hook_beam)
			g_EntityFuncs.Remove( state.hook_beam );
		state.hook_beam = null;
		
		HideLaser();
		if (self.m_fInZoom)
			primaryAlt = false;
		CancelZoom();
		CancelBeam(state);
		
		state.reloading = 0;
		
		state.windingUp = false;
		state.windupLoopEntered = false;
		state.windupSoundActive = false;
		state.windingDown = false;
		state.windupFinished = false;
		state.windupAmmoUsed = 0;
		if (state.active_opts !is null)
		{
			state.active_opts.windup_snd.stop(plr, CHAN_VOICE);
			state.active_opts.wind_down_snd.stop(plr, CHAN_VOICE);
			state.active_opts.windup_loop_snd.stop(plr, CHAN_VOICE);
			state.active_opts.hook_snd.stop(plr, CHAN_VOICE);
			state.active_opts.hook_snd2.stop(plr, CHAN_VOICE);
		}
		
		for (uint i = 0; i < state.ubeams.length(); i++)
			g_EntityFuncs.Remove(state.ubeams[i]);
		
		plr.pev.maxspeed = baseMoveSpeed;
		if (settings.pev.spawnflags & FL_WEP_NO_JUMP != 0)
			plr.pev.fuser4 = 0;
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time; //g_WeaponFuncs.WeaponTimeBase();
	}
	
	void WeaponThink()
	{	 
		AttackThink(state);
	}
	
	// returns true if a windup was started
	bool DoWindup()
	{
		CBasePlayer@ plr = getPlayer();
		if (state.active_opts.windup_time > 0 and !state.windingUp)
		{
			state.windingUp = true;
			state.windupLoopEntered = false;
			state.windingDown = false;
			state.windupFinished = false;
			state.windupHeld = true;
			state.lastWindupHeld = g_Engine.time;
			state.windupSoundActive = false;
			state.windupOvercharged = false;
			state.windupMultiplier = 1.0f;
			state.windupKickbackMultiplier = 1.0f;
			state.windupStart = g_Engine.time;
			self.pev.nextthink = g_Engine.time;
			
			applyPlayerSpeedMult();
			
			if (state.active_opts.windup_cost > 0)
			{
				state.windupAmmoUsed = 1;
				DepleteAmmo(state, 1); // don't let user get away with free shots
			}
			
			EHandle h_plr = plr;
			EHandle h_wep = cast<CBaseEntity@>(self);
			custom_user_effect(h_plr, h_wep, @state.active_opts.user_effect4);
			
			if (settings.player_anims == ANIM_REF_CROWBAR)
			{
				// Manually set wrench windup animation
				plr.m_Activity = ACT_RELOAD;
				plr.pev.frame = 0;
				plr.pev.sequence = 25;
				plr.ResetSequenceInfo();
				//plr.pev.framerate = 0.5f;
			}
			if (settings.player_anims == ANIM_REF_GREN)
			{
				// Manually set wrench windup animation
				plr.m_Activity = ACT_RELOAD;
				plr.pev.frame = 0;
				plr.pev.sequence = 33;
				plr.ResetSequenceInfo();
				//plr.pev.framerate = 0.5f;
			}
			
			return true;
		}
		return false;
	}
	
	void ShowLaser()
	{
		CBasePlayer@ plr = getPlayer();
		if (!state.laser_spr)
		{
			CSprite@ dot = g_EntityFuncs.CreateSprite( settings.laser_sprite, plr.pev.origin, true, 10 );
			dot.pev.rendermode = kRenderGlow;
			dot.pev.renderamt = settings.laser_sprite_color.a;
			dot.pev.rendercolor = settings.laser_sprite_color.getRGB();
			dot.pev.renderfx = kRenderFxNoDissipation;
			dot.pev.movetype = MOVETYPE_NONE;
			dot.pev.scale = settings.laser_sprite_scale;
			state.laser_spr = dot;
			self.pev.nextthink = g_Engine.time;
		} 
	}
	
	void HideLaser()
	{
		if (state.laser_spr)
		{
			CBaseEntity@ ent = state.laser_spr;
			g_EntityFuncs.Remove( ent );
		}
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
			getPlayer().set_m_szAnimExtension("bow");
	}
	
	void TogglePrimaryFire(int mode)
	{
		if (mode == PRIMARY_NO_CHANGE)
			return;
			
		if (mode == PRIMARY_FIRE and !primaryAlt or mode == PRIMARY_ALT_FIRE and primaryAlt)
			return;

		primaryAlt = !primaryAlt;
		
		weapon_custom_shoot@ p_opts = @settings.fire_settings[0];
		weapon_custom_shoot@ p_alt_opts = @settings.alt_fire_settings[0];
		
		weapon_custom_shoot@ next_p_opts = primaryAlt ? @p_alt_opts : @p_opts;
		
		EHandle h_plr = getPlayer();
		EHandle h_wep = cast<CBaseEntity@>(self);
		custom_user_effect(h_plr, h_wep, @next_p_opts.user_effect5);
		
		state.nextActionTime = state.nextShootTime = WeaponTimeBase() + next_p_opts.toggle_cooldown;
	}
	
	void CommonAttack(int attackNum)
	{
		CBasePlayer@ plr = getPlayer();
		int next_fire = attackNum;
		weapon_custom_shoot@ next_opts = @settings.fire_settings[next_fire];
		weapon_custom_shoot@ alt_opts = @settings.alt_fire_settings[next_fire];
		
		state.windupOnly = false;
		
		int fireAct = next_fire == 1 ? settings.secondary_action : settings.tertiary_action;
		if (fireAct != FIRE_ACT_SHOOT)
		{
			if (state.nextActionTime > g_Engine.time)
				return;
			if (fireAct == FIRE_ACT_LASER)
			{
				if (!state.laser_spr)
					ShowLaser();
				else
					HideLaser();
			}
			if (fireAct == FIRE_ACT_ZOOM)
			{ 
				self.SetFOV(primaryAlt ? 0 : settings.zoom_fov);
				self.m_fInZoom = !self.m_fInZoom;
				if (settings.player_anims == ANIM_REF_BOW)
					plr.set_m_szAnimExtension(self.m_fInZoom ? "bowscope" : "bow");
				if (settings.player_anims == ANIM_REF_SNIPER)
					plr.set_m_szAnimExtension(self.m_fInZoom ? "sniperscope" : "sniper");
				
			}
			
			
			if (fireAct == FIRE_ACT_WINDUP)
			{
				next_fire = 0;
				@next_opts = @settings.fire_settings[next_fire];
				@alt_opts = @settings.alt_fire_settings[next_fire];
				state.windupOnly = true;
			}
			else
			{
				TogglePrimaryFire(PRIMARY_TOGGLE);
				return;
			}
			
		}
		
		if (next_fire == 0 and primaryAlt and settings.primary_alt_fire.Length() > 0)
			@next_opts = @alt_opts;
	
		if (next_opts.pev is null or !CanStartAttack(state, next_opts))
			return;
			
		@state.active_opts = next_opts;
		active_fire = next_fire;
		state.active_ammo_type = -1;
		if (next_fire == 0) 
		{
			state.active_ammo_type = self.m_iPrimaryAmmoType;
		} 
		else if (next_fire == 1)
		{
			state.active_ammo_type = self.m_iSecondaryAmmoType;
		}
		else if (next_fire == 2)
		{
			if (settings.tertiary_ammo_type == TAMMO_SAME_AS_PRIMARY)
				state.active_ammo_type = self.m_iPrimaryAmmoType;
			if (settings.tertiary_ammo_type == TAMMO_SAME_AS_SECONDARY) 
				state.active_ammo_type = self.m_iSecondaryAmmoType;
		}
		
		if (DoWindup())
			return;
		
		DoAttack(state);
	}
	
	void PrimaryAttack()   { CommonAttack(0); }
	void SecondaryAttack() { CommonAttack(1); }
	void TertiaryAttack()  { CommonAttack(2); }
	
	// Same as DefaultReload except it doesn't break when changing clip size mid-game
	bool CustomReload(int reloadAnim, float reloadTime)
	{
		CBasePlayer@ plr = getPlayer();
		
		int ammoType = self.m_iPrimaryAmmoType;
		int ammoLeft = plr.m_rgAmmo(ammoType);
		if (ammoLeft <= 0 or self.m_iClip == settings.clip_size())
			return false;
		
		self.SendWeaponAnim( reloadAnim, 0, w_body() );
		state.reloadFinishTime = g_Engine.time + reloadTime;
		state.reloading = -1;
		self.pev.nextthink = g_Engine.time;
			
		return true;
	}
	
	void Reload()
	{
		CBasePlayer@ plr = getPlayer();
		if (settings.clip_size() == 0)
			return;
		if (!cooldownFinished(state) or state.reloading != 0)
			return;
		if (state.reloadFinishTime > g_Engine.time)
			return;
			
		if (state.liveProjectiles > 0 and state.active_opts.projectile.follow_mode == FOLLOW_CROSSHAIRS)
			return; // don't reload if we're controlling a projectile
			
		if (state.liveProjectiles > 0 and settings.pev.spawnflags & FL_WEP_WAIT_FOR_PROJECTILES != 0)
			return; // don't reload if user wants to wait for projectile deaths
		
		if ((settings.reload_mode == RELOAD_STAGED or settings.reload_mode == RELOAD_STAGED_RESPONSIVE) and 
			self.m_iClip < settings.clip_size() and AmmoLeft(state, state.active_ammo_type) >= settings.reload_ammo_amt)
		{
			self.SendWeaponAnim( settings.reload_start_anim, 0, w_body() );
			state.reloading = 1;
			state.nextReload = WeaponTimeBase() + settings.reload_start_time;
			state.nextShootTime = state.nextReload;
			self.pev.nextthink = g_Engine.time;
			settings.reload_start_snd.play(plr, CHAN_VOICE);
			CancelZoom();
			state.windupHeld = false;
			return;
		}
		
		bool emptyReload = EmptyShoot(state);
		int reloadAnim = settings.reload_empty_anim;
		if (reloadAnim < 0 or !emptyReload)
			reloadAnim = settings.reload_anim;
			
		bool emptyReloadEffect = emptyReload and settings.user_effect2 !is null;
		float reload_time = settings.getReloadTime(emptyReloadEffect);
			
		bool reloaded = CustomReload(reloadAnim, reload_time);
		
		if (reloaded)
		{
			if (settings.reload_mode == RELOAD_EFFECT_CHAIN)
			{
				EHandle h_plr = plr;
				EHandle h_wep = cast<CBaseEntity@>(self);
				weapon_custom_user_effect@ ef = emptyReloadEffect ? @settings.user_effect2 : @settings.user_effect1;
				custom_user_effect(h_plr, h_wep, ef, false);
			}
		
			CancelZoom();
			settings.reload_snd.play(plr, CHAN_VOICE);
			state.unhideLaserTime = WeaponTimeBase() + reload_time;
		}
		
		if (settings.player_anims == ANIM_REF_UZIS)
		{
			// Only reload the right uzi since dual wielding doesn't work yet.
			plr.m_Activity = ACT_RELOAD;
			plr.pev.frame = 0;
			plr.pev.sequence = 135;
			plr.ResetSequenceInfo();
			//plr.pev.framerate = 0.5f;
		}
		else
			BaseClass.Reload();
	}

	void WeaponIdle()
	{
		if (state.beam_active and state.beamStartTime + state.minBeamTime < g_Engine.time)
		{
			CancelBeam(state);
		}
		
		if (state.nextCooldownEffect != 0 and state.nextCooldownEffect < g_Engine.time)
		{
			state.nextCooldownEffect = 0;
			
			EHandle h_plr = getPlayer();
			EHandle h_wep = cast<CBaseEntity@>(self);
			custom_user_effect(h_plr, h_wep, @state.active_opts.user_effect3, true);
		}
		
		//println("FRAMERATE: " + self.pev.animtime);
		//self.pev.framerate = 500;
		//float wow = self.StudioFrameAdvance(0.0f);
		
		self.ResetEmptySound();
		
		if( self.m_flTimeWeaponIdle > WeaponTimeBase() or state.windingUp or state.reloading != 0 or state.nextActionTime > g_Engine.time)
			return;

		if (settings.idle_time > 0) {
			self.SendWeaponAnim( settings.getRandomIdleAnim(), 0, w_body() );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + settings.idle_time; // how long till we do this again.
		}
	}
}

class AmmoCustomBase : ScriptBasePlayerAmmoEntity
{
	weapon_custom_ammo@ settings;
	
	void Spawn()
	{ 
		if (settings is null) {
			@settings = cast<weapon_custom_ammo>( @custom_ammos[self.pev.classname] );
		}
		
		Precache();

		if( !self.SetupModel() )
		{
			g_EntityFuncs.SetModel( self, settings.w_model );
		}
		else	//Custom model
			g_EntityFuncs.SetModel( self, self.pev.model );

		BaseClass.Spawn();
	}
	void Precache()
	{
		BaseClass.Precache();
	}
	bool AddAmmo( CBaseEntity@ pOther ) 
	{
		if (pOther.pev.classname != "player")
			return false;
		CBasePlayer@ plr = cast<CBasePlayer@>(pOther);
			
		int type = settings.ammo_type;
		string ammo_type = type < 0 ? settings.custom_ammo_type : g_ammo_types[type];
		
		// I don't like that you have to code a max ammo in each weapon. So I'm doing the math here.
		int should_give = settings.give_ammo;
		int total_ammo = plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(ammo_type));
		if (total_ammo >= settings.max_ammo)
			return false;
		else
			should_give = Math.min(settings.max_ammo - total_ammo, settings.give_ammo);
		
		int ret = pOther.GiveAmmo( should_give, ammo_type, settings.max_ammo );
		if (ret != -1)
		{
			settings.pickup_snd.play(self, CHAN_ITEM);
			return true;
		}
		return false;
	}
}