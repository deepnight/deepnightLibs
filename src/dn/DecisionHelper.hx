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

	public inline function useBest(action:T->Void) {
		var e = getBest();
		if( e!=null )
			action(e);
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
}