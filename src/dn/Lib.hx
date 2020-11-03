package dn;

import dn.M;

enum WeekDay {
	Sunday;
	Monday;
	Tuesday;
	Wednesday;
	Thursday;
	Friday;
	Saturday;
}

class Lib {
	public static inline function countDaysUntil(now:Date, day:WeekDay) {
		var delta = Type.enumIndex(day) - now.getDay();
		return if(delta<0) 7+delta else delta;
	}

	public static inline function getWeekDay(date:Date) : WeekDay {
		return Type.createEnumIndex(WeekDay, date.getDay());
	}

	public static inline function setTime(date:Date, h:Int, ?m=0,?s=0) {
		var str = "%Y-%m-%d "+StringTools.lpad(""+h,"0",2)+":"+StringTools.lpad(""+m,"0",2)+":"+StringTools.lpad(""+s,"0",2);
		return Date.fromString( DateTools.format(date, str) );
	}

	public static inline function countDeltaDays(now:Date, next:Date) {
		var now = setTime(now, 5);
		var next = setTime(next, 5);
		return M.floor( (next.getTime() - now.getTime()) / DateTools.days(1) );
	}

	public static inline function leadingZeros(s:Dynamic, ?zeros=2) {
		var str = Std.string(s);
		while (str.length<zeros)
			str="0"+str;
		return str;
	}

	public static inline function repeatChar(c:String, n:Int) {
		var out = "";
		for(i in 0...n)
			out+=c;
		return out;
	}

	#if neko
	public static function drawExcept<T>(a:List<T>, except:T, ?randFn:Int->Int):T {
		if (a.length==0)
			return null;
		if (randFn==null)
			randFn = Std.random;
		var a2 = new Array();
		for (elem in a)
			if (elem!=except)
				a2.push(elem);
		return
			if (a2.length==0)
				null;
			else
				a2[ randFn(a2.length) ];

	}
	#end


	#if( heaps )
	public static function redirectTracesToH2dConsole(c:h2d.Console) {
		haxe.Log.trace = function(m, ?pos) {
			if ( pos != null && pos.customParams == null )
				pos.customParams = ["debug"];

			c.log(pos.fileName + "(" + pos.lineNumber + ") : " + Std.string(m));
		}
	}
	#end

	#if h3d
   /**
	* guarantees that the screen will return some correctly size bitmap...
	*/
	public static function h2dScreenshot(s:h2d.Scene, ?target:h2d.Tile, ?bindDepth=false) : h2d.Bitmap {
		var engine = h3d.Engine.getCurrent();
		var ww = Math.round(s.width);
		var wh = Math.round(s.height);

		var tw = hxd.Math.nextPow2(ww);
		var th = hxd.Math.nextPow2(wh);

		if( target == null ) {
			var tex = new h3d.mat.Texture(tw, th, h3d.mat.Texture.TargetFlag());
			target = new h2d.Tile(tex, 0, 0, tw, th);
			target.scaleToSize(ww, wh);
			#if cpp
			target.targetFlipY();
			#end
		}

		engine.triggerClear = true;

		var tex = target.getTexture();
		engine.setTarget(tex, bindDepth);
		engine.setRenderZone();

		engine.begin();
		s.render(engine);
		engine.end();

		s.set_posChanged(true);

		engine.setTarget(null, false, null);
		engine.setRenderZone();

		return new h2d.Bitmap(target);
	}
	#end


	/**
		Shuffle an array in place
	**/
	public static function shuffleArray<T>(arr:Array<T>, randFunc:Int->Int) {
		// WARNING!! Now modifies the array itself (changed on Apr. 27 2016)
		// Source: http://bost.ocks.org/mike/shuffle/
		var m = arr.length;
		var i = 0;
		var tmp = null;
		while( m>0 ) {
			i = randFunc(m--);
			tmp = arr[m];
			arr[m] = arr[i];
			arr[i] = tmp;
		}
	}

	/**
		Shuffle a vector in place
	**/
	public static function shuffleVector<T>(arr:haxe.ds.Vector<T>, randFunc:Int->Int) {
		// Source: http://bost.ocks.org/mike/shuffle/
		var m = arr.length;
		var i = 0;
		var tmp = null;
		while( m>0 ) {
			i = randFunc(m);
			m--;
			tmp = arr[m];
			arr[m] = arr[i];
			arr[i] = tmp;
		}
	}

	/** Find a value in an Array **/
	public static function findInArray<T>(arr:Array<T>, checkElement:T->Bool, ?defaultIfNotFound:Null<T>) : Null<T> {
		for(e in arr)
			if( checkElement(e) )
				return e;
		return defaultIfNotFound;
	}

	/** Score Array values and return best one **/
	public static function findBestInArray<T>(arr:Array<T>, scoreElement:T->Float) : Null<T> {
		if( arr.length==0 )
			return null;

		var best = arr[0];
		for(e in arr)
			if( scoreElement(e) > scoreElement(best) )
				best = e;
		return best;
	}

	/**
		Return most frequent value in given Array.

		An equality check `isEqual` method should be provided for arrays containing non-standard types.
	**/
	public static function findMostFrequentValueInArray<T>(arr:Array<T>, ?isEqual:(a:T,b:T)->Bool) : Null<T> {
		if( arr.length==0 )
			return null;

		var bestCount = 1;
		var best = arr[0];
		for(e in arr) {
			if( isEqual==null && e==best || isEqual!=null && isEqual(e,best) )
				continue;

			var count = 0;
			for(ee in arr)
				if( isEqual==null && ee==e || isEqual!=null && isEqual(e,ee) )
					count++;

			if( count>bestCount ) {
				bestCount = count;
				best = e;
			}

		}
		return best;
	}

	/**
		Randomly spread `total` in `nbStacks`.
	**/
	public static function randomSpread(total:Int, nbStacks:Int, ?maxStackValue:Null<Int>, randFunc:Int->Int) : Array<Int> {
		if (total<=0 || nbStacks<=0)
			return new Array();

		if( maxStackValue!=null && total/nbStacks>maxStackValue ) {
			var a = [];
			for(i in 0...nbStacks)
				a.push(maxStackValue);
			return a;
		}

		if( nbStacks>total ) {
			var a = [];
			for(i in 0...total)
				a.push(1);
			return a;
		}

		var plist = new Array();
		for (i in 0...nbStacks)
			plist[i] = 1;

		var remain = total-plist.length;
		while (remain>0) {
			var move = M.ceil(total*(randFunc(8)+1)/100);
			if (move>remain)
				move = remain;

			var p = randFunc(nbStacks);
			if( maxStackValue!=null && plist[p]+move>maxStackValue )
				move = maxStackValue - plist[p];
			plist[p]+=move;
			remain-=move;
		}
		return plist;
	}

	public static inline function replaceTag(str:String, char:String, open:String, close:String) {
		var char = "\\"+char.split("").join("\\");
		var re = char+"([^"+char+"]+)"+char;
		return try { new EReg(re, "g").replace(str, open+"$1"+close); } catch (e:String) { str; }
	}

	/** Return closest next power of 2, `n` being 32bits **/
	public static inline function getNextPower2_32bits(n:Int) { // n est sur 32 bits
		n--;
		n |= n >> 1;
		n |= n >> 2;
		n |= n >> 4;
		n |= n >> 8;
		n |= n >> 16;
		return n+1;
	}

	/** Return closest next power of 2, `n` being 8bits **/
	public static inline function getNextPower2_8bits(n:Int) { // n est sur 8 bits
		n--;
		n |= n >> 1;
		n |= n >> 2;
		n |= n >> 4;
		return n+1;
	}

	/** Random Float value **/
	public static inline function rnd(min:Float, max:Float, sign=false) {
		if( sign )
			return (min + Math.random()*(max-min)) * (Std.random(2)*2-1);
		else
			return min + Math.random()*(max-min);
	}

	/** Random Integer value **/
	public static inline function irnd(min:Int, max:Int, sign=false) {
		if( sign )
			return (min + Std.random(max-min+1)) * (Std.random(2)*2-1);
		else
			return min + Std.random(max-min+1);
	}


	/** Return a pretty time value "HHh MMm SSs" from a timestamp or a duration (trying to guess) **/
	public static inline function prettyTime(t:Float) : String {
		if( t<=DateTools.days(365) ) {
			// Duration
			var s = M.fabs(t)/1000;
			var m = s/60;
			var h = m/60;
			h = Std.int(h%24);
			return (t<0?"-":"") + (h>0?h+"h ":"") + leadingZeros(Std.int(m%60))+"m "+leadingZeros(Std.int(s%60))+"s";
		}
		else {
			// Probably really a timestamp
			return DateTools.format(Date.fromTime(t), "%Hh %Mm %Ss (%Y-%m-%d)");
		}
	}

	/**
		Crash client if it's hosted in some wrong place
	**/
	public static function ludumProtection(p:dn.Process, ?allowLocal=true) : Bool {
		var ok = false;
		var s = "d"+"e"+"e"+"p"+""+"n"+"i"+""+"g"+""+"h"+"t";

		#if flash
			var d = flash.system.Security.pageDomain;
			var url = flash.Lib.current.stage.loaderInfo.url;
			ok =
				d!=null && d.indexOf(s+"."+"n"+"e"+"t")>=0
				|| url.indexOf("app:/")==0 // AIR
				|| allowLocal && url!=null && url.indexOf(s)>=0 && url.indexOf("fi"+"le"+":")>=0; // local file
		#elseif js
			var d = js.Browser.document.URL;
			ok =
				d.indexOf(s+"."+"n"+"e"+"t")>=0
				|| allowLocal && d.indexOf("file://")==0;
		#else
			ok = true;
		#end

		#if debug
		ok = true;
		#end

		if( !ok ) {
			p.delayer.addS(function() {
				p.cd = null; // crash randomly later
			}, rnd(4,7));
		}

		return ok;
	}



	public static function getEnumMetaFloat<T:EnumValue>(e:T, varName:String, ?def=0.) : Float {
		var meta = haxe.rtti.Meta.getFields( Type.getEnum(e) );
		if( meta==null )
			return def;

		var f = Reflect.field(meta, Type.enumConstructor(e));
		if( f==null || !Reflect.hasField(f,varName) || !Std.is(Reflect.field(f,varName)[0], Float) )
			return def;

		var v : Float = Reflect.field(f,varName)[0];
		return Math.isNaN(v) ? def : v;
	}

	public static inline function getEnumMetaInt<T:EnumValue>(e:T, varName:String, ?def=0) : Int {
		return Std.int( getEnumMetaFloat(e, varName, def) );
	}


	#if heaps
	static var fullscreenEnabled = false;
	/**
		Enable fullscreen button in bottom right corner
	**/
	public static function enableFullscreen(scene:h2d.Scene, p:dn.Process, ?alternativeKey:Int, button:Bool) {
		if( fullscreenEnabled )
			return;

		fullscreenEnabled = true;

		#if js

		var canvas = js.Browser.document.getElementById("webgl");

		if( button ) {
			var w = 24;
			var g = new h2d.Graphics(scene);
			g.alpha = 0.7;
			g.blendMode = None;
			g.beginFill(0x0,1);
			g.drawRect(0,0,w,w);
			g.endFill();

			g.lineStyle(2,0xffffff,1);
			g.moveTo(w*0.1, w*0.3);
			g.lineTo(w*0.1, w*0.1);
			g.lineTo(w*0.3, w*0.1);
			g.moveTo(w*0.1,w*0.1);
			g.lineTo(w*0.35, w*0.35);

			g.moveTo(w*0.7, w*0.1);
			g.lineTo(w*0.9, w*0.1);
			g.lineTo(w*0.9, w*0.3);
			g.moveTo(w*0.9,w*0.1);
			g.lineTo(w*0.65, w*0.35);

			g.moveTo(w*0.9, w*0.7);
			g.lineTo(w*0.9, w*0.9);
			g.lineTo(w*0.7, w*0.9);
			g.moveTo(w*0.9,w*0.9);
			g.lineTo(w*0.65, w*0.65);

			g.moveTo(w*0.1, w*0.7);
			g.lineTo(w*0.1, w*0.9);
			g.lineTo(w*0.3, w*0.9);
			g.moveTo(w*0.1,w*0.9);
			g.lineTo(w*0.35, w*0.65);

			canvas.addEventListener( "click", function(e) {
				var rect = canvas.getBoundingClientRect();
				var x = e.clientX - rect.left;
				var y = e.clientY - rect.top;
				if( !isFullscreen() && x>=g.x && x<g.x+w && y>=g.y && y<g.y+w )
					toggleFullscreen();
			});

			p.createChildProcess( function(_) {
				g.x = p.w()-w-2;
				g.y = 2;
				g.visible = !isFullscreen();
			});
		}

		canvas.addEventListener("keydown",function(e) {
			if( alternativeKey!=null && e.keyCode==alternativeKey || e.keyCode==hxd.Key.ENTER && e.altKey || e.keyCode==hxd.Key.F11 )
				toggleFullscreen();
		});

		#else

		p.createChildProcess( function(_) {
			if( alternativeKey!=null && hxd.Key.isPressed(alternativeKey) || hxd.Key.isDown(hxd.Key.ALT) && hxd.Key.isPressed(hxd.Key.ENTER) || hxd.Key.isPressed(hxd.Key.F11) )
				toggleFullscreen();
		});

		#end
	}

	/** Return TRUE if in fullscreen (if supported) **/
	public static inline function isFullscreen() : Bool {
		#if js
			return (cast js.Browser.document).fullscreen;
		#elseif hl
			return h3d.Engine.getCurrent().fullScreen;
		#else
			return false;
		#end
	}

	/** Toggle client fullscreen, if supported **/
	public static function toggleFullscreen() {
		#if js
			if( isFullscreen() )
				(cast js.Browser.document).exitFullscreen();
			else
				(cast js.Browser.document.getElementById("webgl")).requestFullscreen(); // Warning: only works if called from a user-generated event
		#else
			h3d.Engine.getCurrent().fullScreen = !h3d.Engine.getCurrent().fullScreen;
		#end
	}
	#end

	// public static function preventBrowserGameKeyEvents() {
	// 	#if( heaps && js )
	// 	(@:privateAccess hxd.Window.getInstance().element).addEventListener("keydown", function(ev:js.html.KeyboardEvent) {
	// 		switch ev.keyCode {
	// 			case 37, 38, 39, 40, // Arrows
	// 				33, 34, // Page up/down
	// 				35, 36, // Home/end
	// 				8, // Backspace
	// 				16, // Shift
	// 				17 : // Ctrl
	// 					ev.preventDefault();
	// 			case _ :
	// 		}
	// 	});
	// 	#end
	// }

	/** Return array index of `v` in `arr` (-1 if not found) **/
	public static function getArrayIdx<T>(v:T, arr:Array<T>) : Int {
		if( arr.length==0 )
			return -1;

		for(i in 0...arr.length)
			if( arr[i]==v )
				return i;

		return -1;
	}

	/** Return a pretty bytes size value (bytes, kilobytes, or megabytes)**/
	public static inline function prettyBytesSize(bytesCount:Int) : String {
		return
			bytesCount<=1024 ? '$bytesCount bytes'
			: bytesCount<=1024*1024 ? '${ M.pretty( bytesCount/1024, 1 ) } Kb'
			: '${ M.pretty( bytesCount/(1024*1024), 1 ) } Mb';
	}




	@:noCompletion
	public static function __test() {
		CiAssert.equals( findMostFrequentValueInArray([0,0,1,0,1]), 0 );
		CiAssert.equals( findMostFrequentValueInArray([5,0,1,0,1]), 0 );
		CiAssert.equals( findMostFrequentValueInArray([5,1,0,0,1]), 1 );
		CiAssert.equals( findMostFrequentValueInArray(["a","b","c","b"]), "b" );
		CiAssert.equals( findMostFrequentValueInArray([ {v:1}, {v:2}, {v:2} ], (a,b)->a.v==b.v ).v, 2 );
		CiAssert.equals( findMostFrequentValueInArray([ {v:1}, {v:2}, {v:1} ], (a,b)->a.v==b.v ).v, 1 );

		CiAssert.equals( getArrayIdx(7, [4,9,10,7,14]), 3 );
		CiAssert.equals( leadingZeros(14,4), "0014" );
		CiAssert.equals( leadingZeros(14,0), "14" );

		CiAssert.equals( getWeekDay(Date.fromString("2020-11-03 10:44:37")), Tuesday );
		CiAssert.equals( getWeekDay(Date.fromString("2020-11-04 00:00:00")), Wednesday );
	}
}
