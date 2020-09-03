import dn.*;
class Main {
	public static function main() {
		// Assert itself
		CiAssert.isTrue(true);
		CiAssert.isFalse(false);
		CiAssert.isNotNull(5);

		// Bresenham
		CiAssert.noException(
			"Bresenham disc radius",
			Bresenham.iterateDisc(0,0, 2, function(x,y) {
				if( M.floor( Math.sqrt( x*x + y*y ) ) > 2 )
					throw 'Failed at $x,$y';
			})
		);
		CiAssert.noException(
			"Bresenham circle radius",
			Bresenham.iterateCircle(0,0, 2, function(x,y) {
				if( M.round( Math.sqrt( x*x + y*y ) ) != 2 )
					throw 'Failed at $x,$y';
			})
		);

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

		// Color
		CiAssert.isTrue( Color.intToHex(0xff00ff)=="#FF00FF" );
		CiAssert.isTrue( Color.hexToInt("#ff00ff")==0xff00ff );
		CiAssert.isTrue( Color.getLuminosity(0xffffff)==1 );
		CiAssert.isTrue( Color.getLuminosity(0x00ff00)==1 );
		CiAssert.isTrue( Color.makeColorHsl(0, 1, 1)==0xff0000 );
		CiAssert.isTrue( Color.toWhite(0x112233, 1)==0xffffff );
		CiAssert.isTrue( Color.getSaturation(0xff0000)==1 );

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

		// Math
		CiAssert.isTrue( M.round(1.2)==1 );
		CiAssert.isTrue( M.round(1.5)==2 );
		CiAssert.isTrue( M.round(-1.5)==-2 );
		CiAssert.isTrue( M.ceil(-1.5)==-1 );
		CiAssert.isTrue( M.floor(-1.5)==-2 );
		CiAssert.isTrue( M.isValidNumber(1.5) );
		CiAssert.isTrue( !M.isValidNumber(null) );
		CiAssert.isTrue( !M.isValidNumber(1/0) );

		// Build a basic map for pathfinder
		var matrix = [
			"...#.",
			".###.",
			"...#.",
			".#.#.",
			".#...",
		];
		var wid = matrix[0].length;
		var hei = matrix.length;
		var targetX = wid-1;
		var targetY = 0;
		Sys.println("\t"+matrix.join("\n\t"));

		// Pathfinder
		var pf = new dn.pathfinder.AStar( function(x,y) return {x:x, y:y} );
		pf.init(
			wid, hei,
			function(x,y) return x>=0 && y>=0 && x<wid && y<hei ? matrix[y].charAt(x)=="#" : true
		);
		var path = pf.getPath(0, 0, targetX, targetY);
		Sys.println("	Path="+path.map( function(pt) return pt.x+","+pt.y ).join(" -> ") );
		CiAssert.isTrue( path.length>0 );
		CiAssert.isTrue( path[path.length-1].x==targetX && path[path.length-1].y==targetY );

		// DecisionHelper
		var arr = [ "a", "foo", "bar", "food", "hello" ];
		var dh = new dn.DecisionHelper(arr);
		dh.score( v -> StringTools.contains(v,"o") ? 1 : 0 );
		dh.score( v -> v.length*0.1 );
		dh.remove( v -> StringTools.contains(v,"h") );
		dh.keepOnly( v -> v.length>1 );
		CiAssert.isTrue( dh.countRemaining()==3 );
		CiAssert.isTrue( dh.getBest()=="food" );

		// Rand
		var random = new Rand(0);
		for(seed in 0...2) {
			random.initSeed(seed);
			var a = random.rand();
			random.initSeed(seed);
			CiAssert.isTrue( random.rand()==a );
		}

		// RandDeck
		var randDeck = new RandDeck();
		randDeck.push(0, 2);
		randDeck.push(1, 2);
		randDeck.push(2, 2);
		randDeck.shuffle();
		CiAssert.isTrue( randDeck.countRemaining()==6 );
		CiAssert.noException("RandDeck bounds check", {
			for(i in 0...100) {
				var v = randDeck.draw();
				if( v==null || v<0 || v>2 )
					throw "Value "+v+" is incorrect";
			}
		});

		// RandList
		var randList = new RandList([0,1,2,3]);
		CiAssert.noException("RandList bounds check", {
			for(i in 0...100) {
				var v = randList.draw();
				if( v==null || v<0 || v>3 )
					throw "Value "+v+" is incorrect";
			}
		});
		CiAssert.isTrue( randList.getProbaPct(2)==25 );
		CiAssert.isTrue( randList.contains(3) );

		// FilePath
		CiAssert.isTrue( FilePath.fromDir("c:\\windows\\system").getDirectoryArray().length==3 );
		CiAssert.isTrue( FilePath.fromFile("../a\\b/file.png").fileName=="file" );
		CiAssert.isTrue( FilePath.fromFile("a/b/file.png").extension=="png" );
		CiAssert.isTrue( FilePath.fromFile("a/b/file.png").directoryWithSlash=="a/b/" );
		CiAssert.isTrue( FilePath.fromFile("a/file.2.png").fileName=="file.2" );
		CiAssert.isTrue( FilePath.fromFile("f.png").directoryWithSlash==null );
		CiAssert.isTrue( FilePath.fromFile("").fileName=="" );
		CiAssert.isTrue( FilePath.fromFile("").extension==null );
		CiAssert.isTrue( FilePath.fromDir("").fileName==null );
		CiAssert.isTrue( FilePath.fromFile("./f.png").directory=="." );
		CiAssert.isTrue( FilePath.fromFile(".htaccess").fileName=="" );
		CiAssert.isTrue( FilePath.extractDirWithSlash("../a\\b/file.png")=="../a/b/" );

		// Done!
		Sys.println("");
		Sys.println("Tests succcessfully completed!");
	}
}