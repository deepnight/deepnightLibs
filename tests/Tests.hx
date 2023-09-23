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
		dn.Args.__test();
		dn.pathfinder.AStar.__test();
		dn.Bresenham.__test();
		dn.Changelog.__test();
		dn.Cinematic.__test();
		dn.Col.UnitTest._test();
		dn.legacy.Color.__test();
		dn.Cooldown.__test();
		dn.DecisionHelper.__test();
		dn.Delayer.__test();
		dn.FilePath.__test();
		dn.struct.FixedArray.FixedArrayTests.__test();
		dn.data.GetText.__test();
		dn.legacy.GetText.__test();
		dn.Lib.__test();
		dn.data.LocalStorage.__test();
		dn.M.__test();
		dn.Process.__test();
		dn.Rand.__test();
		dn.struct.RandDeck.__test();
		dn.struct.RandList.__test();
		dn.RandomTools.__test();
		dn.struct.RecyclablePool.__test();
		dn.struct.Stat.StatTest.__test();
		dn.phys.Velocity.__test();
		dn.Version.__test();
		dn.Log.__test();



		// Done!
		Lib.println("");
		Lib.println("Tests succcessfully completed!");
	}
	#end
}