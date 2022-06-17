package dn;

class DecisionHelper<T> {
	static inline var DISCARDED = -1e+20;

	var values : Iterable<T>;
	var scores : Map<Int, Float>;

	public inline function new(a:Iterable<T>) {
		values = a;
		scores = new Map();
	}

	inline function getScore(idx:Int) : Float {
		if( !scores.exists(idx) )
			scores.set(idx, 0);
		return scores.get(idx);
	}

	inline function setScore(idx:Int, s:Float) {
		scores.set(idx, s);
	}

	inline function discard(idx:Int) {
		scores.set(idx, DISCARDED);
	}

	inline function isDiscarded(idx:Int) {
		return scores.exists(idx) && scores.get(idx)==DISCARDED;
	}


	/**
		Pick a single value from an Iterable without allocating an actual DecisionHelper.

		**IMPORTANT**: to avoid memory allocations, **make sure the provided `score` method is a class method instead of a callback defined on-the-fly.

		If the score of the best element is <= to `minScoreDiscard`, then the pick returns `null`.
	**/
	public static inline function optimizedPick<T>(all:Iterable<T>, score:T->Float, minScoreDiscard=-999999) : Null<T> {
		var best : T = null;
		var bestScore = -999999.;
		var s = 0.;
		for(e in all) {
			s = score(e);
			if( s>bestScore ) {
				best = e;
				bestScore = s;
			}
		}
		return bestScore<=minScoreDiscard ? null : best;
	}

	/** Reset scores and removals **/
	public function reset() {
		scores = new Map();
	}

	/** Discard any values where `cb(value)` returns TRUE. **/
	public inline function remove( cb:T->Bool ) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) && cb(v) )
				discard(idx);
			idx++;
		}
	}

	/** Discard specified value **/
	public inline function removeValue(search:T) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) && v==search )
				discard(idx);
			idx++;
		}
	}

	/** Keep only values where `cb(value)` returns TRUE. **/
	public inline function keepOnly( cb:T->Bool ) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) && !cb(v) )
				discard(idx);
			idx++;
		}
	}

	/** Score non-discarded values using given method **/
	public inline function score( cb:T->Float ) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) )
				setScore( idx, getScore(idx) + cb(v) );
			idx++;
		}
	}

	/** Return the number of non-discarded values **/
	public inline function countRemaining() {
		var n = 0;
		var idx = 0;
		for(v in values)
			if( !isDiscarded(idx++) )
				n++;
		return n;
	}

	/** Return TRUE if at least one value isn't discarded. **/
    public inline function hasRemaining() return !isEmpty();

	/** Return TRUE if at all values were discarded. **/
	public function isEmpty() {
		var idx = 0;
		for(v in values)
			if( !isDiscarded(idx++))
                return false;
		return true;
	}

	/** Iterate all non-discarded values. The callback `cb` gets the value and its score as arguments. **/
	public inline function iterateRemainings( cb : (value:T,score:Float)->Void ) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) )
				cb(v, getScore(idx));
			idx++;
		}
	}

	/** Return the non-discarded value with the highest score. **/
	public function getBest() : Null<T> {
		var bestIdx = -1;
		var best : Null<T> = null;
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) && ( bestIdx<0 || getScore(idx)>getScore(bestIdx) ) ) {
				best = v;
				bestIdx = idx;
			}
			idx++;
		}

		return best;
	}

	/** Run a callback on the best value (ie. non-discarded and highest score) **/
	public inline function useBest(action:T->Void) : Null<T> {
		var e = getBest();
		if( e!=null )
			action(e);
		return e;
	}

	/** Pick a random value among all non-discardeds **/
	public function getRemainingRandomWithoutScore(rndFunc:Int->Int) : Null<T> {
		var count = countRemaining();
		if( count==0 )
			return null;
		else {
			var idx = 0;
			var targetPickIdx = rndFunc(count);
			var curPickIdx = 0;
			for(v in values) {
				if( !isDiscarded(idx) ) {
					if( curPickIdx==targetPickIdx )
						return v;
					curPickIdx++;
				}
				idx++;
			}
			return null;
		}
	}


	@:noCompletion
	public static function __test() {
		var arr = [ "a", "foo", "bar", "food", "hello", "longworld" ];

		// Filtering
		var dh = new dn.DecisionHelper(arr);
		dh.keepOnly( v->StringTools.contains(v,"o") ); // with letter "o"
		dh.remove( v->StringTools.contains(v,"l") ); // no letter "l"
		dh.score( v -> v.length*0.1 ); // longer is better
		CiAssert.equals( dh.countRemaining(), 2 );
		CiAssert.equals( dh.getBest(), "food" );

		var ok = false;
		dh.useBest( v->ok = (v=="food") );
		CiAssert.isTrue(ok);

		var dh = new dn.DecisionHelper(arr);
		dh.score( v -> v.length*0.1 ); // longer is better
		CiAssert.equals( dh.getBest(), "longworld" );
		dh.remove( v -> StringTools.contains(v,"w") ); // no letter "w"
		CiAssert.equals( dh.getBest(), "hello" );

		dh.keepOnly( v -> StringTools.contains(v,"z") ); // with letter "z"
		CiAssert.equals( dh.isEmpty(), true );

		// FixedArray
		var fa = new dn.struct.FixedArray(5);
		fa.push("foo");
		fa.push("bar");
		fa.push("hello");
		fa.push("longworld");

		var dh = new DecisionHelper(fa);
		dh.keepOnly( v -> StringTools.contains(v,"o") ); // with letter "o"
		dh.score( v -> -v.length ); // shorter is better
		CiAssert.equals(dh.getBest(), "foo");
	}
}