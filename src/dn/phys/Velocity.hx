package dn.phys;

/**
	A generic X/Y velocity utility class
**/
class Velocity {
	/** Custom identifier **/
	public var id = -1;

	public var x : Float;
	public var y : Float;
	public var frictX : Float;
	public var frictY : Float;

	/** `v` is a convenience alias for `x` when you just need a 1D velocity **/
	public var v(get,set) : Float;
		inline function get_v() return x;
		inline function set_v(v:Float) return setBoth(v);

	/** `x` alias **/
	public var dx(get,set) : Float;
		inline function set_dx(v) return x = v;
		inline function get_dx() return x;

	/** `y` alias **/
	public var dy(get,set) : Float;
		inline function set_dy(v) return y = v;
		inline function get_dy() return y;

	/** If absolute `x` or `y` goes below this value, instead, it is set to zero during next update. **/
	public var clearThreshold = 0.0005;

	public var frict(never,set) : Float;
		inline function set_frict(v) return frictX = frictY = v;

	/** Angle in radians of the vector represented by x/y **/
	public var ang(get,never) : Float; inline function get_ang() return Math.atan2(y,x);
	/** Length of the vector represented by x/y **/
	public var len(get,never) : Float; inline function get_len() return Math.sqrt(x*x + y*y);

	public var dirX(get,never) : Int; inline function get_dirX() return M.sign(x);
	public var dirY(get,never) : Int; inline function get_dirY() return M.sign(y);


	public inline function new() {
		x = y = 0;
		frict = 1;
	}

	public static inline function createInit(x:Float, y:Float, frict=1.) {
		var v = new Velocity();
		v.set(x,y);
		v.frict = frict;
		return v;
	}

	public static inline function createFrict(frict:Float) {
		var v = new Velocity();
		v.frict = frict;
		return v;
	}

	@:keep
	public function toString() {
		return 'Velocity${ id<0?"":"#"+id }(${ shortString() })';
	}

	public inline function shortString() {
		return '${ M.pretty(x,2) },${ M.pretty(y,2) }';
	}

	public inline function setFricts(fx:Float, fy:Float) {
		frictX = fx;
		frictY = fy;
	}

	public inline function mulXY(fx:Float, fy:Float) {
		x*=fx;
		y*=fy;
	}

	@:deprecated("Use mul(f)") @:noCompletion public inline function mulBoth(f:Float) mul(f);
	public inline function mul(f:Float) {
		x*=f;
		y*=f;
	}

	public inline function clear() {
		x = y = 0;
	}

	public inline function addXY(vx:Float, vy:Float) {
		x += vx;
		y += vy;
	}

	@:deprecated("This method is no longer implemented.") @:noCompletion public inline function addBoth(v:Float) {}

	public inline function addLen(v:Float) {
		var l = len;
		var a = ang;
		x = Math.cos(a)*(l+v);
		y = Math.sin(a)*(l+v);
	}

	public inline function set(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}

	public inline function setBoth(v:Float) {
		return x = y = v;
	}

	public inline function addAng(ang:Float, v:Float) {
		x += Math.cos(ang)*v;
		y += Math.sin(ang)*v;
	}

	public inline function setAng(ang:Float, v:Float) {
		x = Math.cos(ang)*v;
		y = Math.sin(ang)*v;
	}

	public inline function rotate(angInc:Float) {
		var oldAng = ang;
		var d = len;
		dx = Math.cos(oldAng+angInc) * d;
		dy = Math.sin(oldAng+angInc) * d;
	}


	public inline function isZero() return M.fabs(x)<=clearThreshold  &&  M.fabs(y)<=clearThreshold;

	public inline function fixedUpdate(frictOverride=-1.) {
		if( frictOverride>=0 ) {
			x *= frictOverride;
			y *= frictOverride;
		}
		else {
			x*=frictX;
			y*=frictY;
		}

		if( M.fabs(x)<clearThreshold )
			x = 0;

		if( M.fabs(y)<clearThreshold )
			y = 0;
	}


	@:noCompletion
	public static function __test() {
		// Init
		var v = new Velocity();
		CiAssert.equals( v.x, 0 );
		CiAssert.equals( v.y, 0 );
		CiAssert.equals( v.isZero(), true );
		CiAssert.equals( v.shortString(), "0,0" );

		v.set(8,2);
		CiAssert.equals( v.x, 8 );
		CiAssert.equals( v.y, 2 );
		CiAssert.equals( v.shortString(), "8,2" );
		CiAssert.equals( v.isZero(), false );

		// Frictions
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "8,2" );

		v.setFricts(0.5, 0.5);
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "4,1" );
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "2,0.5" );

		// Threshold
		v.clearThreshold = 1;
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "1,0" );

		// Different frictions
		var v = new Velocity();
		v.set(8,2);
		v.setFricts(0.25, 0.5);
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "2,1" );
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "0.5,0.5" );


		// Multiply
		v.set(8,2);
		v.mul(2);
		CiAssert.equals( v.shortString(), "16,4" );

		v.mulXY(2,3);
		CiAssert.equals( v.shortString(), "32,12" );

		v.mul(0);
		CiAssert.equals( v.shortString(), "0,0" );
		CiAssert.equals( v.isZero(), true );

		// Addition
		v.set(1,1);
		v.addXY(1,1);
		CiAssert.equals( v.shortString(), "2,2" );

		v.addXY(1,2);
		CiAssert.equals( v.shortString(), "3,4" );

		// Single value velocity
		var v = new Velocity();
		v.frict = 0.5;
		v.v = 4;
		CiAssert.equals( v.v, 4 );
		v.fixedUpdate();
		CiAssert.equals( v.v, 2 );
		v.fixedUpdate();
		CiAssert.equals( v.v, 1 );
	}
}



/**
	Array of Velocity instances, with extra helper methods.
**/
class VelocityArray {
	var all : dn.struct.FixedArray<Velocity>;
	var _sum = 0.;

	public inline function new(maxLength:Int) {
		all = new dn.struct.FixedArray(maxLength);
	}

	@:keep public function toString() {
		return all.toString();
	}

	public inline function push(v:Velocity) {
		all.push(v);
	}

	public inline function remove(v:Velocity) : Bool {
		return all.remove(v);
	}

	public inline function empty() {
		all.empty();
	}

	public function dispose() {
		all.dispose();
		all = null;
	}

	public inline function getSumX() {
		_sum = 0.;
		for(v in all)
			_sum+=v.x;
		return _sum;
	}

	public inline function getSumY() {
		_sum = 0.;
		for(v in all)
			_sum+=v.y;
		return _sum;
	}

	public inline function mulAll(f:Float) {
		for(v in all)
			v.mul(f);
	}

	public inline function mulAllX(f:Float) {
		for(v in all)
			v.mulXY(f,1);
	}

	public inline function mulAllY(f:Float) {
		for(v in all)
			v.mulXY(1,f);
	}

	public inline function clearAll() {
		for(v in all)
			v.clear();
	}

	/** Remove "zero" velocities from array **/
	public function removeZeros() {
		var i = 0;
		while( i<all.allocated ) {
			if( all.get(i).isZero() )
				all.removeIndex(i);
			else
				i++;
		}
	}

	public inline function iterator() {
		return all.iterator();
	}
}
