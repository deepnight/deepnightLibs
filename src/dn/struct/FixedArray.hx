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
		return (name==null?"FixedArray":name) + ' $allocated / $maxSize';
	}

	/** Print FixedArray content as a String. WARNING: this operation is slow & generates lots of allocations! Only use for debug purpose. **/
	@:keep
	public function dumpContent() : String {
		var sub = [];
		for(i in 0...nalloc)
			sub[i] = values[i];
		return '[ ${sub.join(", ")} ]';
	}

	/** Get value at given index, or null if out of bounds **/
	public inline function get(idx:Int) : Null<T> {
		return idx<0 || idx>=nalloc ? null : values[idx];
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

	/** Get first value (without modifying the array) **/
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

	/** Remove the first value and returns it **/
	public inline function shift() : Null<T> {
		if( nalloc==0 )
			return null;
		else {
			var v = values[0];
			for(i in 1...nalloc)
				values[i-1] = values[i];
			nalloc--;
			return v;
		}
	}

	/** Clear array content **/
	public inline function empty() {
		nalloc = 0;
	}

	/** Push a value at the end of the array **/
	public inline function push(e:T) {
		if( nalloc>=values.length )
			throw 'FixedArray limit reached ($maxSize)';

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

	/** Remove value at given array index **/
	public function removeIndex(i:Int) {
		if( i<nalloc ) {
			values[i] = null;
			if( nalloc>1 ) {
				values[i] = values[nalloc-1];
				values[nalloc-1] = null;
				nalloc--;
			}
			else
				nalloc = 0;
		}
	}

	/** Destroy the fixed array **/
	public function dispose() {
		values = null;
		nalloc = 0;
	}

	public function bubbleSort(weight:T->Float) {
		var tmp : T = null;
		for(i in 0...allocated-1)
		for(j in i+1...allocated) {
			if( weight(get(i)) > weight(get(j)) ) {
				tmp = get(i);
				set(i, get(j));
				set(j, tmp);
			}
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