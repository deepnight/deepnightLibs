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
		CiAssert.equals("a","a");

		// Libs
		dn.Args.test();
		dn.pathfinder.AStar.test();
		dn.geom.Bresenham.test();
		dn.geom.Geom.test();
		dn.Changelog.test();
		dn.Cinematic.test();
		dn.Col.UnitTest.test();
		dn.legacy.Color.test();
		dn.Cooldown.test();
		dn.DecisionHelper.test();
		dn.Delayer.test();
		dn.FilePath.test();
		dn.struct.FixedArray.FixedArrayTests.test();
		dn.data.GetText.test();
		dn.legacy.GetText.test();
		dn.Lib.test();
		dn.data.LocalStorage.test();
		dn.M.test();
		dn.Process.test();
		dn.Rand.test();
		dn.struct.RandDeck.test();
		dn.struct.RandList.test();
		dn.RandomTools.test();
		dn.struct.RecyclablePool.test();
		dn.struct.Stat.StatTest.test();
		dn.phys.Velocity.test();
		dn.Version.test();
		dn.Log.test();
		dn.TinyTween.test();

		#if hscript
		dn.script.ScriptTest.run();
		#end


		// Done!
		Lib.println("");
		Lib.println("Tests succcessfully completed!");
	}
	#end
}