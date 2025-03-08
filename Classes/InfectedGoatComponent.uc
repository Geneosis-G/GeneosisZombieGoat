class InfectedGoatComponent extends GGGoatZeroComponents;

function TickMutatorComponent( float deltaTime )
{
	local GGNpc npc;

	if(GGGameInfoZombie(class'WorldInfo'.static.GetWorldInfo().Game) != none)
	{
		super.TickMutatorComponent(deltaTime);
		return;
	}

	if(mIsInfecting)
	{
		foreach mGoat.VisibleCollidingActors( class'GGNpc', npc, 150.f, mGoat.Location + vector( mGoat.Rotation ) * 100.f )
		{
			if(npc != none && GGNpcZombieAbstract( npc ) == none)
			{
				TriggerGoatTurnedNPCKismetEvents();
				class'GGZombieManagerContent'.static.TurnNPCIntoZombie(npc, mGoat);
			}
		}
	}
}

DefaultProperties
{

}