import dn.CiAssert;
import dn.Lib;

class Tests {
	#if !macro
	public static function main() {
		#if verbose
		CiAssert.VERBOSE = true;
		#end

		// Assert itself
		CiAssert.isTrue(true);
		CiAssert.isFalse(false);
		CiAssert.isNotNull("a");

		// Libs
		dn.Lib.__test();
		dn.Cinematic.__test();
		dn.Cooldown.__test();
		dn.DecisionHelper.__test();
		dn.Delayer.__test();
		dn.Rand.__test();
		dn.Col.UnitTest._test();
		dn.Bresenham.__test();
		dn.FilePath.__test();
		dn.Version.__test();
		dn.M.__test();
		dn.Changelog.__test();
		dn.Args.__test();
		dn.Process.__test();
		dn.RandomTools.__test();

		dn.pathfinder.AStar.__test();

		dn.legacy.Color.__test();
		dn.legacy.GetText.__test();

		dn.data.GetText.__test();
		dn.data.LocalStorage.__test();

		dn.struct.RandList.__test();
		dn.struct.RandDeck.__test();
		dn.struct.FixedArray.__test();
		dn.struct.RecyclablePool.__test();

		// Done!
		Lib.println("");
		Lib.println("Tests succcessfully completed!");
	}
	#end
}