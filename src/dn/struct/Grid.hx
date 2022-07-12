package dn.struct;

@:allow(dn.struct.GridIterator)
class Grid<T> {
	public var wid(default,null) : Int;
	public var hei(default,null) : Int;

	var data : Map<Int,T>;

	public function new(w,h) {
		wid = w;
		hei = h;
		data = new Map();
	}

	public inline function iterator() return new GridIterator(this);

	public function dispose(?elementDisposer:T->Void) {
		if( elementDisposer!=null )
			for(e in this)
				elementDisposer(e);
		data = null;
	}

	public inline function isValid(x:Int, y:Int) {
		return x>=0 && x<wid && y>=0 && y<hei;
	}

	public inline function coordId(x:Int, y:Int) {
		return x + y*wid;
	}

	public inline function set(x:Int, y:Int, v:T) {
		if( isValid(x,y) )
			data.set( coordId(x,y), v );
	}

	public inline function get(x:Int, y:Int) : Null<T> {
		return isValid(x,y) ? data.get( coordId(x,y) ) : null;
	}

	public inline function hasValue(x:Int, y:Int) : Bool {
		return isValid(x,y) && data.get( coordId(x,y) )!=null;
	}

	public inline function remove(x:Int, y:Int) {
		if( isValid(x,y) )
			data.remove( coordId(x,y) );
	}

	public inline function fill(v:T) {
		for(x in 0...wid)
		for(y in 0...hei)
			data.set( coordId(x,y), v );
	}

	public inline function empty() {
		data = new Map();
	}
}



/**
	Custom iterator for Grid
**/
private class GridIterator<T> {
	var grid : Grid<T>;
	var i : Int;


	public inline function new(grid:Grid<T>) {
		this.grid = grid;
		i = 0;
	}

	public inline function hasNext() {
		return i < grid.wid * grid.hei;
	}

	public inline function next() {
		return grid.data.get(i++);
	}
}