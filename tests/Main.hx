import dn.*;
class Main {
	#if !macro
	public static function main() {

		// Assert itself
		CiAssert.isTrue(true);
		CiAssert.isFalse(false);
		CiAssert.isNotNull("a");

		Cinematic.__test();
		Cooldown.__test();
		dn.data.GetText.__test();
		DecisionHelper.__test();
		Delayer.__test();
		Rand.__test();
		RandList.__test();
		RandDeck.__test();
		Color.__test();
		Bresenham.__test();
		FilePath.__test();
		dn.pathfinder.AStar.__test();
		Version.__test();
		M.__test();
		Changelog.__test();
		LocalStorage.__test();
		Lib.__test();
		Args.__test();

		// Done!
		Lib.println("");
		Lib.println("Tests succcessfully completed!");
	}
	#end
}