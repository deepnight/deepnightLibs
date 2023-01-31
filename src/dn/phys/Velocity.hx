package dn.phys;

/**
	A generic X/Y velocity utility class
**/
class Velocity {
	public var dx : Float;
	public var dy : Float;
	public var frictX : Float;
	public var frictY : Float;

	/** If absolute dx or dy goes below this value, instead, it is set to zero during next update. **/
	public var clearThreshold = 0.0005;

	public var frict(never,set) : Float;
		inline function set_frict(v) return frictX = frictY = v;

	/** Angle in radians of the vector represented by dx/dy **/
	public var ang(get,never) : Float; inline function get_ang() return Math.atan2(dy,dx);
	/** Length of the vector represented by dx/dy **/
	public var len(get,never) : Float; inline function get_len() return Math.sqrt(dx*dx + dy*dy);

	public var dirX(get,never) : Int; inline function get_dirX() return M.sign(dx);
	public var dirY(get,never) : Int; inline function get_dirY() return M.sign(dy);


	public inline function new(frict=0.9) {
		dx = dy = 0;
		this.frict = frict;
	}

	@:keep
	public function toString() {
		return 'Velocity(${ shortString() })';
	}

	public inline function shortString() {
		return '${ M.pretty(dx,2) },${ M.pretty(dy,2) }';
	}

	public inline function setFricts(x:Float, y:Float) {
		frictX = x;
		frictY = y;
	}

	public inline function mul(fx:Float, fy:Float) {
		dx*=fx;
		dy*=fy;
	}

	public inline function mulBoth(f:Float) {
		dx*=f;
		dy*=f;
	}

	public inline function clear() {
		dx = dy = 0;
	}

	public inline function add(vx:Float, vy:Float) {
		dx += vx;
		dy += vy;
	}

	public inline function addBoth(v:Float) {
		dx += v;
		dy += v;
	}

	public inline function set(x:Float, y:Float) {
		dx = x;
		dy = y;
	}

	public inline function addAng(ang:Float, v:Float) {
		dx += Math.cos(ang)*v;
		dy += Math.sin(ang)*v;
	}

	public inline function setAng(ang:Float, v:Float) {
		dx = Math.cos(ang)*v;
		dy = Math.sin(ang)*v;
	}


	public inline function isZero() return M.fabs(dx)<=clearThreshold  &&  M.fabs(dy)<=clearThreshold;

	public inline function fixedUpdate() {
		dx*=frictX;
		dy*=frictY;

		if( M.fabs(dx)<clearThreshold )
			dx = 0;

		if( M.fabs(dy)<clearThreshold )
			dy = 0;
	}


	@:noCompletion
	public static function __test() {
		var v = new Velocity(1);
		CiAssert.equals( v.dx, 0 );
		CiAssert.equals( v.dy, 0 );
		CiAssert.equals( v.isZero(), true );
		CiAssert.equals( v.shortString(), "0,0" );

		v.set(8,2);
		CiAssert.equals( v.dx, 8 );
		CiAssert.equals( v.dy, 2 );
		CiAssert.equals( v.shortString(), "8,2" );
		CiAssert.equals( v.isZero(), false );


		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "8,2" );

		v.setFricts(0.5, 0.5);
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "4,1" );
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "2,0.5" );

		v.clearThreshold = 1;
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "1,0" );

		v.set(8,2);
		CiAssert.equals( v.shortString(), "8,2" );

		v.mulBoth(2);
		CiAssert.equals( v.shortString(), "16,4" );

		v.mul(2,3);
		CiAssert.equals( v.shortString(), "32,12" );

		v.addBoth(1);
		CiAssert.equals( v.shortString(), "33,13" );

		v.add(1,2);
		CiAssert.equals( v.shortString(), "34,15" );

		v.mulBoth(0);
		CiAssert.equals( v.shortString(), "0,0" );
		CiAssert.equals( v.isZero(), true );
	}
}
