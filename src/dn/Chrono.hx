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
	public static var DECIMALS = 3;
	static var DEFAULT_ID = "";

	static var all : Array<{ id:String, t:Float }> = [];
	static var results : Array<{ id:String, t:Float }> = [];


	/** Init chrono session **/
	public static inline function init() {
		all = [];
		results = [];
	}


	/**
		Stop every chrono then return results as an Array of Strings (one line per result)
	**/
	public static inline function getResultsStr() {
		stopAll();
		return results.map( (r)->( r.id=="" || r.id==null ? "" : r.id+" => " ) + M.pretty(r.t,DECIMALS)+"s" );
	}

	/**
		Stop every chrono then print results using `printer()` method (defaults to `trace()`).
	**/
	public static inline function printResults(init=true) {
		stopAll();
		var res = getResultsStr();
		if( res.length>1 )
			printer("--Chrono--");
		for(r in res)
			printer(r);

		if( init )
			Chrono.init();
	}


	/**
		Print something to output (default is `trace()`). This method can be replaced by a custom method.
	**/
	public static dynamic function printer(str:String) {
		#if sys
			Sys.println(str);
		#elseif js
			js.html.Console.log(str);
		#else
			trace(str);
		#end
	}

	/**
		Start a chrono
	**/
	public static inline function start(?id:String, stopAllOthers=false) {
		id = id!=null ? id : DEFAULT_ID;

		if( stopAllOthers )
			stopAll();
		else
			stop(id);

		all.push({ id:id, t:haxe.Timer.stamp() });
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


	/**
		Stop every running chrono
	**/
	public static inline function stopAll() {
		while( all.length>0 )
			stop();
	}

	/**
		Stop a chrono and return elapsed time (in seconds). If `id` is not provided, stops only the last one.
	 **/
	public static function stop(?id:String) : Float {
		if( all.length==0 )
			return 0;

		if( id==null ) {
			var last = all.pop();
			var t = haxe.Timer.stamp() - last.t;
			results.push({ id:last.id, t:t });
			return t;
		}
		else {
			for(i in 0...all.length)
				if( all[i].id==id ) {
					var t = haxe.Timer.stamp() - all[i].t;
					results.push({ id:all[i].id, t:t });
					all.splice(i,1);
					return t;
				}

			throw 'Unknown chrono $id';
		}
	}
}