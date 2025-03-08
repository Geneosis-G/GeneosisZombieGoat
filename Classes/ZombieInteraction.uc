class ZombieInteraction extends Interaction;

var ZombieOutbreak myMut;

function InitZombieInteraction(ZombieOutbreak newMut)
{
	myMut=newMut;
}

exec function ShowZombieSpawnCount()
{
	myMut.WorldInfo.Game.Broadcast(myMut, "ZombieSpawnCount = " $ myMut.minZombieCount);
}

exec function SetZombieSpawnCount(int newSpawnCount)
{
	myMut.minZombieCount=newSpawnCount;
	myMut.maxZombieCount=newSpawnCount*2;
}

exec function ResetZombieSpawnCount()
{
	myMut.minZombieCount=myMut.default.minZombieCount;
	myMut.maxZombieCount=myMut.default.maxZombieCount;
}
/*
exec function ShowInfectedSpawnCount()
{
	myMut.WorldInfo.Game.Broadcast(myMut, "InfectedSpawnCount = " $ myMut.minInfectedCount);
}

exec function SetInfectedSpawnCount(int newSpawnCount)
{
	myMut.minInfectedCount=newSpawnCount;
	myMut.maxInfectedCount=newSpawnCount*2;
}

exec function ResetInfectedSpawnCount()
{
	myMut.minInfectedCount=myMut.default.minInfectedCount;
	myMut.maxInfectedCount=myMut.default.maxInfectedCount;
}
*/