package dn;


private class DecisionElement<T> {
	public var v : T;
	public var score = 0.;
	public var out = false;

	public function new(v:T) {
		this.v = v;
	}
}


class DecisionHelper<T> {
	var all : haxe.ds.Vector< DecisionElement<T> >;

	public function new(a:Array<T>) {
		all = new haxe.ds.Vector(a.length);
		var i = 0;
		for(v in a) {
			all.set(i, new DecisionElement(v));
			i++;
		}
	}

	public static inline function optimizedPick<T>(all:Array<T>, score:T->Float) : Null<T> {
		var best : T = null;
		var bestScore = -9999999.;
		var s = 0.;
		for(e in all) {
			s = score(e);
			if( s>bestScore ) {
				best = e;
				bestScore = s;
			}
		}
		return best;
	}

	public function reset() {
		for(e in all) {
			e.out = false;
			e.score = 0;
		}
	}

	public inline function remove( cb:T->Bool ) {
		for(e in all)
			if( !e.out && cb(e.v) )
				e.out = true;
	}

	public inline function removeValue(v:T) {
		for(e in all)
			if( !e.out && e.v==v )
				e.out = true;
	}

	public inline function keepOnly( cb:T->Bool ) {
		for(e in all)
			if( !e.out && !cb(e.v) )
				e.out = true;
	}

	public inline function score( cb:T->Float ) {
		for(e in all)
			if( !e.out )
				e.score+=cb(e.v);
	}

	public inline function countRemaining() {
		var n = 0;
		for(e in all)
			if( !e.out ) n++;
		return n;
	}

    public inline function hasRemaining() return !isEmpty();
	public function isEmpty() {
		for(e in all)
			if( !e.out )
                return false;
		return true;
	}

	public inline function iterateRemainings(cb:T->Float->Void) {
		for(e in all)
			if( !e.out )
				cb(e.v, e.score);
	}

	public function getBest() : Null<T> {
		var best : DecisionElement<T> = null;
		for(e in all)
			if( !e.out && ( best==null || e.score>best.score ) )
				best = e;

		return best==null ? null : best.v;
	}

	public inline function useBest(action:T->Void) : Null<T> {
		var e = getBest();
		if( e!=null )
			action(e);
		return e;
	}

	public function getRemainingRandomWithoutScore(rnd:Int->Int) : Null<T> {
		var idx = rnd( countRemaining() );
		var i = 0;
		for(e in all) {
			if( e.out )
				continue;
			if( i==idx )
				return e.v;
			i++;
		}
		return null;
	}


	@:noCompletion
	public static function __test() {
		var arr = [ "a", "foo", "bar", "food", "hello" ];
		var dh = new dn.DecisionHelper(arr);
		dh.score( v -> StringTools.contains(v,"o") ? 1 : 0 );
		dh.score( v -> v.length*0.1 );
		dh.remove( v -> StringTools.contains(v,"h") );
		dh.keepOnly( v -> v.length>1 );

		CiAssert.equals( dh.countRemaining(), 3 );
		CiAssert.equals( dh.getBest(), "food" );
		CiAssert.equals( new DecisionHelper([]).getBest(), null );
	}
}