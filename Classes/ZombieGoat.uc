class ZombieGoat extends GGMutator;

var array<GGGoat> mGoats;

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
		}
	}
	super.ModifyPlayer( other );
}

/**
 * Called when an actor takes damage
 */
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum )
{
	local GGNpc npc;

	super.OnTakeDamage(damagedActor, damageCauser, damage, dmgType, momentum);

	npc=GGNpc(damagedActor);

	//If human NPC
	if(class'GGAIControllerZombieGen'.static.IsHuman(npc))
	{
		if((GGAIControllerZombieGen(npc.Controller) == none && GGAIController(npc.Controller) != none) || npc.Controller == none)
		{
			if((GGGoat(damageCauser) != none && mGoats.Find(GGGoat(damageCauser)) != INDEX_NONE) && class< GGDamageTypeAbility >(dmgType) != none)
			{
				class'ZombieGoat'.static.Zombifie(npc);
			}
		}
	}
}

static function bool Zombifie(GGNpc npc)
{
	local Controller oldController;
	local GGAIControllerZombieGen newController;

	//npc.WorldInfo.Game.Broadcast(npc, "Zombifie " $ npc);
	if(npc == none || npc.mIsBurning || npc.mInWater || GGAIControllerZombieGen(npc.Controller) != none)
		return false;
	//npc.WorldInfo.Game.Broadcast(npc, "OK");

	oldController=npc.Controller;
	if(oldController != none)
	{
		oldController.Unpossess();
		if(PlayerController(oldController) == none)
		{
			oldController.Destroy();
		}
	}

	newController = npc.Spawn(class'GGAIControllerZombieGen');
	npc.Controller=newController;
	newController.Possess(npc, false);

	return true;
}

defaultproperties
{

}