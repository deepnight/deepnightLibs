package dn.struct;

/**
	"Fixed-size Array" but with standard-Array comfort. It is optimized to have no memory allocations while supporting common Array operations.

		- FixedArray has a limit to the number of values it can hold, as defined at creation.
		- Allocated values can be iterated over.
		- Supports basic Array operations (get/set, push, pop/shift, etc.)
**/
@:allow(dn.struct.FixedArrayIterator)
class FixedArray<T> {
	var values : haxe.ds.Vector<T>;
	var nalloc : Int;

	/** Custom display name to identify this array **/
	public var name : Null<String>;

	/** Count of allocated values **/
	public var allocated(get,never) : Int;
		inline function get_allocated() return nalloc;

	/** Maximum number of values **/
	public var maxSize(get,never) : Int;
		inline function get_maxSize() return values.length;

	/**
		NOT RECOMMENDED: allow the fixed array to automatically resize itself when its limit is reached.
		Obviously, you will lose all the benefits. However, in some cases,it could useful to "disable" a FixedArray behaviour.
	**/
	@:noCompletion
	public var autoResize = false;

	/**
		If FALSE (default value), then the order of the array won't be guaranted after various operations like `removeIndex` or `shift`. If set to TRUE, then **these operations will be slower**, but the array order will always be preserved.
	**/
	public var preserveOrder = false;


	@:deprecated("Use 'allocated' here (to avoid allocated/maxSize ambiguity)") @:noCompletion
	public var length(get,never) : Int; inline function get_length() return allocated;

	public function new(?name:String, maxSize:Int) {
		this.name = name;
		values = new haxe.ds.Vector(maxSize);
		nalloc = 0;
	}

	/** Fixed Array iterator**/
	public inline function iterator() return new FixedArrayIterator(this);


	@:keep
	public function toString() {
		var a = [];
		for(e in this)
			a.push(e);
		return a.toString() + '<$allocated/$maxSize>';
	}


	/**
		Print FixedArray content as a String.
		**WARNING**: this operation is slow and generates allocations! **Only use for debug purpose.**
	**/
	public inline function shortString() {
		var a = [];
		for(e in this)
			a.push(e);
		return a.join(",");
	}

	/** Create a FixedArray from an existing Array **/
	public static inline function fromArray<T>(arr:Array<T>) : FixedArray<T> {
		var out = new FixedArray(arr.length);
		for(e in arr)
			out.push(e);
		return out;
	}

	/** Return a standard Array using a mapping function on all elements **/
	public function mapToArray<X>(cb:T->X) : Array<X> {
		var out = [];
		for(e in this)
			out.push( cb(e) );
		return out;
	}

	/** Get value at given index, or null if out of bounds **/
	public inline function get(idx:Int) : Null<T> {
		return idx<0 || idx>=nalloc ? null : values[idx];
	}

	public inline function pickRandom(?rndFunc:Int->Int, removeAfterPick=false) : Null<T> {
		if( allocated==0 )
			return null;
		else {
			var idx = (rndFunc==null?Std.random:rndFunc)(allocated);
			if( removeAfterPick ) {
				var e = get(idx);
				removeIndex(idx);
				return e;
			}
			else
				return get(idx);
		}
	}

	/** Set value at given index. This throws an error if the index is above allocated count. **/
	public inline function set(idx:Int, v:T) : T {
		if( idx<0 || idx>=nalloc )
			throw 'Out-of-bounds FixedArray set (idx=$idx, allocated=$allocated)';
		return values[idx] = v;
	}

	/** Get first value (without modifying the array) **/
	public inline function first() : Null<T> {
		return values[0];
	}

	/** Get a random element from the fixed array **/
	public inline function oneRandomly() : Null<T> {
		return allocated==0 ? null : values[ Std.random(allocated) ];
	}

	/** Get last value (without modifying the array) **/
	public inline function last() : Null<T> {
		return values[nalloc-1];
	}

	/** Remove the last value and returns it **/
	public inline function pop() : Null<T> {
		return nalloc==0 ? null : values[(nalloc--)-1];
	}

	/**
		Remove the first value and returns it.
		**Warning**: this will affect the array order if `preserveOrder` is FALSE (default).
	**/
	public inline function shift() : Null<T> {
		if( nalloc==0 )
			return null;
		else {
			var v = values[0];
			removeIndex(0);
			return v;
		}
	}

	/** Clear array content **/
	public inline function empty() {
		nalloc = 0;
	}

	/** Return TRUE if the array contains given value. **/
	public function contains(search:T) {
		for(v in this)
			if( v==search )
				return true;
		return false;
	}

	/** Push a value at the end of the array **/
	public inline function push(e:T) {
		if( nalloc>=values.length ) {
			if( !autoResize )
				throw 'FixedArray limit reached ($maxSize)';
			else {
				// Increase size
				var newValues = new haxe.ds.Vector(values.length*2);
				for(i in 0...values.length)
					newValues[i] = values[i];
				values = newValues;
			}
		}

		values[nalloc] = e;
		nalloc++;
	}

	/** Search and remove given value. Return True if the value was found and removed. **/
	public function remove(e:T) : Bool {
		var found = false;
		for(i in 0...nalloc)
			if( values[i]==e ) {
				removeIndex(i);
				found = true;
				break;
			}

		return found;
	}

	/**
		Remove value at given array index
		**Warning**: this will affect the array order if `preserveOrder` is FALSE (default).
	**/
	public function removeIndex(i:Int) {
		if( i<nalloc ) {
			if( nalloc==1 )
				nalloc = 0;
			else if( !preserveOrder ) {
				// Fast method (no order preservation)
				values[i] = values[nalloc-1];
				values[nalloc-1] = null;
				nalloc--;
			}
			else {
				// Slower method
				for(j in i+1...nalloc)
					values[j-1] = values[j];
				nalloc--;
			}
		}
	}

	/** Destroy the fixed array **/
	public function dispose() {
		values = null;
		nalloc = 0;
	}

	/** Sort elements in place **/
	public function bubbleSort( getSortWeight:T->Float ) {
		var tmp : T = null;
		for(i in 0...allocated-1)
		for(j in i+1...allocated) {
			if( getSortWeight( get(i)) > getSortWeight(get(j) ) ) {
				tmp = get(i);
				set(i, get(j));
				set(j, tmp);
			}
		}
	}

	/** Shuffle the fixed array in place **/
	public function shuffle(?randFunc:Int->Int) {
		if( randFunc==null )
			randFunc = Std.random;
		var m = allocated;
		var i = 0;
		var tmp : T = null;
		while( m>0 ) {
			i = randFunc(m--);
			tmp = values[m];
			values[m] = values[i];
			values[i] = tmp;
		}
	}


	/** Unit tests **/
	@:noCompletion
	public static function __test() {
		var a : FixedArray<Int> = new FixedArray(10);
		CiAssert.equals(a.allocated, 0);
		CiAssert.equals(a.maxSize, 10);

		// Push/pops
		CiAssert.equals({ a.push(16); a.allocated; }, 1);
		CiAssert.equals({ a.push(32); a.allocated; }, 2);
		CiAssert.equals(a.pop(), 32);
		CiAssert.equals(a.allocated, 1);
		CiAssert.equals(a.pop(), 16);
		CiAssert.equals(a.allocated, 0);

		// Shift
		CiAssert.equals({ a.push(16); a.push(32); a.allocated; }, 2);
		CiAssert.equals(a.shift(), 16);
		CiAssert.equals(a.allocated, 1);
		CiAssert.equals(a.shift(), 32);
		CiAssert.equals(a.allocated, 0);

		// Get/set
		CiAssert.equals({ a.push(16); a.push(32); a.allocated; }, 2);
		CiAssert.equals(a.get(0), 16);
		CiAssert.equals(a.get(1), 32);
		CiAssert.equals(a.get(2), null);
		CiAssert.equals({ a.push(64); a.get(2); }, 64);
		CiAssert.equals({ a.pop(); a.get(2); }, null);

		// First/last
		a.push(64);
		CiAssert.equals(a.first(), 16);
		CiAssert.equals(a.last(), 64);

		// Removals
		CiAssert.equals(a.remove(32), true);
		CiAssert.equals(a.remove(99), false);
		CiAssert.equals(a.allocated, 2);
		CiAssert.equals({ a.removeIndex(10); a.allocated; }, 2);
		CiAssert.equals({ a.removeIndex(0); a.allocated; }, 1);
		CiAssert.equals(a.get(0), 64);

		// Resizable fixed arrays
		var dyn = new FixedArray(2);
		dyn.autoResize = true;
		CiAssert.equals(dyn.maxSize, 2);
		CiAssert.equals(dyn.allocated, 0);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 1);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 2);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 3);
		CiAssert.equals(dyn.maxSize, 4);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 4);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 5);
		CiAssert.equals(dyn.maxSize, 8);

		// Sorting
		var a = new FixedArray(4);
		a.push(30);
		a.push(10);
		a.push(40);
		a.push(20);
		a.bubbleSort( v->v );
		CiAssert.equals(a.get(0), 10);
		CiAssert.equals(a.get(1), 20);
		CiAssert.equals(a.get(2), 30);
		CiAssert.equals(a.get(3), 40);

		// From array init
		var a = FixedArray.fromArray([0,1,2]);
		CiAssert.equals(a.allocated, 3);
		CiAssert.equals(a.first(), 0);
		CiAssert.equals(a.get(1), 1);
		CiAssert.equals(a.last(), 2);

		// Without array order preservation (default)
		var a = new FixedArray(5);
		a.push("a");
		a.push("b");
		a.push("c");
		a.push("d");
		a.push("e");
		CiAssert.equals(a.shortString(), "a,b,c,d,e");
		a.shift(); CiAssert.equals(a.shortString(), "e,b,c,d");
		a.removeIndex(1); CiAssert.equals(a.shortString(), "e,d,c");
		a.remove("e"); CiAssert.equals(a.shortString(), "c,d");

		// With array order preservation
		var a = new FixedArray(5);
		a.preserveOrder = true;
		a.push("a");
		a.push("b");
		a.push("c");
		a.push("d");
		a.push("e");
		CiAssert.equals(a.shortString(), "a,b,c,d,e");
		a.shift(); CiAssert.equals(a.shortString(), "b,c,d,e");
		a.removeIndex(1); CiAssert.equals(a.shortString(), "b,d,e");
		a.remove("b"); CiAssert.equals(a.shortString(), "d,e");
	}
}



/**
	Custom iterator for FixedArrays
**/
private class FixedArrayIterator<T> {
	var arr : FixedArray<T>;
	var i : Int;


	public inline function new(arr:FixedArray<T>) {
		this.arr = arr;
		i = 0;
	}

	public inline function hasNext() {
		return i<arr.nalloc;
	}

	public inline function next() {
		return arr.values[i++];
	}
}