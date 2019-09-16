import dn.*;
class Test {
	public static function main() {
		test(Bresenham, Bresenham.iterateDisc.bind(0,0,5, function(x,y) {}));
		test(CdbHelper, function() @:privateAccess dn.CdbHelper.idxToPt(0,0) );
		test(Cinematic, function() @:privateAccess Cinematic.error.bind("test") );
		test(Color, Color.intToHex.bind(0xff0000));
		test(DecisionHelper, function() new DecisionHelper([1,2,3]));
		test(DM, DM.imax.bind(1,2));
		test(GameFocusHelper, function() {});
		test(HaxeJson, function() HaxeJson.prettify("{ a:5 }"));
		test(dn.heaps.HParticle, function() dn.heaps.HParticle.DEFAULT_BOUNDS);
		test(Lib, function() Lib.angularDistanceRad(0,3.14));
		test(PathFinder, function() new PathFinder(5,5));
		// test(MacroTools, function() MacroTools); 	// cannot test
		test(Process, function() new dn.Process());
		test(Sfx, function() @:privateAccess Sfx.GLOBAL_GROUPS);
		test(Tweenie, function() @:privateAccess Tweenie.DEFAULT_DURATION);
	}

	static function test(c:Class<Dynamic>, cb:Void->Void) {
		try {
			haxe.Log.trace(Type.getClassName(c)+"...");
			cb();
		}
		catch(e:Dynamic) {
			haxe.Log.trace(" > FAILED: "+e);
			haxe.Log.trace("");
		}
	}
}