package dn.struct;

private typedef Recyclable = {
	function recycle() : Void;
}

/**
	Recyclable pool of objects.
		- A pool has a limited number of slots,
		- Each pool object is initialized before-hand at pool creation,
		- "Allocating" an object from the pool actually restore an existing unused one and calls its `object.recycle()` method,
		- Objects should be freed by calling `pool.freeElement(obj)` or `pool.freeIndex(idx)`.
**/
@:allow(dn.struct.RecyclablePoolIterator)
class RecyclablePool<T:Recyclable> {
	/** Currently allocated count **/
	public var allocated(get,never) : Int;
		inline function get_allocated() return nalloc;

	/** Max pool size **/
	public var maxSize(get,never) : Int;
		inline function get_maxSize() return size;

	var nalloc = 0;
	var size : Int;
	var pool : haxe.ds.Vector<T>;

	/**
		Create a RecyclablePool.
	**/
	public inline function new(size:Int, valueConstructor:Void->T) {
		this.size = size;
		pool = new haxe.ds.Vector(size);
		for(i in 0...pool.length)
			pool[i] = valueConstructor();
	}

	@:keep
	public function toString() {
		return 'RecyclablePool($allocated/$maxSize)';
	}

	/**
		Return the expected object at given index.
		"Expected" means that this method will return `null` if the index is out of the *currently allocated* bounds.
	**/
	public inline function get(index:Int) : Null<T> {
		return index<0 || index>=nalloc ? null : pool[index];
	}

	/**
		Return the object at given index, without checking the currently allocated bounds.
	**/
	public inline function getUnsafe(index:Int) : Null<T> {
		return pool[index];
	}

	/**
		Destroy the pool.

		**WARNING**: to dispose the pool objects, you need to provide a custom dispose method that will be executed on all pool objects (including unused ones).
	**/
	public function dispose(?elementDisposer:T->Void) {
		if( elementDisposer!=null )
			for(e in pool)
				elementDisposer(e);
		nalloc = 0;
		pool = null;
	}

	/**
		Pick and return an available element from the pool.

		Its `recycle()` method is automatically called.
	**/
	public inline function alloc() : T {
		if( nalloc>=size )
			throw 'RecyclablePool limit reached ($maxSize)';
		var e = pool[nalloc++];
		e.recycle();
		return e;
	}

	/** Free all pool **/
	public inline function freeAll() {
		nalloc = 0;
	}

	/** Free value at given array index **/
	public inline function freeIndex(i:Int) {
		if( i>=0 && i<nalloc ) {
			if( nalloc>1 ) {
				var tmp = pool[i];
				pool[i] = pool[nalloc-1];
				pool[nalloc-1] = tmp;
				nalloc--;
			}
			else
				nalloc = 0;
		}
	}

	/** Search a specific value and free it **/
	public inline function freeElement(search:T) {
		for(i in 0...nalloc)
			if( pool[i]==search ) {
				freeIndex(i);
				break;
			}
	}


	public inline function iterator() return new RecyclablePoolIterator(this);



	/** Unit tests **/
	@:noCompletion
	public static function __test() {
		// Init
		var i = 0;
		var p : RecyclablePool<TestObject> = new RecyclablePool(3, ()->new TestObject(i++));
		CiAssert.equals( p.allocated, 0 );
		CiAssert.equals( p.maxSize, 3 );
		CiAssert.equals( p.get(0), null );
		CiAssert.isTrue( p.getUnsafe(0) != null );
		CiAssert.isTrue( p.getUnsafe(1) != null );
		CiAssert.isTrue( p.getUnsafe(2) != null );
		CiAssert.isTrue( p.getUnsafe(3) == null );

		// Alloc
		var e = p.alloc();
		CiAssert.equals( p.allocated, 1 );
		CiAssert.equals( p.get(0), e );
		CiAssert.equals( { p.alloc(); p.allocated; }, 2 );
		CiAssert.equals( { p.alloc(); p.allocated; }, 3 );
		CiAssert.equals( { p.freeAll(); p.allocated; }, 0 );

		// Free
		CiAssert.equals( { e = p.alloc(); p.allocated; }, 1 );
		CiAssert.equals( { p.freeElement(e); p.allocated; }, 0 );
		CiAssert.equals( p.get(0), null );
		CiAssert.equals( { p.alloc(); p.allocated; }, 1 );
		CiAssert.equals( { p.freeIndex(1); p.allocated; }, 1 );
		CiAssert.equals( { p.freeIndex(0); p.allocated; }, 0 );

		// Check pointers
		var i = 0;
		var p = new RecyclablePool(10, ()->new TestObject(i++));
		for(i in 0...1000) {
			if( p.allocated<p.maxSize )
				p.alloc();
			if( Std.random(2)==0 )
				p.freeIndex(0);
		}
		for(i in 0...p.maxSize)
		for(j in i+1...p.maxSize)
			CiAssert.isTrue( p.getUnsafe(i)!=p.getUnsafe(j) );
	}
}

private class TestObject {
	var id : Int;
	public var value : Int;

	public function new(id) {
		this.id = id;
	}

	@:keep
	public function toString() return '#$id=${Std.string(value)}';
	public function recycle() {
		value = Std.random(999999);
	}
}


/**
	Custom iterator for FixedArrays
**/
private class RecyclablePoolIterator<T:Recyclable> {
	var rpool : RecyclablePool<T>;
	var i : Int;


	public inline function new(r:RecyclablePool<T>) {
		this.rpool = r;
		i = 0;
	}

	public inline function hasNext() {
		return i<rpool.nalloc;
	}

	public inline function next() {
		return rpool.pool[i++];
	}
}