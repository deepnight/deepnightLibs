package dn;

class DecisionHelper<T> {
	static inline var DISCARDED = -1e+20;

	var values : Iterable<T>;
	var scores : Map<Int, Float>;

	var asyncKeepers : Array< T->Bool >;
	var asyncDiscarders : Array< T->Bool >;
	var asyncScorers : Array< T->Float >;

	public var lastBest(default,null) : Null<T>;
	public var customData : Null<T>;

	public inline function new(a:Iterable<T>) {
		values = a;
		scores = new Map();
		asyncKeepers = null;
		asyncDiscarders = null;
		asyncScorers = null;
	}

	public inline function dispose() {
		values = null;
		scores = null;
		asyncKeepers = null;
		asyncDiscarders = null;
		asyncScorers = null;
		lastBest = null;
		customData = null;
	}

	inline function getScore(idx:Int) : Float {
		if( !scores.exists(idx) )
			scores.set(idx, 0);
		return scores.get(idx);
	}

	inline function setScore(idx:Int, s:Float) {
		scores.set(idx, s);
	}

	inline function discardIndex(idx:Int) {
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
		lastBest = null;
	}

	@:deprecated("Use discard()") @:noCompletion public inline function remove( cb:T->Bool ) discard(cb);
	/** Discard any values where `cb(value)` returns TRUE. **/
	public inline function discard( cb:T->Bool ) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) && cb(v) )
				discardIndex(idx);
			idx++;
		}
	}

	@:deprecated("Use discardValue()") @:noCompletion public inline function removeValue(search:T) discardValue(search);
	/** Discard specified value **/
	public inline function discardValue(search:T) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) && v==search )
				discardIndex(idx);
			idx++;
		}
	}

	/** Keep only values where `cb(value)` returns TRUE. **/
	public inline function keepOnly( cb:T->Bool ) {
		var idx = 0;
		for(v in values) {
			if( !isDiscarded(idx) && !cb(v) )
				discardIndex(idx);
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

		lastBest = best;
		return best;
	}

	/** Return the non-discarded value with the highest score, then removes it from the pool. **/
	public function getBestAndDiscard() : Null<T> {
		var best = getBest();
		if( best!=null )
			discardValue(best);
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



	@:deprecated("Use addAsyncKeep(...)") @:noCompletion public inline function addAsyncKeepMethod(cb:T->Bool) addAsyncKeep(cb);
	/**
		Register an asynchronous "keep" callback that will be ran with `applyAsyncMethods()`.
		The callback should return TRUE if the given element should be kept during the scoring phase.
		See `applyAsyncMethods()` for more info.
	**/
	public inline function addAsyncKeep(cb:T->Bool) {
		if( asyncKeepers==null )
			asyncKeepers = [];
		asyncKeepers.push(cb);
	}

	@:deprecated("Use addAsyncDiscard(...)") @:noCompletion public inline function addAsyncRemoveMethod(cb:T->Bool) addAsyncDiscard(cb);
	/**
		Register an asynchronous "discard" callback that will be ran with `applyAsyncMethods()`.
		The callback should return TRUE if the given element should be discarded during the scoring phase.
		See `applyAsyncMethods()` for more info.
	**/
	public inline function addAsyncDiscard(cb:T->Bool) {
		if( asyncDiscarders==null )
			asyncDiscarders = [];
		asyncDiscarders.push(cb);
	}


	@:deprecated("Use addAsyncScore(...)") @:noCompletion public inline function addAsyncScoreMethod(cb:T->Float) addAsyncScore(cb);
	/**
		Register an asynchronous "scoring" callback that will be ran with `applyAsyncMethods()`.
		The callback should return a Float "score" value for given element.
		See `applyAsyncMethods()` for more info.
	**/
	public inline function addAsyncScore(cb:T->Float) {
		if( asyncScorers==null )
			asyncScorers = [];
		asyncScorers.push(cb);
	}


	public inline function removeAllAsyncMethods() {
		asyncDiscarders = null;
		asyncKeepers = null;
		asyncScorers = null;
	}


	/**
		Substitute array of values (this will reset the DecisionHelper scoring state)
	**/
	public function replaceValues(values:Iterable<T>) {
		this.values = values;
		reset();
	}

	/**
		Run all registered asynchronous methods (see `addAsyncScore`, `addAsyncKeep` and `addAsyncDiscard`)
		This approach allows you to prepare a DecisionHelper instance, add scoring/keep/discard methods, and run them later on the set of values.
	**/
	public inline function applyAsyncMethods(?customValues:Iterable<T>, ?customData:T, resetBefore=true) {
		lastBest = null;
		this.customData = customData;
		if( customValues!=null )
			replaceValues(customValues); // includes a reset
		else if( resetBefore )
			reset();

		if( asyncKeepers!=null )
			for(cb in asyncKeepers)
				keepOnly(cb);

		if( asyncDiscarders!=null )
			for(cb in asyncDiscarders)
				discard(cb);

		if( asyncScorers!=null )
			for(cb in asyncScorers)
				score(cb);
	}


	#if deepnightLibsTests
	public static function test() {
		var arr = [ "a", "foo", "bar", "food", "hello", "longworld" ];

		// Filtering
		var dh = new dn.DecisionHelper(arr);
		dh.keepOnly( v->StringTools.contains(v,"o") ); // with letter "o"
		dh.discard( v->StringTools.contains(v,"l") ); // no letter "l"
		dh.score( v -> v.length*0.1 ); // longer is better
		CiAssert.equals( dh.countRemaining(), 2 );
		CiAssert.equals( dh.getBest(), "food" );

		var ok = false;
		dh.useBest( v->ok = (v=="food") );
		CiAssert.isTrue(ok);

		var dh = new dn.DecisionHelper(arr);
		dh.score( v -> v.length*0.1 ); // longer is better
		CiAssert.equals( dh.getBest(), "longworld" );
		dh.discard( v -> StringTools.contains(v,"w") ); // no letter "w"
		CiAssert.equals( dh.getBest(), "hello" );

		dh.keepOnly( v -> StringTools.contains(v,"z") ); // with letter "z"
		CiAssert.equals( dh.isEmpty(), true );

		// FixedArray
		var fa = new dn.struct.FixedArray<String>(5);
		fa.push("foo");
		fa.push("bar");
		fa.push("hello");
		fa.push("longworld");

		var dh = new DecisionHelper(fa);
		dh.keepOnly( v -> StringTools.contains(v,"o") ); // with letter "o"
		dh.score( v -> -v.length ); // shorter is better
		CiAssert.equals(dh.getBest(), "foo");

		// Async methods
		var arr = [ "a", "foo", "bar", "food", "hello", "longworld" ];
		var dh = new DecisionHelper(arr);
		dh.addAsyncKeep( v -> StringTools.contains(v,"o") ); // contains "O"
		dh.addAsyncDiscard( v -> StringTools.contains(v,"l") ); // should not contain any "L"
		dh.addAsyncScore( v -> v.length*0.1 ); // longer is better
		dh.applyAsyncMethods();
		CiAssert.equals( dh.countRemaining(), 2 );
		CiAssert.equals( dh.getBest(), "food" );
	}
	#end
}