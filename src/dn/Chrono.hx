package dn;

/**
	Simple debug "chronometer" class.

	**NOTE**: this class will do nothing if `-debug` compiler option isn't set.
**/
class Chrono {
	static var DEFAULT_ID = "";
	static var all : Array<{ id:String, t:Float }> = [];

	public static inline function reset() {
		all = [];
	}

	/**
		Print chrono result to output. Can be replaced by your own callback.
	**/
	public static dynamic function print(str:String) {
		trace(str);
	}

	/**
		Start a chrono
	**/
	public static inline function start(?id:String) {
		#if !debug
		all.push({
			id: id!=null ? id : DEFAULT_ID,
			t: haxe.Timer.stamp(),
		});
		#end
	}

	/**
		Stop all existing chrono then start a new one
	**/
	public static inline function startSingle(?id:String) {
		#if !debug
		while( all.length>0 )
			stop();

		all.push({
			id: id!=null ? id : DEFAULT_ID,
			t: haxe.Timer.stamp(),
		});
		#end
	}


	/**
		Stop a chrono, print result and return elapsed time.
	 **/
	#if !debug
	public static inline function stop(?id:String) : Float  return 0.;
	#else
	public static function stop(?id:String) : Float {
		if( all.length==0 )
			return 0;

		if( id==null ) {
			var last = all.pop();
			var t = haxe.Timer.stamp() - last.t;
			print('${last.id}: ${t}s');
			return t;
		}
		else {
			for(c in all)
				if( c.id==id ) {
					var t = haxe.Timer.stamp() - c.t;
					print('${c.id}: ${M.pretty(t)}s');
					return t;
				}

			throw 'Unknown chrono $id';
		}
	}
	#end
}