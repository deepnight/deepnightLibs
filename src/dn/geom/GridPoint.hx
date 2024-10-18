package dn.geom;

class GridPoint {
	public var x : Int;
	public var y : Int;

	/** cx alias **/
	public var cx(get,set) : Int;
		inline function get_cx() return x;
		inline function set_cx(v:Int) return x = v;

	/** cy alias **/
	public var cy(get,set) : Int;
		inline function get_cy() return y;
		inline function set_cy(v:Int) return y = v;


	public inline function new(x,y) {
		this.x = x;
		this.y = y;
	}

	@:keep public function toString() return '<$x,$y>';
}