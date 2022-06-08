package dn;

/**
	"Fixed-size Array" but with standard-Array comfort. It is optimized to have no memory allocations while supporting common Array operations.

		- FixedArray has a limit to the number of values it can hold, as defined at creation.
		- Allocated values can be iterated over.
		- Supports basic Array operations (push, pop, shift, get etc.)
**/
@:allow(dn.FixedArrayIterator)
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

	/** Get value at given index **/
	@:arrayAccess
	public inline function get(idx:Int) : Null<T> {
		return idx<0 || idx>=nalloc ? null : values[idx];
	}

	/** Set value at given index. This throws an error if the index is above allocated count. **/
	@:arrayAccess
	public inline function set(idx:Int, v:T) : T {
		if( idx<0 || idx>=nalloc )
			throw 'Out-of-bounds FixedArray set (idx=$idx, allocated=$allocated)';
		return values[idx] = v;
	}

	/** Get first value (without modifying the array) **/
	public inline function first() : Null<T> {
		return values[0];
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
			throw "FixedArray overflow";

		values[nalloc] = e;
		nalloc++;
	}

	/** Search and remove given value **/
	public inline function remove(e:T) {
		for(i in 0...nalloc)
			if( values[i]==e ) {
				removeIndex(i);
				break;
			}
	}

	/** Remove value at given array index **/
	public inline function removeIndex(i:Int) {
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

	/** Destroy fixed array **/
	public function dispose() {
		values = null;
		nalloc = 0;
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