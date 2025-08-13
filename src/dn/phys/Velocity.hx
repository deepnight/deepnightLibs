package dn.phys;

/**
	A generic X/Y velocity utility class
**/
@:allow(dn.phys.VelocityArray)
class Velocity {
	/** Custom identifier **/
	public var id = -1;

	public var x(get,never) : Float;
	public var y(get,never) : Float;
	public var frictX : Float;
	public var frictY : Float;

	/** Real internal X value, with preMul applied **/
	var _preMultX : Float;

	/** Real internal Y value, with preMul applied **/
	var _preMultY : Float;

	/** This factor is pre-multiplied to any value added to the X/Y velocity values **/
	public var preMul : Float = 1.;

	/** Convenience alias for `x` **/
	public var dx(get,never) : Float;
		inline function get_dx() return _preMultX;

	/** Convenience alias for `y` **/
	public var dy(get,never) : Float;
		inline function get_dy() return _preMultY;

	/** If any absolute values of `x` or `y` goes below this value, instead, it is set to zero during next update. **/
	public var clearThreshold = 0.0005;

	public var frict(never,set) : Float;
		inline function set_frict(v) return frictX = frictY = v;

	/** Angle in radians of the vector represented by x/y **/
	public var ang(get,never) : Float; inline function get_ang() return Math.atan2(_preMultY,_preMultX);

	/** Length of the vector represented by x/y **/
	public var len(get,never) : Float; inline function get_len() return Math.sqrt(_preMultX*_preMultX + _preMultY*_preMultY);

	/** Sign of X (-1 or 1) **/
	public var dirX(get,never) : Int; inline function get_dirX() return M.sign(_preMultX);

	/** Sign of Y (-1 or 1) **/
	public var dirY(get,never) : Int; inline function get_dirY() return M.sign(_preMultY);


	public inline function new() {
		_preMultX = _preMultY = 0;
		frict = 1;
	}

	inline function get_x() return _preMultX;
	public inline function setX(v:Float) _preMultX = v * preMul;
	public inline function addX(v:Float) _preMultX += v * preMul;
	public inline function mulX(v:Float) _preMultX *= v;
	public inline function setSignX(sign:Int) {
		if( sign!=0 )
			_preMultX = M.fabs(_preMultX) * (sign>0?1:-1);
	}

	inline function get_y() return _preMultY;
	public inline function setY(v:Float) _preMultY = v * preMul;
	public inline function addY(v:Float) _preMultY += v * preMul;
	public inline function mulY(v:Float) _preMultY *= v;
	public inline function setSignY(sign:Int) {
		if( sign!=0 )
			_preMultY = M.fabs(_preMultY) * (sign>0?1:-1);
	}

	/** Create a Velocity instance with X and Y values **/
	public static inline function createXY(vx:Float, vy:Float, frict=1.) {
		var v = new Velocity();
		v.setXY(vx,vy);
		v.frict = frict;
		return v;
	}
	@:deprecated("Use createXY(f)") @:noCompletion public inline function createInit(vx,vy,?f) createXY(vx,vy,f);

	/** Create a Velocity instance with an angle and a length **/
	public static inline function createAng(ang:Float, len:Float, frict=1.) {
		var v = new Velocity();
		v.setAng(ang,len);
		v.frict = frict;
		return v;
	}

	/** Create a Velocity instance with just an initial friction **/
	public static inline function createFrict(frict:Float) {
		var v = new Velocity();
		v.frict = frict;
		return v;
	}

	@:keep public function toString() {
		return 'Velocity${ id<0?"":"#"+id }(${ shortString() })';
	}

	public inline function shortString() {
		return '${ M.pretty(_preMultX,2) },${ M.pretty(_preMultY,2) }';
	}

	/** Set individual frictions **/
	public inline function setFricts(fx:Float, fy:Float) {
		frictX = fx;
		frictY = fy;
	}

	/* Multiply X/Y values by individual factors */
	public inline function mulXY(fx:Float, fy:Float) {
		mulX(fx);
		mulY(fy);
	}

	/** Multiply both X/Y values by a factor **/
	public inline function mul(f:Float) {
		mulX(f);
		mulY(f);
	}
	@:deprecated("Use mul(f)") @:noCompletion public inline function mulBoth(f:Float) mul(f);

	public inline function clear() {
		_preMultX = _preMultY = 0;
	}

	/** Add individual values to X/Y **/
	public inline function addXY(vx:Float, vy:Float) {
		addX(vx);
		addY(vy);
	}

	public inline function addLen(v:Float) {
		var l = len;
		var a = ang;
		_preMultX = Math.cos(a)*(l + v*preMul);
		_preMultY = Math.sin(a)*(l + v*preMul);
	}
	@:deprecated("This method is no longer implemented.") @:noCompletion public inline function addBoth(v:Float) {}

	/** Set X and Y to specific values **/
	public inline function setXY(vx:Float, vy:Float) {
		setX(vx);
		setY(vy);
	}

	/** Set both X and Y to the same value **/
	public inline function set(v:Float) {
		return _preMultX = _preMultY = v*preMul;
	}
	@:deprecated("Use set(f)") @:noCompletion public inline function setBoth(f:Float) set(f);

	/** Add a vector to this one **/
	public inline function addAng(ang:Float, v:Float) {
		addX( Math.cos(ang) * v );
		addY( Math.sin(ang) * v );
	}

	/** Set X and Y to specific values based on given angle and current length **/
	public inline function setAng(ang:Float, v:Float) {
		setX( Math.cos(ang) * v );
		setY( Math.sin(ang) * v );
	}

	public inline function rotate(angInc:Float) {
		var oldAng = ang;
		var d = len;
		_preMultX = Math.cos(oldAng+angInc) * d;
		_preMultY = Math.sin(oldAng+angInc) * d;
	}


	/** Return true if X and Y are both below the `clearThreshold` value **/
	public inline function isZero() return M.fabs(_preMultX)<=clearThreshold  &&  M.fabs(_preMultY)<=clearThreshold;

	/** Call this method to update Velocity at fixed/constant FPS **/
	public inline function fixedUpdate(frictOverride=-1.) {
		frameUpdate(1, frictOverride);
	}

	/** Call this method to update Velocity at variable FPS **/
	public inline function frameUpdate(tmod:Float, frictOverride=-1.) {
		if( frictOverride>=0 ) {
			_preMultX *= Math.pow(frictOverride,tmod);
			_preMultY *= Math.pow(frictOverride,tmod);
		}
		else {
			_preMultX *= Math.pow(frictX,tmod);
			_preMultY *= Math.pow(frictY,tmod);
		}

		if( M.fabs(_preMultX)<clearThreshold )
			_preMultX = 0;

		if( M.fabs(_preMultY)<clearThreshold )
			_preMultY = 0;
	}


	#if deepnightLibsTests
	public static function test() {
		// Init
		var v = new Velocity();
		CiAssert.equals( v.x, 0 );
		CiAssert.equals( v.y, 0 );
		CiAssert.equals( v.isZero(), true );
		CiAssert.equals( v.shortString(), "0,0" );

		v.setXY(8,2);
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
		v.setXY(8,2);
		v.setFricts(0.25, 0.5);
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "2,1" );
		v.fixedUpdate();
		CiAssert.equals( v.shortString(), "0.5,0.5" );


		// Multiply
		v.setXY(8,2);
		v.mul(2);
		CiAssert.equals( v.shortString(), "16,4" );

		v.mulXY(2,3);
		CiAssert.equals( v.shortString(), "32,12" );

		v.mul(0);
		CiAssert.equals( v.shortString(), "0,0" );
		CiAssert.equals( v.isZero(), true );

		// Addition
		v.setXY(1,1);
		v.addXY(1,1);
		CiAssert.equals( v.shortString(), "2,2" );

		v.addXY(1,2);
		CiAssert.equals( v.shortString(), "3,4" );

		// Frame updates
		var v = new Velocity();
		v.frict = 0.5;
		v.setX(4);
		CiAssert.equals( v.x, 4 );
		v.frameUpdate(2);
		CiAssert.equals( v.x, 1 );
		v.frameUpdate(1);
		CiAssert.equals( v.x, 0.5 );


		// Set signs
		var v = new Velocity();
		v.set(5);
		CiAssert.equals( v.x, 5 );
		CiAssert.equals( v.y, 5 );
		v.setSignX(-1);
		CiAssert.equals( v.x, -5 );
		v.setSignX(1);
		CiAssert.equals( v.x, 5 );
		v.setSignY(1);
		CiAssert.equals( v.y, 5 );


		// Pre-multiplied values
		var v = new Velocity();
		v.frict = 1;
		v.preMul = 0.5;
		CiAssert.equals( v.x, 0 );
		CiAssert.equals( v.y, 0 );

		v.setX(1);
		v.setY(1);
		CiAssert.equals( v.x, 0.5 );
		CiAssert.equals( v.y, 0.5 );

		v.setXY(1,1);
		CiAssert.equals( v.x, 0.5 );
		CiAssert.equals( v.y, 0.5 );

		v.setAng(0, 1);
		CiAssert.equals( v.x, 0.5 );
		CiAssert.equals( v.y, 0 );

		v.setX(100);
		CiAssert.equals( v.x, 50 );
		v.addX(100);
		CiAssert.equals( v.x, 100 );

		// Frame updates with pre-multiplied values
		var v = new Velocity();
		v.setXY(100,100);
		v.preMul = 0.5;
		v.frict = 0.25;
		v.frameUpdate(1);
		CiAssert.equals( v.x, 25 );
		CiAssert.equals( v.y, 25 );
		v.frameUpdate(1);
		CiAssert.equals( v.x, 6.25 );
		CiAssert.equals( v.y, 6.25 );
	}
	#end
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

	/** Get the sum of all X values **/
	public inline function getSumX() {
		_sum = 0.;
		for(v in all)
			_sum+=v._preMultX;
		return _sum;
	}

	/** Get the sum of all Y values **/
	public inline function getSumY() {
		_sum = 0.;
		for(v in all)
			_sum+=v._preMultY;
		return _sum;
	}

	/** Get the overall "total" length of all vectors **/
	public inline function getOverallLen() {
		return Math.sqrt( getSumX()*getSumX() + getSumY()*getSumY() );
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

	public inline function clearAllExcept(exceptId:Int) {
		for(v in all)
			if( v.id!=exceptId )
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
