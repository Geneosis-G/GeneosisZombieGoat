class ZombieOutbreak extends GGMutator;

var array<GGGoat> mGoats;
var float timeElapsed;
var float managementTimer;
var float SRTimeElapsed;
var float spawnRemoveTimer;
var float spawnRadius;
var int minZombieCount;
var int minInfectedCount;
var int maxZombieCount;
var int maxInfectedCount;

var array<GGNpc> mZombiePool;
var float mTimeNotLookingForHide;
var array<GGNpc> delayedRemovableNPCs;
var array<GGNpc> mRemovableNPCs;//TODO remove?
var int mZombieNPCCount;
var int mInfectedNPCCount;
var array<int> mZombieNPCsToSpawnForPlayer;
var array<int> mInfectedNPCsToSpawnForPlayer;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );
	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			mGoats.AddItem(goat);
			if(mGoats.Length == 1)
			{
				InitZombieInteraction();
			}
		}
	}
	super.ModifyPlayer( other );
}

function InitZombieInteraction()
{
	local ZombieInteraction mi;

	mi = new class'ZombieInteraction';
	mi.InitZombieInteraction(self);
	GetALocalPlayerController().Interactions.AddItem(mi);
}

simulated event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	timeElapsed=timeElapsed+deltaTime;
	if(timeElapsed > managementTimer)
	{
		timeElapsed=0.f;
		//ManageZombieNPCs();
		GenerateZombieLists();
	}
	SRTimeElapsed=SRTimeElapsed+deltaTime;
	if(SRTimeElapsed > spawnRemoveTimer)
	{
		SRTimeElapsed=0.f;
		RemoveZombieFromList();//Remove first to get new zombies in the pool
		SpawnZombieFromList();
	}
}

function GenerateZombieLists()
{
	local GGNpc zombieNPC;
	local array<int> zombieNPCsForPlayer;
	local array<int> infectedNPCsForPlayer;
	local bool isRemovable;
	local int nbPlayers, i;
	local vector dist;

	mRemovableNPCs.Length=0;

	nbPlayers=mGoats.Length;
	mZombieNPCsToSpawnForPlayer.Length = 0;
	mZombieNPCsToSpawnForPlayer.Length = nbPlayers;
	mInfectedNPCsToSpawnForPlayer.Length = 0;
	mInfectedNPCsToSpawnForPlayer.Length = nbPlayers;
	zombieNPCsForPlayer.Length = nbPlayers;
	infectedNPCsForPlayer.Length = nbPlayers;
	mZombieNPCCount=0;
	mInfectedNPCCount=0;
	//Find all zombie (and infected NPCs) close to each player
	foreach WorldInfo.AllPawns(class'GGNpc', zombieNPC)
	{
		if(zombieNPC.bPendingDelete
		|| zombieNPC.bHidden
		|| GGAIControllerZombieGen(zombieNPC.Controller) == none)
			continue;

		//WorldInfo.Game.Broadcast(self, zombieAI $ " possess " $ zombieNPC);
		mZombieNPCCount++;
		isRemovable=true;

		for(i=0 ; i<nbPlayers ; i++)
		{
			dist=mGoats[i].Location - zombieNPC.Location;
			if(VSize2D(dist) < spawnRadius)
			{
				zombieNPCsForPlayer[i]++;
				isRemovable=false;
			}
		}

		if(isRemovable && GGAIControllerZombieGen(zombieNPC.Controller).mIsFromPool)
		{
			GGAIControllerZombieGen(zombieNPC.Controller).mHideImmediately=true;//Make sure the NPC dissapear
			DelayedHideNPC(zombieNPC);
		}
	}
	//Temporarly disabled
	/*
	foreach AllActors(class'GGAIControllerZombieGM', infectedAI)
	{
		zombieNPC=infectedAI.mMyPawn;
		if(zombieNPC != none)
		{
			mInfectedNPCCount++;
			isRemovable=true;

			for(i=0 ; i<nbPlayers ; i++)
			{
				dist=mGoats[i].Location - zombieNPC.Location;
				if(VSize2D(dist) < spawnRadius)
				{
					infectedNPCsForPlayer[i]++;
					isRemovable=false;
				}
			}

			if(isRemovable)
			{
				mRemovableNPCs.AddItem(zombieNPC);
			}
		}
	}
	*/

	for(i=0 ; i<nbPlayers ; i++)
	{
		mZombieNPCsToSpawnForPlayer[i]=minZombieCount-zombieNPCsForPlayer[i];
		mInfectedNPCsToSpawnForPlayer[i]=minInfectedCount-infectedNPCsForPlayer[i];
	}
	//WorldInfo.Game.Broadcast(self, "Zombies to spawn " $ mZombieNPCsToSpawnForPlayer[0]);
}

function AddZombieToPool(GGNpc zombieNPC)
{
	local vector randomLoc;

	if(zombieNPC == none
	|| zombieNPC.bPendingDelete
	|| mZombiePool.Find(zombieNPC) != INDEX_NONE)
		return;
	//WorldInfo.Game.Broadcast(self, "Add zombie to pool " $ zombieNPC $ ", size=" $ mZombiePool.Length+1);
	zombieNPC.SetHidden(true);
	zombieNPC.SetCollision( false, false, false );
	zombieNPC.SetTickIsDisabled( true );
	if(!zombieNPC.mIsRagdoll)
	{
		zombieNPC.SetRagdoll(true);
	}
	zombieNPC.DisableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
	zombieNPC.SetPhysics(PHYS_None);
	randomLoc=vect(0, 0, -900) + (vect(10, 0, 0) * int(GetRightMost(zombieNPC.name))) + (vect(0, 1, 0) * (Rand(2000)-1000));
	zombieNPC.SetLocation(randomLoc);
	mZombiePool.AddItem(zombieNPC);
}

function bool SpawnZombieFromPool(vector spawnLoc, rotator spawnRot)
{
	local GGNpc spawnedNPC;

	if(mZombiePool.Length == 0)
	{
		spawnedNPC=Spawn(class'GGNpc',,, spawnLoc, spawnRot,, true);
		//WorldInfo.Game.Broadcast(self, "Spawn new zombie " $ spawnedNPC);
	}
	else
	{
		spawnedNPC=mZombiePool[mZombiePool.Length-1];
		mZombiePool.RemoveItem(spawnedNPC);
		//WorldInfo.Game.Broadcast(self, "Get zombie from pool " $ spawnedNPC);
		//Force unragdoll instantly
		spawnedNPC.SetLocation(spawnLoc);
		spawnedNPC.SetPhysics(PHYS_RigidBody);
		spawnedNPC.SetCollision( true, true, true );
		spawnedNPC.EnableStandUp(class'GGNpc'.const.SOURCE_EDITOR);
		spawnedNPC.SetOnFire(false);
		spawnedNPC.SetIsInWater(false);
		spawnedNPC.ReleaseFromHogtie();
		if(spawnedNPC.mIsRagdoll)
		{
			spawnedNPC.Velocity=vect(0, 0, 0);
			spawnedNPC.StandUp();
			spawnedNPC.mesh.PhysicsWeight=0;
			spawnedNPC.TerminateRagdoll(0.f);
		}
		spawnedNPC.SetDrawScale(1.f);
		spawnedNPC.SetLocation(spawnLoc);
		spawnedNPC.SetRotation(spawnRot);
		spawnedNPC.SetTickIsDisabled( false );
		spawnedNPC.SetHidden(false);
	}

	if(spawnedNPC == none
	|| spawnedNPC.bPendingDelete
	|| !spawnedNPC.IsAliveAndWell())
	{
		DestroyNPC(spawnedNPC);
		return false;
	}

	SetRandomMesh(spawnedNPC);
	spawnedNPC.SetPhysics( PHYS_Falling );
	if(GGAIControllerZombieGen(spawnedNPC.Controller) == none)
	{
		if(class'ZombieGoat'.static.Zombifie(spawnedNPC))
		{
			GGAIControllerZombieGen(spawnedNPC.Controller).OnAIDestroyed=DelayedHideNPC;
			GGAIControllerZombieGen(spawnedNPC.Controller).mIsFromPool=true;
		}
		else
		{
			DestroyNPC(spawnedNPC);
			return false;
		}
	}
	else
	{
		GGAIControllerZombieGen(spawnedNPC.Controller).SetZombieVoice();//new skeletalmesh, new voice
		GGAIControllerZombieGen(spawnedNPC.Controller).ForceRagdollBones();//new skeletalmesh, new bones
	}

	return true;
}

function AddInfectedToPool(GGNpc zombieNPC)
{
	//TODO
}

function bool SpawnInfectedFromPool(vector spawnLoc, rotator spawnRot)
{
	//TODO
	return false;
}

function SpawnZombieFromList()
{
	local int nbPlayers, i;

	//Spawn new zombies and infected NPCs if needed
	nbPlayers=mGoats.Length;
	for(i=0 ; i<nbPlayers ; i++)
	{
		if(mZombieNPCsToSpawnForPlayer.Length > 0 && mZombieNPCsToSpawnForPlayer[i] > 0)
		{
			if(SpawnZombieFromPool(GetRandomSpawnLocation(mGoats[i]), GetRandomRotation()))
			{
				mZombieNPCsToSpawnForPlayer[i]--;
				mZombieNPCCount++;
			}
			break;
		}

		if(mInfectedNPCsToSpawnForPlayer.Length > 0 && mInfectedNPCsToSpawnForPlayer[i] > 0)
		{
			/*mInfectedNPCsToSpawnForPlayer[i]--;
			newInfectedNpc = Spawn( class'GGNpcZombie',,, GetRandomSpawnLocation(mGoats[i].Location), GetRandomRotation(),, true);
			if(newInfectedNpc != none)
			{
				newInfectedNpc.mFastOrSlowMethod=EZFSM_ForceFast;
				newInfectedNpc.SetUpFastOrSlowZombie();
				newInfectedNpc.SetRandomVisuals();
				newInfectedNpc.SetPhysics( PHYS_Falling );
				mInfectedNPCCount++;
			}
			break;*/
			if(SpawnInfectedFromPool(GetRandomSpawnLocation(mGoats[i]), GetRandomRotation()))
			{
				mInfectedNPCsToSpawnForPlayer[i]--;
				mInfectedNPCCount++;
			}
			break;
		}
	}
}

function SetRandomMesh(GGNpc npc)
{
	local GGNPc npcItr;
	local array< GGNpc > someNPCs;
	local int i;

	foreach WorldInfo.AllPawns( class'GGNpc', npcItr )
	{
		if( npcItr.mesh.SkeletalMesh != none
		 && npcItr.mesh.PhysicsAsset != none
	 	 && npcItr.mesh.Materials.Length > 0
		 && npcItr.mesh.Materials[0] != none
		 && class'GGAIControllerZombieGen'.static.IsHuman(npcItr))
		{
			someNPCs.AddItem( npcItr );
		}
	}

	npcItr = someNPCs[ Rand( someNPCs.Length ) ];
	npc.SetMesh(npcItr.mesh.SkeletalMesh, npcItr.mesh.PhysicsAsset, npcItr.mesh.Materials[0]);
	for(i=0 ; i<npcItr.mesh.Materials.Length ; i++)
	{
		npc.mesh.SetMaterial(i, npcItr.mesh.GetMaterial(i));
	}
	npc.mesh.SetAnimTreeTemplate(npcItr.mesh.AnimTreeTemplate);
	npc.mesh.AnimSets[0]=npcItr.mesh.AnimSets[0];
}

function RemoveZombieFromList()//Remove dead zombies when out of view (add them back to pool)
{
	local int i;

	for(i=delayedRemovableNPCs.Length-1 ; i>=0 ; i--)
	{
		if(`TimeSince( delayedRemovableNPCs[i].LastRenderTime ) > mTimeNotLookingForHide
		|| (GGAIControllerZombieGen(delayedRemovableNPCs[i].Controller) != none && GGAIControllerZombieGen(delayedRemovableNPCs[i].Controller).mHideImmediately))
		{
			AddZombieToPool(delayedRemovableNPCs[i]);
			delayedRemovableNPCs.RemoveItem(delayedRemovableNPCs[i]);
		}
	}
}

function DelayedHideNPC(GGNpc npc)
{
	delayedRemovableNPCs.AddItem(npc);
}

function DestroyNPC(GGPawn gpawn)
{
	local int i;

	if(gpawn == none || gpawn.bPendingDelete)
		return;

	for( i = 0; i < gpawn.Attached.Length; i++ )
	{
		if(GGGoat(gpawn.Attached[i]) == none)
		{
			gpawn.Attached[i].ShutDown();
			gpawn.Attached[i].Destroy();
		}
	}
	gpawn.ShutDown();
	gpawn.Destroy();
}

function vector GetRandomSpawnLocation(GGPawn pawnCenter)
{
	local vector dest, center;
	local rotator rot;
	local float dist;
	local Actor hitActor;
	local vector hitLocation, hitLocationWater, hitNormal, traceEnd, traceStart;
	local int i;

	center=pawnCenter.mIsRagdoll?pawnCenter.mesh.GetPosition():pawnCenter.Location;
	rot=GetRandomRotation();
	dist=spawnRadius;
	dist=RandRange(dist/2.f, dist);

	for(i=0 ; i<4 ; i++)
	{
		dest=center+Normal(vector(rot))*dist;
		traceStart=dest;
		traceEnd=dest;
		traceStart.Z=10000.f;
		traceEnd.Z=-3000;

		hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
		if( hitActor == none )
		{
			hitLocation = traceEnd;
		}

		//Try to avoid spawning zombies in water because it's laggy
		hitActor = Trace( hitLocationWater, hitNormal, traceEnd, traceStart, false,,, TRACEFLAG_PhysicsVolumes );
		if(WaterVolume( hitActor ) != none || (Volume( hitActor ) != none && pawnCenter.IsWaterMaterial( hitActor.Tag )))
		{
			if(hitLocationWater.Z < hitLocation.Z)//Ok we are not in water
			{
				break;
			}
		}
		rot.Yaw+=16384;//+1/4 of circle
	}
	hitLocation.Z+=85;

	return hitLocation;
}

function rotator GetRandomRotation()
{
	local rotator rot;

	rot=Rotator(vect(1, 0, 0));
	rot.Yaw+=RandRange(0.f, 65536.f);

	return rot;
}

DefaultProperties
{
	managementTimer=1.f
	spawnRemoveTimer=0.1f
	spawnRadius=5000.f
	minZombieCount=20
	minInfectedCount=0
	maxZombieCount=40
	maxInfectedCount=0
	mTimeNotLookingForHide=0.5f
}