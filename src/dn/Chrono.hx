package dn;

/**
	Basic "chronometer" class.
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
		all.push({
			id: id!=null ? id : DEFAULT_ID,
			t: haxe.Timer.stamp(),
		});
	}

	static function exists(id:String) {
		for(c in all)
			if( c.id==id )
				return true;
		return false;
	}

	/**
		Start or stop a chrono
	**/
	public static inline function t(id:String) {
		if( exists(id) )
			stop(id);
		else
			start(id);
	}

	/**
		Stop all existing chrono then start a new one
	**/
	public static inline function startSingle(?id:String) {
		while( all.length>0 )
			stop();

		all.push({
			id: id!=null ? id : DEFAULT_ID,
			t: haxe.Timer.stamp(),
		});
	}


	/**
		Stop a chrono, print result and return elapsed time.
	 **/
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
			for(i in 0...all.length)
				if( all[i].id==id ) {
					var t = haxe.Timer.stamp() - all[i].t;
					print('${all[i].id}: ${M.pretty(t)}s');
					all.splice(i,1);
					return t;
				}

			throw 'Unknown chrono $id';
		}
	}
}