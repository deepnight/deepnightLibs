import dn.*;
class Main {
	public static function main() {

		// Assert itself
		CiAssert.isTrue(true);
		CiAssert.isFalse(false);
		CiAssert.isNotNull("a");

		// Cinematic
		var c = new Cinematic(30);
		var v = 0;
		c.create({
			100;
			v+=1;
			100;
			v+=1;
		});
		c.chainToLast({
			200;
			v+=1;
		});
		while( !c.isEmpty() )
			c.update(1);
		CiAssert.isTrue( v==3 );

		// Cooldown
		var fps = 30;
		var coolDown = new Cooldown(fps);
		coolDown.setS("test",1);
		CiAssert.isTrue( coolDown.has("test") );
		CiAssert.isTrue( coolDown.getRatio("test") == 1 );

		for(i in 0...fps) coolDown.update(1);
		CiAssert.isFalse( coolDown.has("test") );
		CiAssert.isTrue( coolDown.getRatio("test") == 0 );

		// Delayer
		var fps = 30;
		var delayer = new Delayer(fps);
		var done = false;
		delayer.addS("test", function() done = true, 2);
		CiAssert.isTrue( delayer.hasId("test") );
		CiAssert.isFalse( done );

		for(i in 0...fps) delayer.update(1);
		CiAssert.isFalse( done );

		for(i in 0...fps) delayer.update(1);
		CiAssert.isFalse( delayer.hasId("test") );
		CiAssert.isTrue( done );

		delayer.addF("test", function() CiAssert.isFalse(true), 1);
		delayer.cancelById("test");
		delayer.update(1);

		// DecisionHelper
		var arr = [ "a", "foo", "bar", "food", "hello" ];
		var dh = new dn.DecisionHelper(arr);
		dh.score( v -> StringTools.contains(v,"o") ? 1 : 0 );
		dh.score( v -> v.length*0.1 );
		dh.remove( v -> StringTools.contains(v,"h") );
		dh.keepOnly( v -> v.length>1 );
		CiAssert.isTrue( dh.countRemaining()==3 );
		CiAssert.isTrue( dh.getBest()=="food" );


		Rand.__test();
		RandList.__test();
		RandDeck.__test();
		Color.__test();
		Bresenham.__test();
		FilePath.__test();
		dn.pathfinder.AStar.__test();
		VersionNumber.__test();
		M.__test();
		Changelog.__test();
		LocalStorage.__test();
		Lib.__test();
		Args.__test();

		// Done!
		Lib.println("");
		Lib.println("Tests succcessfully completed!");
	}
}