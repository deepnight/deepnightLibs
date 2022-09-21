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

#if sys
// List of codes: https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences?redirectedfrom=MSDN
enum abstract DosColor(Int) to Int {
	var Sys_Black = 90;
	var Sys_Red = 91;
	var Sys_Green = 92;
	var Sys_Yellow = 93;
	var Sys_Blue = 94;
	var Sys_Magenta = 95;
	var Sys_Cyan = 96;
	var Sys_White = 97;
}
#end

class Lib {

	/**  Print a line to standard output, if any (shortcut for println) **/
	public static inline function p(v:Dynamic) println(v);

	/** Print a line to standard output, if any **/
	public static function println(v:Dynamic) {
		#if js
			js.html.Console.log( Std.string(v) );
		#elseif neko
			neko.Lib.println( Std.string(v) );
		#elseif flash
			trace( Std.string(v) );
		#elseif sys
			Sys.println( Std.string(v) );
		#else
			trace( Std.string(v) );
		#end
	}

	/** Print a string to standard output without newline character, if any. Might not be supported everywhere. **/
	public static function print(v:Dynamic) {
		#if js
			js.html.Console.log( Std.string(v) );
		#elseif neko
			neko.Lib.print( Std.string(v) );
		#elseif flash
			trace( Std.string(v) );
		#elseif sys
			Sys.print( Std.string(v) );
		#else
			trace( Std.string(v) );
		#end
	}


	#if sys
	/**
		Print to standard DOS output a colored text using Escape sequences.

		Source: https://stackoverflow.com/questions/2048509/how-to-echo-with-different-colors-in-the-windows-command-line
	**/
	public static function printDosColor(str:String, color:DosColor) {
		Sys.command("echo ["+color+"m"+str+"[0m");
	}
	#end


	/** Print an array standard output, if any **/
	public static inline function printArray(v:Array<Dynamic>) {
		for(e in v)
			println(e);
	}



	/**
		Escape specificied character in given string, but doesn't re-escape if it's already.
	**/
	public static inline function safeEscape(str:String, escapedChar:String) : String {
		var r = new EReg( "([^\\\\]|^)\\"+escapedChar, "gim" );
		return r.replace(str, "$1\\"+escapedChar);
	}


	#if !macro

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

	/**
		Trim (left and right) and any whitespace character (space, tab, end of line, etc.)
	**/
	static var L_WHITESPACE_TRIM = ~/^\s*/gi;
	static var R_WHITESPACE_TRIM = ~/\s*$/gi;
	public static inline function wtrim(str:String) {
		if( str==null )
			return "";
		else {
			str = L_WHITESPACE_TRIM.replace(str, "");
			str = R_WHITESPACE_TRIM.replace(str, "");
			return str;
		}
	}

	public static inline function repeatChar(c:String, n:Int) {
		var out = "";
		for(i in 0...n)
			out+=c;
		return out;
	}

	/** Add `padChar` at the beginning of given String to ensure its length is at least `minLen` **/
	public static inline function padLeft(str:String, minLen:Int, padChar=" ") {
		while( str.length<minLen )
			str=padChar+str;
		return str;
	}

	/** Add `padChar` at the end of given String to ensure its length is at least `minLen` **/
	public static inline function padRight(str:String, minLen:Int, padChar=" ") {
		while( str.length<minLen )
			str+=padChar;
		return str;
	}

	/** Add `padChar` at the end of given String to ensure its length is at least `minLen` **/
	public static inline function padCenter(str:String, minLen:Int, padChar=" ") {
		var side = true;
		while( str.length<minLen ) {
			str = side ? str+padChar : padChar+str;
			side = !side;
		}
		return str;
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

	/** Return TRUE if given value exists in Array **/
	public static function arrayContains<T>(arr:Array<T>, v:T, ?checkElement:T->Bool) : Bool {
		for(e in arr)
			if( checkElement!=null && checkElement(e) || e==v )
				return true;
		return false;
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

		var f : Dynamic = Reflect.field(meta, Type.enumConstructor(e));
		if( f==null || !Reflect.hasField(f,varName) || !Std.isOfType(Reflect.field(f,varName)[0], Float) )
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
	public static function getArrayIndex<T>(v:T, arr:Array<T>) : Int {
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

	public static inline function parseSignedInt(v:String) : Int {
		#if js
		return ( cast Std.parseInt(v):Int ) & 0xffffffff;
		#else
		return Std.parseInt(v);
		#end
	}


	/**
		Return TRUE if rectangle A touches or overlaps rectangle B.
	**/
	public static inline function rectangleTouches(aX:Float, aY:Float, aWid:Float, aHei:Float, bX:Float, bY:Float, bWid:Float, bHei:Float) {
		/*
		Source: https://www.baeldung.com/java-check-if-two-rectangles-overlap

		"The two given rectangles won't overlap if either of the below conditions is true:
			One of the two rectangles is above the top edge of the other rectangle
			One of the two rectangles is on the left side of the left edge of the other rectangle"
		*/
		if( aY+aHei < bY || bY+bHei < aY )
			return false;
		else if( aX+aWid < bX || bX+bWid < aX )
			return false;
		else
			return true;
	}


	/**
		Return TRUE if rectangle A overlaps (NOT just touches) rectangle B.
	**/
	public static inline function rectangleOverlaps(aX:Float, aY:Float, aWid:Float, aHei:Float, bX:Float, bY:Float, bWid:Float, bHei:Float) {
		/*
		Source: https://www.baeldung.com/java-check-if-two-rectangles-overlap

		"The two given rectangles won't overlap if either of the below conditions is true:
			One of the two rectangles is above the top edge of the other rectangle
			One of the two rectangles is on the left side of the left edge of the other rectangle"
		*/
		if( aY+aHei <= bY || bY+bHei <= aY )
			return false;
		else if( aX+aWid <= bX || bX+bWid <= aX )
			return false;
		else
			return true;
	}

	static function iterateArrayRec( arr:Array<Dynamic>, cb:(value:Dynamic, setter:Dynamic->Void)->Void ) {
		for(i in 0...arr.length) {
			switch Type.typeof( arr[i] ) {
				case TObject:
					iterateObjectRec(arr[i], cb);

				case TClass(Array):
					iterateArrayRec(arr[i], cb);

				case _:
			}
			cb(arr[i], (v)->arr[i]=v);
		}
	}

	public static function iterateObjectRec( obj:Dynamic, cb:(value:Dynamic, setter:Dynamic->Void)->Void ) {
		if( obj==null )
			return;

		for( k in Reflect.fields(obj) ) {
			var f : Dynamic = Reflect.field(obj,k);
			switch Type.typeof(f) {
				case TObject:
					iterateObjectRec( f, cb );

				case TClass(Array):
					iterateArrayRec(f, cb);

				case _:
			}
			cb(f, (v)->Reflect.setField(obj, k, v));
		}
	}


	/** Remove leading and trailing empty lines in a multi-lines String. **/
    public static function trimEmptyLines(str:String) {
        var lines = str.split("\n");
        while( lines.length>0 && StringTools.trim(lines[0]).length==0 )
            lines.shift();

        while( lines.length>0 && StringTools.trim(lines[lines.length-1]).length==0 )
            lines.pop();

        return lines.join("\n");
    }

	static var VOWELS = [ "a"=>true, "e"=>true, "i"=>true, "o"=>true, "u"=>true, "y"=>true, ];
	static inline function isVowel(c:String) {
		return c!=null && c.length>=1 && VOWELS.exists( c.charAt(0).toLowerCase() );
	}
	static inline function isConsonant(c:String) {
		return c!=null && c.length>=1 && !VOWELS.exists( c.charAt(0).toLowerCase() ) && ( c>="a" && c<="z" || c>="A" && c<="Z" );
	}


	/**
		Create a "short name" from a long one by removing lowercase vowels (eg. "AVeryLongName" => "AVrLngNm")
	**/
	public static function buildShortName(longName:String, maxLen=8) {
		var out = "";
		var i = 0;
		var c = "";
		while( out.length<maxLen && i<longName.length ) {
			c = longName.charAt(i);
			switch c {
				case _ if( i==0 ): // First char
					out+=c;

				case _ if( isConsonant(c) ): // Consonants
					out+=c;

				case _ if( c>="A" && c<="Z" ): // Caps
					out+=c;

				case _:
			}
			i++;
		}
		return out;
	}

	@:noCompletion
	public static function __test() {
		CiAssert.equals( findMostFrequentValueInArray([0,0,1,0,1]), 0 );
		CiAssert.equals( findMostFrequentValueInArray([5,0,1,0,1]), 0 );
		CiAssert.equals( findMostFrequentValueInArray([5,1,0,0,1]), 1 );
		CiAssert.equals( findMostFrequentValueInArray(["a","b","c","b"]), "b" );
		CiAssert.equals( findMostFrequentValueInArray([ {v:1}, {v:2}, {v:2} ], (a,b)->a.v==b.v ).v, 2 );
		CiAssert.equals( findMostFrequentValueInArray([ {v:1}, {v:2}, {v:1} ], (a,b)->a.v==b.v ).v, 1 );

		CiAssert.equals( getArrayIndex(7, [4,9,10,7,14]), 3 );
		CiAssert.equals( leadingZeros(14,4), "0014" );
		CiAssert.equals( leadingZeros(14,0), "14" );

		CiAssert.equals( parseSignedInt("0xaaffcc00"), 0xaaffcc00 );
		CiAssert.equals( parseSignedInt("0xffffffff"), 0xffffffff );
		CiAssert.equals( parseSignedInt("0xffffff"), 0xffffff );
		CiAssert.equals( parseSignedInt("0x00ffffff"), 0x00ffffff );

		CiAssert.equals( getWeekDay(Date.fromString("2020-11-03 10:44:37")), Tuesday );
		CiAssert.equals( getWeekDay(Date.fromString("2020-11-04 00:00:00")), Wednesday );

		CiAssert.isTrue( rectangleTouches(0,0,5,5, 0,5,1,1) );
		CiAssert.isTrue( rectangleTouches(0,0,5,5, 5,5,1,1) );
		CiAssert.isTrue( rectangleTouches(0,0,5,5, 2,2,1,1) );
		CiAssert.isTrue( rectangleTouches(2,2,1,1, 0,0,5,5) );
		CiAssert.isFalse( rectangleTouches(0,0,5,5, 0,6,1,1) );
		CiAssert.isFalse( rectangleTouches(0,0,5,5, -3,-3,1,1) );

		CiAssert.isFalse( rectangleOverlaps(0,0,5,5, 0,5,1,1) );
		CiAssert.isFalse( rectangleOverlaps(0,0,5,5, -1,0,1,1) );
		CiAssert.isTrue( rectangleOverlaps(0,0,5,5, 2,2,1,1) );
		CiAssert.isTrue( rectangleOverlaps(2,2,1,1, 0,0,5,5) );

		CiAssert.equals( safeEscape(' \"hello\" ', '"'),	' \\"hello\\" ');
		CiAssert.equals( safeEscape(' "hello" ', '"'),		' \\"hello\\" ');
		CiAssert.equals( safeEscape(' "hello" \"world" ', '"'), ' \\"hello\\" \\"world\\" ');

		CiAssert.equals( wtrim('  \thello  \t  \r\n'), 'hello' );
		CiAssert.equals( wtrim(' \t '), '' );
		CiAssert.equals( wtrim(''), '' );
		CiAssert.equals( wtrim(null), '' );
	}

	#end // End of "if macro"
}
