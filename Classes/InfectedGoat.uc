class InfectedGoat extends GGMutator;

static function bool IsUnlocked( optional out array<AchievementDetails> out_CachedAchievements )
{
	return false;//Temporary disabled after Payday update
}

DefaultProperties
{
	mMutatorComponentClass=class'InfectedGoatComponent'
}