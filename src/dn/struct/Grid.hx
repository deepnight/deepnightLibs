package dn.struct;

/**
	A 2D Grid structure. It cannot be resized after creation.
**/
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

	@:keep
	public inline function toString() {
		return 'Grid(${wid}x$hei)';
	}

	/** Return a text representation of the grid, for debug purpose. **/
	public function debug() {
		var lines = [];
		for(cy in 0...hei) {
			var l = "";
			for(cx in 0...wid) {
				if( !hasValue(cx,cy) )
					l+=".. ";
				else {
					l += Std.string( get(cx,cy) );
					while( l.length<3 ) l+=" ";
				}
			}
			lines.push(l);
		}

		return lines.join("\n");
	}

	public inline function iterator() return new GridIterator(this);

	public function dispose(?elementDisposer:T->Void) {
		if( elementDisposer!=null )
			for(e in this)
				elementDisposer(e);
		data = null;
	}

	/** Return TRUE if given coordinate is in grid bounds **/
	public inline function isValid(x:Int, y:Int) {
		return x>=0 && x<wid && y>=0 && y<hei;
	}

	inline function coordId(x:Int, y:Int) {
		return x + y*wid;
	}

	/** Set a grid cell, if coordinates are in bounds. **/
	public inline function set(x:Int, y:Int, v:T) {
		if( isValid(x,y) )
			data.set( coordId(x,y), v );
	}

	/** Return a grid cell value. **/
	public inline function get(x:Int, y:Int) : Null<T> {
		return isValid(x,y) ? data.get( coordId(x,y) ) : null;
	}

	/** Return TRUE if given grid cell contains a non-null value. **/
	public inline function hasValue(x:Int, y:Int) : Bool {
		return isValid(x,y) && data.get( coordId(x,y) )!=null;
	}

	/** Remove the value of a grid cell. **/
	public inline function remove(x:Int, y:Int) {
		if( isValid(x,y) )
			data.remove( coordId(x,y) );
	}

	/** Fill all the grid with given value. **/
	public inline function fill(v:T) {
		for(x in 0...wid)
		for(y in 0...hei)
			data.set( coordId(x,y), v );
	}

	/** Remove all grid values. **/
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