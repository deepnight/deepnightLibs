package dn.struct;

/**
	"Fixed-size Array" but with most of the standard-Array comfort. It is optimized to have no memory allocations while supporting common Array operations.

		- FixedArray has a limit to the number of values it can hold, which is defined at construction.
		- WARNING: VALUES ORDER IS NOT PRESERVED, unless you set its `preserveOrder` flag to TRUE (costs some extra execution time, see documentation)
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

	var autoExpand = false;
	var autoExpandAdd = 0;

	@:noCompletion @:deprecated("Use enableAutoExpand()")
	public var autoResize(never,default) : Bool;

	/**
		If FALSE (default value), then the order of the array won't be guaranted after operations that affect values other the last one (eg. `removeIndex` and `shift`). If set to TRUE, then **these operations will be slower**, but the array order will always be preserved.
	**/
	public var preserveOrder = false;

	@:deprecated("Use 'allocated' here (to avoid allocated/maxSize ambiguity)") @:noCompletion
	public var length(get,never) : Int;
		inline function get_length() return allocated;



	public function new(?name:String, maxSize:Int) {
		this.name = name;
		values = new haxe.ds.Vector(maxSize);
		nalloc = 0;
	}

	/** Fixed Array iterator**/
	public inline function iterator() return new FixedArrayIterator<T>(this);


	@:keep
	public function toString() {
		var a = [];
		for(v in this)
			a.push(v);
		return a.map( v->toStringValue(v) ).toString() + '<$allocated/$maxSize>';
	}


	/**
		Print FixedArray content as a String (example: "valueA,valueB,valueC").
		**WARNING**: this operation is slow and generates allocations! **Only use for debug purpose.**
	**/
	public function shortString() {
		var a = [];
		for(v in this)
			a.push(v);
		return a.map( v->toStringValue(v) ).join(",");
	}

	/** Create a String representation (this method can be replaced) **/
	public dynamic function toStringValue(v:T) : String {
		return Std.string(v);
	}

	/** Re-initialize this FixedArray using the content of given Array **/
	function loadArray(arr:Array<T>) {
		values = new haxe.ds.Vector(arr.length);
		nalloc = 0;
		for(e in arr)
			push(e);
	}


	/** Create a FixedArray using the content of an Array **/
	public static function fromArray<T>(arr:Array<T>) : FixedArray<T> {
		var fa = new FixedArray(arr.length);
		fa.loadArray(arr);
		return fa;
	}


	/** Return a standard Array using a mapping function on all elements **/
	public function mapToArray<X>(mapValue:T->X) : Array<X> {
		var out = [];
		for(v in this)
			out.push( mapValue(v) );
		return out;
	}


	/**
		NOT RECOMMENDED: allow the fixed array to automatically expand its length when its limit is reached.
		Obviously, you will lose most fixed length benefits, if such resizing happens. However, in some cases,it could useful to "disable" a FixedArray behaviour.
	**/
	public function enableAutoExpand(sizeIncrease:Int) {
		autoExpand = true;
		autoExpandAdd = sizeIncrease;
	}

	/** Check if there's a value at given index **/
	public inline function exists(idx:Int) {
		return idx>=0 && idx<nalloc;
	}

	/** Get value at given index, or null if out of bounds **/
	public inline function get(idx:Int) : Null<T> {
		return exists(idx) ? values[idx] : null;
	}

	public function pickRandom(?rndFunc:Int->Int, removeAfterPick=false) : Null<T> {
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
		return allocated>0 ? values[ Std.random(allocated) ] : null;
	}

	/** Get last value (without modifying the array) **/
	public inline function last() : Null<T> {
		return values[nalloc-1];
	}

	/** Remove the last value and returns it **/
	public inline function pop() : Null<T> {
		return nalloc>0 ? values[(nalloc--)-1] : null;
	}

	/**
		Remove the first value and returns it.
		**Warning**: this will affect the array order if `preserveOrder` is FALSE (default).
	**/
	public function shift() : Null<T> {
		if( nalloc==0 )
			return null;
		else {
			var v = values[0];
			removeIndex(0);
			return v;
		}
	}

	/** Clear array content **/
	public function empty() {
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
	public function push(e:T) {
		if( nalloc>=values.length ) {
			if( !autoExpand )
				throw 'FixedArray limit reached ($maxSize)';
			else {
				// Increase size
				var newValues = new haxe.ds.Vector<T>(values.length + autoExpandAdd);
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
				// values[nalloc-1] = null;
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
		var tmp : T;
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
		var tmp : T;
		while( m>0 ) {
			i = randFunc(m--);
			tmp = values[m];
			values[m] = values[i];
			values[i] = tmp;
		}
	}

}



/** Unit tests **/
@:noCompletion
class FixedArrayTests {
	public static function __test() {
		var a = new FixedArray<Int>(10);
		CiAssert.equals(a.allocated, 0);
		CiAssert.equals(a.maxSize, 10);

		// Filling/emptying
		for(i in 0...a.maxSize) a.push(i);
		CiAssert.equals(a.allocated, 10);
		a.empty();
		CiAssert.equals(a.allocated, 0);
		for(i in 0...a.maxSize) a.push(i);
		CiAssert.equals(a.allocated, 10);
		a.empty();
		CiAssert.equals(a.allocated, 0);

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
		CiAssert.equals(a.exists(0), true);
		CiAssert.equals(a.exists(1), true);
		CiAssert.equals(a.exists(2), false);
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
		var dyn = new FixedArray<Bool>(2);
		dyn.enableAutoExpand(2);
		CiAssert.equals(dyn.maxSize, 2);
		CiAssert.equals(dyn.allocated, 0);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 1);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 2);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 3); // expand happens
		CiAssert.equals(dyn.maxSize, 4);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 4);

		dyn.push(true);
		CiAssert.equals(dyn.allocated, 5); // expand happens
		CiAssert.equals(dyn.maxSize, 6);

		// Sorting
		var a = new FixedArray<Int>(4);
		a.push(30);
		a.push(10);
		a.push(40);
		a.push(20);
		a.bubbleSort( v->v );
		CiAssert.equals(a.get(0), 10);
		CiAssert.equals(a.get(1), 20);
		CiAssert.equals(a.get(2), 30);
		CiAssert.equals(a.get(3), 40);

		// Init from an Array
		var a = FixedArray.fromArray([0,1,2]);
		CiAssert.equals(a.allocated, 3);
		CiAssert.equals(a.get(0), 0);
		CiAssert.equals(a.get(1), 1);
		CiAssert.equals(a.get(2), 2);

		// Without array order preservation (default)
		var a = new FixedArray<String>(5);
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
		var a = new FixedArray<String>(5);
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