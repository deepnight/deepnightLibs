package dn;

/**
	Basic "chronometer" class.
	 - `init()` to start a session
	 - to measure the time of a block, either:
	 	- call `start("someId")` and `stop("someId")` around the code block
		- or just call `start("someId",true)` (which stops all previous chrono before starting a new one) at the beginning of each block you need to measure
	 - `printResults()` or `getResultsStr()` to end session
**/

class Chrono {
	/** Precision **/
	public static var DECIMALS = 4;
	public static var COLORS_LOW = { timeThreshold:0.05, col:new Col("#009c44") }
	public static var COLORS_HIGH = { timeThreshold:0.50, col:new Col("#a10000") }

	static var all : Array<ChronoInstance> = [];
	static var results : Array<ChronoInstance> = [];


	/** Init chrono session **/
	public static inline function init() {
		all = [];
		results = [];
	}


	/**
		Stop every chrono then return results as an Array of Strings (one line per result)
	**/
	public static inline function getResultsStr() : Array<String> {
		stopAll();
		return results.map( (r)->r.toString() );
	}

	/**
		Stop every chrono then print results using `printer()` method (defaults to `trace()`).
	**/
	public static inline function printResults(init=true) {
		stopAll();
		// var res = getResultsStr();
		if( results.length>1 )
			printer("--Chrono--");
		for(r in results)
			printer(r.toString(), r.getColor());

		if( init )
			Chrono.init();
	}


	/**
		Print something to output (default is `trace()`). This method can be replaced by a custom method.
	**/
	public static dynamic function printer(str:String, ?col:dn.Col) {
		#if sys
			Sys.println(str);
		#elseif js
			if( col!=null )
				js.html.Console.log("%c"+str, "color:"+col.toHex());
			else
				js.html.Console.log(str);
		#else
			trace(str);
		#end
	}

	/**
		Start a chrono
	**/
	public static inline function start(?id:String, stopAllOthers=false) {
		if( stopAllOthers )
			stopAll();
		else if( id!=null )
			stopId(id);
		else
			stopLast();

		all.push( new ChronoInstance(id) );
	}

	/**
		Start a quick chrono, or stop it and print its result immediately.
	**/
	public static inline function quick(?id:String) {
		if( all.length==0 || id!=null && !exists(id) )
			start(id,true);
		else
			printResults();
	}

	/**
		Return TRUE if a chrono with this `id` exists
	**/
	public static function exists(id:String) {
		for(c in all)
			if( c.id==id )
				return true;
		return false;
	}


	public static function stopLast() : Float {
		var last = all.pop();
		last.stop();
		results.push(last);
		return last.elapsedS;
	}

	public static function stopId(id:String) : Float {
		for(i in 0...all.length)
			if( all[i].id==id ) {
				var c = all[i];
				c.stop();
				results.push(c);
				all.splice(i,1);
				return c.elapsedS;
			}
		return 0;
	}

	public static function stopAll() {
		for(c in all) {
			c.stop();
			results.push(c);
		}
		all = [];
	}
}


private class ChronoInstance {
	public var id(default,null): Null<String>;
	var startStamp: Float;
	var stopStamp: Float = -1;

	public var elapsedS(get,never) : Float;
		inline function get_elapsedS() {
			return stopStamp<0 ? haxe.Timer.stamp()-startStamp : stopStamp-startStamp;
		}

	public inline function new(?id) {
		this.id = id;
		startStamp = haxe.Timer.stamp();
	}

	public inline function isStopped() {
		return stopStamp>=0;
	}

	public function getColor() : Null<dn.Col> {
		if( !isStopped() )
			return null;
		else
			return Chrono.COLORS_LOW.col.to( Chrono.COLORS_HIGH.col, M.subRatio(elapsedS, Chrono.COLORS_LOW.timeThreshold, Chrono.COLORS_HIGH.timeThreshold) );
	}

	public inline function stop() {
		if( !isStopped() )
			stopStamp = haxe.Timer.stamp();
	}

	@:keep public function toString() {
		return
			( id=="" || id==null ? "" : id+" => " )
			+ M.pretty(elapsedS, Chrono.DECIMALS)+"s"
			+ ( !isStopped() ? " (running)" : "" );
	}
}
