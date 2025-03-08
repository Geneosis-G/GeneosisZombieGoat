class GGAIControllerZombieGen extends GGAIController;

var GGNpcZombieGameModeAbstract zomb;

var float mDestinationOffset;
var kActorSpawnable destActor;
var GGGoat fearPoint;

var ParticleSystemComponent mZombieParticle;
var array< name > mBonesToRagdoll;
var array<SoundCue> zombieSounds;
var array<SoundCue> zombieSoundsF;
var SoundCue zombieKnockSound;
var SoundCue zombieKnockSoundF;

var array<SoundCue> oldNoticeGoatSoundToPlay;
var array<SoundCue> oldAngrySoundToPlay;
var array<SoundCue> oldApplaudSoundToPlay;
var array<SoundCue> oldKnockedOverSounds;

var bool enraged;
var float totalTime;
var bool isArrived;
var bool isPossessing;

var IntervalInfo mChasingIntervalInfo;

var bool mIsFromPool;
var bool mHideImmediately;
delegate OnAIDestroyed(GGNpc npc);

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;

	super.Possess(inPawn, bVehicleTransition);

	isPossessing=true;
	if(mMyPawn == none)
		return;

	if(fearPoint == none)
	{
		fearPoint = Spawn(class'GGGoat', mMyPawn,, vect(-10000, -10000, -10000),,,true);
		fearPoint.SetDrawScale(0.0000001f);
		fearPoint.SetHidden(true);
		fearPoint.SetPhysics(PHYS_None);
		fearPoint.SetCollisionType(COLLIDE_NoCollision);
		fearPoint.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " fearPoint=" $ fearPoint);

	AddZombieEffect();

	mMyPawn.mStandUpDelay=3.0f;
	mMyPawn.EnableStandUp( class'GGNpc'.const.SOURCE_EDITOR );
	mMyPawn.mTimesKnockedByGoat=0;
	mMyPawn.mTimesKnockedByGoatStayDownLimit=1000000;
	mMyPawn.mAttackRange=class'GGNpc'.default.mAttackRange;
	mMyPawn.mDelayedRouteStart=false;

	mMyPawn.mProtectItems.Length=0;
	if(destActor == none)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " destActor=" $ destActor);
	destActor.SetLocation(mMyPawn.Location);
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	// Fix zombified GoatZ Zombies
	zomb=GGNpcZombieGameModeAbstract(mMyPawn);
	if(zomb != none)
	{
		zomb.mHealth=zomb.default.mHealthMax;
		zomb.mIsPendingDeath=false;
		zomb.mCanDie=false;
		zomb.LifeSpan=0.0f;
	}

	StandUp();
	FindBestState();
}

function ForceRagdollBones()
{
	local name currBoneName;
	local int i;

	for( i = 0; i < mBonesToRagdoll.Length; ++i )
	{
		currBoneName = mBonesToRagdoll[i];
		mMyPawn.Mesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed(currBoneName, mMyPawn.Mesh.PhysicsAsset, mMyPawn.Mesh, true );
	}

	mMyPawn.mesh.MinDistFactorForKinematicUpdate = 0.0f;
	mMyPawn.mesh.ForceSkelUpdate();
	mMyPawn.mesh.UpdateRBBonesFromSpaceBases( true, true );
}

event UnPossess()
{
	RemoveZombieEffect();
	if(destActor != none)
	{
		destActor.ShutDown();
		destActor.Destroy();
	}
	if(fearPoint != none)
	{
		fearPoint.Destroy();
	}
	if(zomb != none)
	{
		zomb.mHealth=zomb.default.mHealthMax;
		zomb.mCanDie=zomb.default.mCanDie;
	}
	isPossessing=false;
	super.UnPossess();
	if(mMyPawn != none)
	{
		mMyPawn.mStandUpDelay=mMyPawn.default.mStandUpDelay;
		mMyPawn.mTimesKnockedByGoat=0;
		mMyPawn.mTimesKnockedByGoatStayDownLimit=mMyPawn.default.mTimesKnockedByGoatStayDownLimit;
		mMyPawn.mProtectItems=mMyPawn.default.mProtectItems;
		mMyPawn.mAttackRange=mMyPawn.default.mAttackRange;
		mMyPawn.mDelayedRouteStart=mMyPawn.default.mDelayedRouteStart;
	}
	mMyPawn=none;
}

function AddZombieEffect()
{
	mMyPawn.mesh.AttachComponent(mZombieParticle, 'Spine_01');
	mZombieParticle.ActivateSystem();

	oldNoticeGoatSoundToPlay=mMyPawn.mNoticeGoatAnimationInfo.SoundToPlay;
	oldAngrySoundToPlay=mMyPawn.mAngryAnimationInfo.SoundToPlay;
	oldApplaudSoundToPlay=mMyPawn.mApplaudAnimationInfo.SoundToPlay;
	oldKnockedOverSounds=mMyPawn.mKnockedOverSounds;
	SetZombieVoice();
	ForceRagdollBones();
}

function SetZombieVoice()
{
	local int i;

	mMyPawn.mNoticeGoatAnimationInfo.SoundToPlay.Length = 0;
	mMyPawn.mAngryAnimationInfo.SoundToPlay.Length = 0;
	mMyPawn.mApplaudAnimationInfo.SoundToPlay.Length = 0;
	mMyPawn.mKnockedOverSounds.Length = 0;
	for( i = 0; i < zombieSounds.Length; ++i )
	{
		if(mMyPawn.mVoiceIdentity == VI_FEMALE)
		{
			mMyPawn.mNoticeGoatAnimationInfo.SoundToPlay.AddItem(zombieSoundsF[i]);
			mMyPawn.mAngryAnimationInfo.SoundToPlay.AddItem(zombieSoundsF[i]);
			mMyPawn.mApplaudAnimationInfo.SoundToPlay.AddItem(zombieSoundsF[i]);
		}
		else
		{
			mMyPawn.mNoticeGoatAnimationInfo.SoundToPlay.AddItem(zombieSounds[i]);
			mMyPawn.mAngryAnimationInfo.SoundToPlay.AddItem(zombieSounds[i]);
			mMyPawn.mApplaudAnimationInfo.SoundToPlay.AddItem(zombieSounds[i]);
		}
	}
	if(mMyPawn.mVoiceIdentity == VI_FEMALE)
	{
		mMyPawn.mKnockedOverSounds.AddItem(zombieKnockSoundF);
	}
	else
	{
		mMyPawn.mKnockedOverSounds.AddItem(zombieKnockSound);
	}
}

function RemoveZombieEffect()
{
	local name currBoneName;
	local int i;

	if(mZombieParticle != none)
	{
		mZombieParticle.DeactivateSystem();
		mZombieParticle.KillParticlesForced();
		if(mZombieParticle.Owner != none)
		{
			mZombieParticle.Owner.DetachComponent(mZombieParticle);
		}
	}

	if(mMyPawn != none)
	{
		mMyPawn.mNoticeGoatAnimationInfo.SoundToPlay=oldNoticeGoatSoundToPlay;
		mMyPawn.mAngryAnimationInfo.SoundToPlay=oldAngrySoundToPlay;
		mMyPawn.mApplaudAnimationInfo.SoundToPlay=oldApplaudSoundToPlay;
		mMyPawn.mKnockedOverSounds=oldKnockedOverSounds;

		for( i = 0; i < mBonesToRagdoll.Length; ++i )
		{
			currBoneName = mBonesToRagdoll[i];
			if(mMyPawn.Mesh.PhysicsAssetInstance != none)
			{
				mMyPawn.Mesh.PhysicsAssetInstance.UndoForceAllBodiesBelowUnfixed(currBoneName, mMyPawn.Mesh.PhysicsAsset, mMyPawn.Mesh, false );
			}
		}
	}
}

//Kill AI if zombie is destroyed
function bool KillAIIfPawnDead()
{
	if(mMyPawn == none || mMyPawn.bPendingDelete || mMyPawn.Controller != self)
	{
		UnPossess();
		Destroy();
		return true;
	}

	return false;
}

function KillMyPawn()
{
	local int i;

	if(mMyPawn != none && !mMyPawn.bPendingDelete)
	{
		for( i = 0; i < mMyPawn.Attached.Length; i++ )
		{
			if(GGGoat(mMyPawn.Attached[i]) == none)
			{
				mMyPawn.Attached[i].ShutDown();
				mMyPawn.Attached[i].Destroy();
			}
		}
		mMyPawn.ShutDown();
		mMyPawn.Destroy();
	}
	mMyPawn=none;
}

function vector GetPawnPosition(Pawn pwn)
{
	return pwn.Physics==PHYS_RigidBody?pwn.mesh.GetPosition():pwn.Location;
}

event Tick( float deltaTime )
{
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " state=" $ mCurrentState);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " SightRadius=" $ mMyPawn.SightRadius);
	//Kill destroyed zombies
	if(isPossessing)
	{
		if(KillAIIfPawnDead())
		{
			return;
		}
	}

	// Optimisation
	if( mMyPawn.IsInState( 'UnrenderedState' ) )
	{
		return;
	}

	super.Tick( deltaTime );
	// Resurect GoatZ Zombies if needed
	if(zomb != none && zomb.mIsPendingDeath)
	{
		zomb.mHealth=zomb.default.mHealthMax;
		zomb.mIsPendingDeath=false;
		zomb.mRelaxed=false;
		zomb.LifeSpan=0.0f;
	}
	// Fix dead attacked pawns
	if( mPawnToAttack != none )
	{
		if( mPawnToAttack.bPendingDelete )
		{
			mPawnToAttack = none;
		}
	}

	if(!mMyPawn.mIsRagdoll)
	{
		//Fix NPC with no collisions
		if(mMyPawn.CollisionComponent == none)
		{
			mMyPawn.CollisionComponent = mMyPawn.Mesh;
		}

		//Fix NPC rotation
		UnlockDesiredRotation();
		if(mPawnToAttack != none)
		{
			mMyPawn.SetDesiredRotation( rotator( Normal2D(GetPawnPosition(mPawnToAttack) - GetPawnPosition(mMyPawn) ) ) );
			mMyPawn.LockDesiredRotation( true );

			if(ShouldPlayChaseSound())
			{
				mChasingIntervalInfo.LastTimeStamp = WorldInfo.TimeSeconds;
				mChasingIntervalInfo.CurrentInterval = RandRange( mChasingIntervalInfo.Min, mChasingIntervalInfo.Max );

				mMyPawn.PlaySoundFromAnimationInfoStruct(mMyPawn.mAngryAnimationInfo);
			}
		}
		else
		{
			if(IsZero(mMyPawn.Velocity))
			{
				if(isArrived && !mMyPawn.isCurrentAnimationInfoStruct(mMyPawn.mIdleAnimationInfo))
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mIdleAnimationInfo );
				}

				if(!IsTimerActive( NameOf( StartRandomMovement ) ))
				{
					SetTimer(RandRange(1.0f, 10.0f), false, nameof( StartRandomMovement ) );
				}
			}
			else
			{
				if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mDanceAnimationInfo ) )
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mDanceAnimationInfo );
				}
			}
		}
		FindBestState();
		// if waited too long to before reaching some place or some target, abandon
		totalTime = totalTime + deltaTime;
		if(totalTime > 11.f)
		{
			totalTime=0.f;
			mMyPawn.SetRagdoll(true);
		}
	}
	else
	{
		//Fix NPC not standing up
		if(!IsTimerActive( NameOf( StandUp ) ))
		{
			StartStandUpTimer();
		}

		//Kill burning and drowning and glitchy zombies
		if(mMyPawn.mIsBurning || mMyPawn.mInWater || mMyPawn.Mesh.PhysicsAssetInstance == none)
		{
			OnAIDestroyed(mMyPawn);
			UnPossess();
			Destroy();
		}
	}
}

function FindBestState()
{
	if(mPawnToAttack != none)
	{
		if(!IsValidEnemy(mPawnToAttack) || !PawnInRange(mPawnToAttack))
		{
			EndAttack();
		}
		else if(mCurrentState == '')
		{
			GotoState( 'ChasePawn' );
		}
	}
	else if(mCurrentState != 'RandomMovement')
	{
		GotoState( 'RandomMovement' );
	}
}

function StartRandomMovement()
{
	local vector dest;
	local int OffsetX;
	local int OffsetY;

	if(mPawnToAttack != none || mMyPawn.mIsRagdoll  || KillAIIfPawnDead())
		return;

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " start random movement");
	totalTime=-10.f;

	OffsetX = Rand(1000)-500;
	OffsetY = Rand(1000)-500;

	dest.X = mMyPawn.Location.X + OffsetX;
	dest.Y = mMyPawn.Location.Y + OffsetY;
	dest.Z = mMyPawn.Location.Z;

	destActor.SetLocation(dest);
	isArrived=false;
	//mMyPawn.SetDesiredRotation(rotator(Normal(dest -  mMyPawn.Location)));
}

function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat )
{
	local GGNpc npc;
	local GGAIController aic;

	// Don't attack if pawn out of view or no enemy
	if(threat == none
	|| mMyPawn.IsInState( 'UnrenderedState' ))
		return;

	StopAllScheduledMovement();
	totalTime=0.f;

	mCurrentlyProtecting = protectInformation;

	mPawnToAttack = threat;

	StartLookAt( threat, 5.0f );
	//Make humans panic when they are attacked by a zombie
	npc = GGNpc(mPawnToAttack);
	if(npc != none)
	{
		aic = GGAIController(npc.Controller);
		if(aic != none && !aic.IsInState('StartPanic'))
		{
			//Use a fake goat to make the NPC panic in the opposite direction of the zombie
			fearPoint.SetLocation(mMyPawn.Location);
			aic.mLastSeenGoat=fearPoint;
			aic.Panic();
		}
	}

	GotoState( 'ChasePawn' );
}

/**
 * Initiate the attack chain
 * called when our pawn needs to protect a given item
 */
function StartAttack( Pawn pawnToAttack )
{
	local name animName;

	super.StartAttack(pawnToAttack);

	animName=mMyPawn.mAttackAnimationInfo.AnimationNames[0];
	if(animName == ''
	|| mMyPawn.mesh.GetAnimLength(animName) == 0.f
	|| mMyPawn.mAnimNodeSlot.GetPlayedAnimation() != animName)
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " Instant Attack");
		AttackPawn();
	}
}

/**
 * Attacks mPawnToAttack using mMyPawn.mAttackMomentum
 * called when our pawn needs to protect and item from a given pawn
 */
function AttackPawn()
{
	local vector dir, hitLocation;
	local float	ColRadius, ColHeight;

	StartLookAt( mPawnToAttack, 5.0f );

	mPawnToAttack.GetBoundingCylinder( ColRadius, ColHeight );
	dir = Normal(GetPawnPosition(mPawnToAttack) - GetPawnPosition(mMyPawn));
	hitLocation = GetPawnPosition(mPawnToAttack) - 0.5f * ( ColRadius + ColHeight ) *  dir;

	if( mPawnToAttack.DrivenVehicle == none )
	{
		if(mPawnToAttack.Physics != PHYS_RigidBody)
		{
			mPawnToAttack.SetPhysics( PHYS_Falling );
		}

		dir.Z += 1.0f;

		//apply force, with a random factor (0.75 - 1.25)
		mPawnToAttack.HandleMomentum( dir * mMyPawn.mAttackMomentum * Lerp( 0.75f, 1.25f, FRand() ), hitLocation, class'GGDamageTypeGTwo' );

		//maybe ragdoll
		if( FRand() < 0.25f )
		{
			GGPawn( mPawnToAttack ).SetRagdoll( true );
		}
	}

	ClearTimer( nameof( DelayedGoToProtect ) );
	SetTimer( 0.1f, false, nameof( DelayedGoToProtect ) );

	mAttackIntervalInfo.LastTimeStamp = WorldInfo.TimeSeconds;
	totalTime=0.f;

	if(enraged || GGNpc(mPawnToAttack) != none)//Ragdoll enemy
	{
		mPawnToAttack.TakeDamage(0, self, vect(0, 0, 0), vect(0, 0, 0), class'GGDamageTypeGTwo',, mMyPawn);
	}
	//Zombifie NPC
	class'ZombieGoat'.static.Zombifie(GGNpc(mPawnToAttack));
	//Fix pawn stuck after attack
	FindBestState();
}

/*
 * Returns if the zombie should play chase sound
 */
function bool ShouldPlayChaseSound()
{
	local float currentTime;

	currentTime = WorldInfo.TimeSeconds;

	if( mChasingIntervalInfo.LastTimeStamp == 0.0f )
	{
		return true;
	}

	return ( currentTime - mChasingIntervalInfo.LastTimeStamp >= mChasingIntervalInfo.CurrentInterval );
}

event PawnFalling();//do NOT go into wait for landing state

/**
 * We have to disable the notifications for changing states, since there are so many npcs which all have hundreds of calls.
 */
state MasterState
{
	function BeginState( name prevStateName )
	{
		mCurrentState = GetStateName();
	}
}

state RandomMovement extends MasterState
{
	/**
	 * Called by APawn::moveToward when the point is unreachable
	 * due to obstruction or height differences.
	 */
	event MoveUnreachable( vector AttemptedDest, Actor AttemptedTarget )
	{
		if( AttemptedDest == mOriginalPosition )
		{
			if( mMyPawn.IsDefaultAnimationRestingOnSomething() )
			{
			    mMyPawn.mDefaultAnimationInfo =	mMyPawn.mIdleAnimationInfo;
			}

			mOriginalPosition = mMyPawn.Location;
			mMyPawn.ZeroMovementVariables();

			StartRandomMovement();
		}
	}
Begin:
	mMyPawn.ZeroMovementVariables();
	while(mPawnToAttack == none && !KillAIIfPawnDead())
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " STATE OK!!!");
		if(VSize2D(destActor.Location - mMyPawn.Location) > mDestinationOffset)
		{
			MoveToward (destActor);
		}
		else
		{
			if(!isArrived)
			{
				isArrived=true;
			}
			totalTime=0.f;
			MoveToward (mMyPawn,, mDestinationOffset);// Ugly hack to prevent "runnaway loop" error
		}
	}
	mMyPawn.ZeroMovementVariables();
}

state ChasePawn extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );

	while(mPawnToAttack != none && !KillAIIfPawnDead() && (VSize(GetPawnPosition(mMyPawn) - GetPawnPosition(mPawnToAttack)) > mMyPawn.mAttackRange || !ReadyToAttack()))
	{
		MoveToward( mPawnToAttack,, mDestinationOffset );
	}

	if(!IsValidEnemy(mPawnToAttack))
	{
		ReturnToOriginalPosition();
	}
	else
	{
		FinishRotation();
		GotoState( 'Attack' );
	}
}

state Attack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	Focus = mPawnToAttack;

	StartAttack( mPawnToAttack );
	FinishRotation();
}

/**
 * Go back to where the position we spawned on
 */
function ReturnToOriginalPosition()
{
	FindBestState();
}

//All work done in EnemyNearProtectItem()
function CheckVisibilityOfGoats();
function CheckVisibilityOfEnemies();
event SeePlayer( Pawn Seen );
event SeeMonster( Pawn Seen );

/**
 * Helper function to determine if the last seen goat is near a given protect item
 * @param  protectInformation - The protectInfo to check against
 * @return true / false depending on if the goat is near or not
 */
function bool EnemyNearProtectItem( ProtectInfo protectInformation, out GGPawn enemyNear )
{
	local GGPawn gpawn;
	local float dist, minDist;

	if(mMyPawn.mIsRagdoll)
		return false;

	//Find closest pawn to attack
	minDist=-1;
	foreach CollidingActors(class'GGPawn', gpawn, mMyPawn.SightRadius, mMyPawn.Location)
	{
		if(gpawn == mMyPawn || !IsValidEnemy(gpawn) || GeometryBetween(gpawn))
			continue;

		dist=VSize(GetPawnPosition(mMyPawn)-GetPawnPosition(gpawn));
		if(minDist == -1 || dist<minDist)
		{
			minDist=dist;
			enemyNear=gpawn;
		}
	}

	return (enemyNear != none);
}

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

/**
 * Picks up on Actor::MakeNoise within Pawn.HearingThreshold
 */
event HearNoise( float Loudness, Actor NoiseMaker, optional Name NoiseType )
{
	super.HearNoise( Loudness, NoiseMaker, NoiseType );

	if( NoiseType == 'Baa' )
	{
		enraged=true;
	}
}

static function bool IsHuman(GGPawn gpawn)
{
	local GGAIControllerMMO AIMMO;

	if(InStr(string(gpawn.Mesh.PhysicsAsset), "CasualGirl_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "CasualMan_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "SportyMan_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "HeistNPC_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "Explorer_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "SpaceNPC_Physics") != INDEX_NONE)
	{
		return true;
	}
	AIMMO=GGAIControllerMMO(gpawn.Controller);
	if(AIMMO == none)
	{
		return false;
	}
	else
	{
		return AIMMO.PawnIsHuman();
	}
}

function bool IsValidEnemy( Pawn newEnemy )
{
	local GGNpc npc;
	local GGPawn gpawn;

	if(mMyPawn.mIsRagdoll)
		return false;
	gpawn=GGPawn(newEnemy);
	npc = GGNpc(gpawn);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " IsValidEnemy=" $ newEnemy);
	if(gpawn == none
	|| gpawn.mIsBurning
	|| (npc != none && npc.mInWater))
		return false;
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " IsValidEnemy nut burning or drowning");
	if(GGGoat(gpawn) != none)
		return !GGGoat(gpawn).mIsRagdoll;

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " IsValidEnemy not goat");
	if(class'GGAIControllerZombieGen'.static.IsHuman(npc))
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " IsValidEnemy(controller)=" $ npc.Controller);
		if((GGAIControllerZombieGen(npc.Controller) == none && GGAIController(npc.Controller) != none) || npc.Controller == none)
		{
			return true;
		}
	}

	return false;
}

function ResumeDefaultAction()
{
	super.ResumeDefaultAction();
	FindBestState();
}

function bool GoatCarryingDangerItem();
function bool PawnUsesScriptedRoute();
function StartLookAt( Actor lookAtActor, float lookAtDuration );
function StopLookAt();
function StartInteractingWith( InteractionInfo intertactionInfo );

//--------------------------------------------------------------//
//			GGNotificationInterface								//
//--------------------------------------------------------------//

function OnTrickMade( GGTrickBase trickMade );
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum );
function OnKismetActivated( SequenceAction activatedKismet );

/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	local GGPawn gpawn;

	gpawn = GGPawn( ragdolledActor );

	if(ragdolledActor == mMyPawn)
	{
		if(isRagdoll)
		{
			if( IsTimerActive( NameOf( StopPointing ) ) )
			{
				StopPointing();
			}

			if( IsTimerActive( NameOf( StopLookAt ) ) )
			{
				StopLookAt();
			}

			if(mCurrentState == 'ChasePawn' || mCurrentState == 'Attack')
			{
				ClearTimer( nameof( AttackPawn ) );
				ClearTimer( nameof( DelayedGoToProtect ) );
			}
			StopAllScheduledMovement();
			StartStandUpTimer();
			UnlockDesiredRotation();
		}
	}

	if( gpawn != none)
	{
		if( gpawn == mLookAtActor )
		{
			StopLookAt();
		}
	}
}

function DelayedGoToProtect()
{
	UnlockDesiredRotation();
	FindBestState();
}

/**
 * Try to figure out what we want to do after we have stand up
 */
function DeterminWhatToDoAfterStandup()
{
	ForceRagdollBones();
	FindBestState();
}

function bool CanPawnInteract();
function OnManual( Actor manualPerformer, bool isDoingManual, bool wasSuccessful );
function OnWallRun( Actor runner, bool isWallRunning );
function OnWallJump( Actor jumper );

//--------------------------------------------------------------//
//			End GGNotificationInterface							//
//--------------------------------------------------------------//

function ApplaudGoat();
function PointAtGoat();
function StopPointing();
function bool WantToPanicOverTrick( GGTrickBase trickMade );
function bool WantToApplaudTrick( GGTrickBase trickMade  );
function bool WantToPanicOverKismetTrick( GGSeqAct_GiveScore trickRelatedKismet );
function bool WantToApplaudKismetTrick( GGSeqAct_GiveScore trickRelatedKismet );
function bool NearInteractItem( PathNode currentlyAtNode, out InteractionInfo out_InteractionInfo );
function bool ShouldApplaud();
function bool ShouldNotice();
event GoatPickedUpDangerItem( GGGoat goat );
function Panic();
function Dance(optional bool forever);
function PawnDied(Pawn inPawn);

DefaultProperties
{
	mDestinationOffset=100.0f
	mSeeAI=true

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mChasingIntervalInfo=(Min=4,Max=7,CurrentInterval=4)

	Begin Object class=ParticleSystemComponent Name=ParticleSystemComponent0
        Template=ParticleSystem'Goat_Effects.Effects.Effects_RepulsiveGoat_01'
		bAutoActivate=true
		bResetOnDetach=true
	End Object
	mZombieParticle=ParticleSystemComponent0

	mBonesToRagdoll=(Neck, Clavicle_L, Clavicle_R)

	zombieSounds.Add(SoundCue'ZombieGoatSounds.ZombieSoundCue2')
	zombieSounds.Add(SoundCue'ZombieGoatSounds.ZombieSoundCue3')
	zombieSounds.Add(SoundCue'ZombieGoatSounds.ZombieSoundCue4')
	zombieSoundsF.Add(SoundCue'ZombieGoatSounds.ZombieFSoundCue1')
	zombieSoundsF.Add(SoundCue'ZombieGoatSounds.ZombieFSoundCue2')
	zombieSoundsF.Add(SoundCue'ZombieGoatSounds.ZombieFSoundCue3')

	zombieKnockSound=SoundCue'ZombieGoatSounds.ZombieSoundCue1'
	zombieKnockSoundF=SoundCue'ZombieGoatSounds.ZombieFSoundCue4'

	enraged=false
}
