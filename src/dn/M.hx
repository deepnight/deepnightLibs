/*
 * BASED ON POLYGONAL - A HAXE LIBRARY FOR GAME DEVELOPERS
 * Copyright (c) 2009-2010 Michael Baczynski, http://www.polygonal.de
 */
package dn;

import haxe.macro.Expr;

class M {
	/**
	 * Min value, signed byte.
	 */
	inline public static var T_INT8_MIN =-0x80;

	/**
	 * Max value, signed byte.
	 */
	inline public static var T_INT8_MAX = 0x7F;

	/**
	 * Max value, unsigned byte.
	 */
	inline public static var T_UINT8_MAX = 0xFF;

	/**
	 * Min value, signed short.
	 */
	inline public static var T_INT16_MIN =-0x8000;

	/**
	 * Max value, signed short.
	 */
	inline public static var T_INT16_MAX = 0x7FFF;

	/**
	 * Max value, unsigned short.
	 */
	inline public static var T_UINT16_MAX = 0xFFFF;

	/**
	 * Min value, signed integer.
	 */
	inline public static var T_INT32_MIN =
	#if cpp
	//warning: this decimal constant is unsigned only in ISO C90
	-0x7fffffff;
	#elseif(neko && !neko_v2)
	0xc0000000;
	#else
	0x80000000;
	#end

	/**
	 * Max value, signed integer.
	 */
	inline public static var T_INT32_MAX = #if(neko && !neko_v2) 0x3fffffff #else 0x7fffffff#end;

	/**
	 * Max value, unsigned integer.
	 */
	inline public static var T_UINT32_MAX =  #if(neko && !neko_v2) 0x3fffffff #else 0xffffffff#end;

	/**
	 * Number of bits using for representing integers.
	 */
	inline public static var T_INT_BITS =	#if (neko && neko_v2)
											32;
										#elseif(neko)
											31;
										#else
											32;
										#end

	/**
	 * The largest representable number (single-precision IEEE-754).
	 */
	inline public static var T_FLOAT_MAX = 3.4028234663852886e+38;

	/**
	 * The smallest representable number (single-precision IEEE-754).
	 */
	inline public static var T_FLOAT_MIN = -3.4028234663852886e+38;

	/**
	 * The largest representable number (double-precision IEEE-754).
	 */
	inline public static var T_DOUBLE_MAX = 1.7976931348623157e+308;

	/**
	 * The smallest representable number (double-precision IEEE-754).
	 */
	inline public static var T_DOUBLE_MIN = -1.7976931348623157e+308;

	/**
	 * IEEE 754 NAN.
	 */
	#if !flash
	inline public static function NaN() { return Math.NaN; }
	#else
	inline public static function NaN() { return .0 / .0; }
	#end
	/**
	 * IEEE 754 positive infinity.
	 */
	#if !flash
	inline public static function POSITIVE_INFINITY() { return Math.POSITIVE_INFINITY; }
	#else
	inline public static function POSITIVE_INFINITY() { return  1. / .0; }
	#end
	/**
	 * IEEE 754 negative infinity.
	 */
	#if !flash
	inline public static function NEGATIVE_INFINITY() { return Math.NEGATIVE_INFINITY; }
	#else
	inline public static function NEGATIVE_INFINITY() { return -1. / .0; }
	#end

	/**
	 * Multiply value by this constant to convert from radians to degrees.
	 */
	inline public static var RAD_DEG = 180 / PI;

	/**
	 * Multiply value by this constant to convert from degrees to radians.
	 */
	inline public static var DEG_RAD = PI / 180;

	/**
	 * The natural logarithm of 2.
	 */
	inline public static var LN2 = 0.6931471805599453;

	/* Math.PI/2 */
	inline public static var PIHALF = 1.5707963267948966;

	/* Math.PI */
	inline public static var PI   = 3.141592653589793;

	/* Math.PI*2 */
	inline public static var PI2  = 6.283185307179586;

	/* Math.PI*2 */
	inline public static var A360 = PI2;

	/* Math.PI */
	inline public static var A180 = PI;

	/* Math.PI/2 */
	inline public static var A90  = PIHALF;

	/* Math.PI/4 */
	inline public static var A45  = 0.785398163397448;

	/**
	 * Default system epsilon.
	 */
	inline public static var EPS = 1e-6;

	/**
	 * The square root of 2.
	 */
	inline public static var SQRT2 = 1.414213562373095;

	/**
	 * Converts deg to radians.
	 */
	inline public static function toRad(deg:Float):Float
	{
		return deg * M.DEG_RAD;
	}

	/**
	 * Converts rad to degrees.
	 */
	inline public static function toDeg(rad:Float):Float
	{
		return rad * M.RAD_DEG;
	}

	/**
	 * Returns min(x, y).
	 */
	inline public static function imin(x:Int, y:Int):Int
	{
		return x < y ? x : y;
	}

	/**
	 * Returns max(x, y).
	 */
	inline public static function imax(x:Int, y:Int):Int
	{
		return x > y ? x : y;
	}

	/**
	 * Returns the absolute value of x.
	 */
	inline public static function iabs(x:Int):Int
	{
		return x < 0 ? -x : x;
	}

	/**
	 * Returns the sign of x.
	 * sgn(0) = 0.
	 */
	inline public static function sign(x:Float):Int {
		return (x > 0) ? 1 : (x < 0 ? -1 : 0);
	}
	inline public static function signEq(x:Float,y:Float):Bool {
		return M.sign(x)==M.sign(y);
	}

	/**
		Always return a non-zero value
	**/
	public static inline function notZero(v:Float, ifZero=0.000001) {
		return v==0 ? ifZero : v;
	}

	/**
	 * Clamps x to the interval so min <= x <= max.
	 */
	inline public static function iclamp(x:Int, min:Int, max:Int):Int
	{
		return (x < min) ? min : (x > max) ? max : x;
	}

	/**
	 * Clamps x to the interval so -i <= x <= i.
	 */
	inline public static function clampSym(x:Int, i:Int):Int
	{
		return (x < -i) ? -i : (x > i) ? i : x;
	}

	/**
	 * Wraps x to the interval so min <= x <= max.
	 */
	inline public static function wrap(x:Int, min:Int, max:Int):Int
	{
		return x < min ? (x - min) + max + 1: ((x > max) ? (x - max) + min - 1: x);
	}

	/**
	 * Fast replacement for Math.min(x, y).
	 */
	inline public static function fmin(x:Float, y:Float):Float
	{
		return x < y ? x : y;
	}

	/**
	 * Fast replacement for Math.max(x, y).
	 */
	inline public static function fmax(x:Float, y:Float):Float
	{
		return x > y ? x : y;
	}

	/**
	 * Fast replacement for Math.abs(x).
	 */
	inline public static function fabs(x:Float):Float
	{
		return x < 0 ? -x : x;
	}

	/**
	 * Extracts the sign of x.
	 * fsgn(0) = 0.
	 */
	inline public static function fsgn(x:Float):Int
	{
		return (x > 0.) ? 1 : (x < 0. ? -1 : 0);
	}

	/**
	 * Clamps x to the interval so min <= x <= max.
	 */
	inline public static function fclamp(x:Float, min:Float, max:Float):Float
	{
		return (x < min) ? min : (x > max) ? max : x;
	}

	/**
	 * Clamps x to the interval so -i <= x <= i.
	 */
	inline public static function fclampSym(x:Float, i:Float):Float
	{
		return (x < -i) ? -i : (x > i) ? i : x;
	}

	/**
	 * Wraps x to the interval so min <= x <= max.
	 */
	inline public static function fwrap(value:Float, lower:Float, upper:Float):Float
	{
		return value - (Std.int((value - lower) / (upper - lower)) * (upper - lower));
	}

	/**
	 * Returns true if the sign of x and y is equal.
	 */
	inline public static function eqSgn(x:Int, y:Int):Bool
	{
		return (x ^ y) >= 0;
	}

	/**
	 * Returns true if the sign of x and y is equal.
	 */
	inline public static function feqSgn(x:Float, y:Float):Bool
	{
		return x*y >= 0;
	}

	/**
	 * Returns true if x is even.
	 */
	inline public static function isEven(x:Int):Bool
	{
		return (x & 1) == 0;
	}

	/**
	 * Returns true if x is a power of two.
	 */
	inline public static function isPow2(x:Int):Bool
	{
		return x > 0 && (x & (x - 1)) == 0;
	}

	/**
	 * Returns the nearest power of two value
	 */
	inline public static function nearestPow2( x:Int )
	{
		return Math.pow( 2, Math.round( Math.log( x ) / Math.log( 2 ) ) );
	}

	/**
	 * Linear interpolation over interval a...b with t = 0...1
	 */
	inline public static function lerp(a:Float, b:Float, t:Float):Float
	{
		return a + (b - a) * t;
	}

	/**
	 * Spherically interpolates between two angles.
	 * See <a href="http://www.paradeofrain.com/2009/07/interpolating-2d-rotations/" target="_blank">http://www.paradeofrain.com/2009/07/interpolating-2d-rotations/</a>.
	 */
	inline public static function slerp(a:Float, b:Float, t:Float)
	{
		var m = Math;

        var c1 = m.sin(a * .5);
        var r1 = m.cos(a * .5);
		var c2 = m.sin(b * .5);
        var r2 = m.cos(b * .5);

       var c = r1 * r2 + c1 * c2;

        if( c < 0.)
		{
			if( (1. + c) > M.EPS)
			{
				var o = m.acos(-c);
				var s = m.sin(o);
				var s0 = m.sin((1 - t) * o) / s;
				var s1 = m.sin(t * o) / s;
				return m.atan2(s0 * c1 - s1 * c2, s0 * r1 - s1 * r2) * 2.;
			}
			else
			{
				var s0 = 1 - t;
				var s1 = t;
				return m.atan2(s0 * c1 - s1 * c2, s0 * r1 - s1 * r2) * 2;
			}
		}
		else
		{
			if( (1 - c) > M.EPS)
			{
				var o = m.acos(c);
				var s = m.sin(o);
				var s0 = m.sin((1 - t) * o) / s;
				var s1 = m.sin(t * o) / s;
				return m.atan2(s0 * c1 + s1 * c2, s0 * r1 + s1 * r2) * 2.;
			}
			else
			{
				var s0 = 1 - t;
				var s1 = t;
				return m.atan2(s0 * c1 + s1 * c2, s0 * r1 + s1 * r2) * 2;
			}
		}
	}

	/**
	 * Calculates the next highest power of 2 of x.
	 */
	inline public static function nextPow2(x:Int):Int
	{
		var t = x;
		t |= (t >> 0x01);
		t |= (t >> 0x02);
		t |= (t >> 0x03);
		t |= (t >> 0x04);
		t |= (t >> 0x05);
		return t + 1;
	}

	/**
	 * Fast integer exponentiation for base a and exponent n.
	 */
	inline public static function exp(a:Int, n:Int):Int
	{
		var t = 1;
		var r = 0;
		while (true)
		{
			if( n & 1 != 0) t = a * t;
			n >>= 1;
			if( n == 0)
			{
				r = t;
				break;
			}
			else
				a *= a;
		}
		return r;
	}

	/**
	 * Rounds x to the interval y.
	 */
	inline public static function roundTo(x:Float, y:Int):Int {
		return round(x / y) * y;
	}

	/**
	 * Fast replacement for Math.round(x).
	 */
	inline public static function round(x:Float):Int
	{
		return Std.int(x > 0 ? x + .5 : x < 0 ? x - .5 : 0);
	}

	/**
	 * Fast replacement for Math.ceil(x).
	 */
	inline public static function ceil(x:Float):Int
	{
		if( x > .0)
		{
			var t = Std.int(x + .5);
			return (t < x) ? t + 1 : t;
		}
		else if( x < .0)
		{
			var t = Std.int(x - .5);
			return (t < x) ? t + 1 : t;
		}
		else
			return 0;
	}

	/**
	 * Fast replacement for Math.floor(x).
	 */
	inline public static function floor(x:Float) : Int {
		return
			if( x>=0 )
				Std.int(x);
			else {
				var i = Std.int(x);
				if( x==i )
					i;
				else
					i - 1;
			}
	}

	/**
	 * Computes the 'quake-style' fast inverse square root of x.
	 */
	inline public static function invSqrt(x:Float):Float
	{
		/*
		#if( flash10 && !no_alchemy)
		var xt = x;
		var half = .5 * xt;
		var i = floatToInt(xt);
		i = 0x5f3759df - (i >> 1);
		var xt = intToFloat(i);
		return xt * (1.5 - half * xt * xt);
		#else
		return 1 / Math.sqrt(x);
		#end
		*/
		return 1 / Math.sqrt(x);
	}

	/**
	 * Compares x and y using an absolute tolerance of eps.
	 */
	inline public static function cmpAbs(x:Float, y:Float, eps:Float):Bool
	{
		var d = x - y;
		return d > 0 ? d < eps : -d < eps;
	}

	/**
	 * Compares x to zero using an absolute tolerance of eps.
	 */
	inline public static function cmpZero(x:Float, eps:Float):Bool
	{
		return x > 0 ? x < eps : -x < eps;
	}

	/**
	 * Snaps x to the grid y.
	 */
	inline public static function snap(x:Float, y:Float):Float
	{
		return floor((x + y * .5) / y);
	}

	/**
	 * Returns true if min <= x <= max.
	 */
	inline public static function inRange(x:Float, min:Float, max:Float):Bool
	{
		return x >= min && x <= max;
	}

	/**
		Returns a seeded random for a x/y coord. Result range: [0->max[
	**/
	public static inline function randSeedCoords(seed:Int, x:Int, y:Int, max:Int) {
		// Source: https://stackoverflow.com/questions/37128451/random-number-generator-with-x-y-coordinates-as-seed
		var h = seed + x*374761393 + y*668265263; // all constants are prime
		h = (h^(h >> 13)) * 1274126177;
		return ( h^(h >> 16) ) % max;
	}

	/**
	 * Returns a pseudo-random integral value x, where 0 <= x < 0x7fffffff  0 <= x < 0x3FFFFFFF on Neko1
	 */
	inline public static function rand(?max:Int=#if neko 0x3FFFFFFF #else 0x7fffffff #end, ?rnd:Void->Float):Int
	{
		return Std.int(frand(rnd) * max);
	}

	/**
	 * Returns a pseudo-random integral value x, where min <= x <= max.
	 */
	inline public static function randRange(min:Int, max:Int, ?rnd:Void->Float):Int
	{
		var l = min - .4999;
		var h = max + .4999;
		return M.round(l + (h - l) * frand(rnd));
	}

	/**
	 * Returns a pseudo-random double value x, where -range <= x <= range.
	 */
	inline public static function randRangeSym(range:Int, ?rnd:Void->Float):Int
	{
		return randRange(-range, range, rnd);
	}

	/**
	 * Returns a pseudo-random double value x, where 0 <= x < 1.
	 */
	inline public static function frand(?rnd:Void->Float):Float
	{
		return
			if ( rnd == null )
				Math.random();
			else
				rnd();
	}

	/**
	 * Returns a pseudo-random double value x, where min <= x < max.
	 */
	inline public static function frandRange(min:Float, max:Float, ?rnd:Void->Float):Float
	{
		return min + (max - min) * frand(rnd);
	}

	/**
	 * Returns a pseudo-random double value x, where -range <= x < range.
	 */
	inline public static function frandRangeSym(range:Float, ?rnd:Void->Float):Float
	{
		return frandRange(-range, range, rnd);
	}

	/**
	 * Wraps an angle x to the range -PI...PI by adding the correct multiple of 2 PI.
	 */
	inline public static function wrapToPi(x:Float):Float
	{
		var t = round(x / PI2);
		return (x < -PI) ? (x - t * PI2) : (x > PI ? x - t * PI2 : x);
	}

	/**
	 * Wraps a number to the range -mod...mod
	 * Donne des résultats différents de budum9.Num.hMod mais devrait fonctionner en gros de la meme façon.
	 */
	inline public static function wrapTo(n:Float, mod:Float)
	{
		var t = round(n / mod);
		return (n < -2*mod) ? (n - t * mod) : (n > 2*mod ? n - t * mod : n);
	}

	/**
	 * Modulo simple
	 */
	inline static public function sMod(n:Float, mod:Float):Float
	{
		if ( mod != 0.0  )
		{
			while(n >= mod) n -= mod;
			while (n < 0) n += mod;
		}
		return n;
	}

	/**
	 * Module avec partie négative
	 */
	inline static public function hMod(n:Float, mod:Float):Float
	{
		while(n > mod) n -= mod*2;
		while(n < -mod) n += mod*2;
		return n;
	}

	/**
	 * Computes the greatest common divisor of x and y.
	 * See <a href="http://www.merriampark.com/gcd.htm" target="_blank">http://www.merriampark.com/gcd.htm</a>.
	 */
	inline public static function gcd(x:Int, y:Int):Int
	{
		var d = 0;
		var r = 0;
		x = M.iabs(x);
		y = M.iabs(y);
		while (true)
		{
			if( y == 0)
			{
				d = x;
				break;
			}
			else
			{
				r = x % y;
				x = y;
				y = r;
			}
		}
		return d;
	}

	/**
	 * Removes excess floating point decimal precision from x.
	 */
	inline public static function maxPrecision(x:Float, precision:Int):Float
	{
		if( x == 0)
			return x;
		else
		{
			var correction = 10;
			for (i in 0...precision - 1) correction *= 10;
			return round(correction * x) / correction;
		}
	}

	/**
	 * Converts the boolean expression x to an integer.
	 * @return 1 if x is true and zero if x is false.
	 */
	inline public static function ofBool(x:Bool):Int
	{
		return x ? 1 : 0;
	}


	/**
	 * mod that allways returns a positive value ( neg % k -> neg )
	 */
	public static inline function posMod( i :Int,m:Int ){
		var mod = i % m;
		return (mod >= 0)
		? mod
		: mod + m;
	}


	/**
	 * Replaces pow(v, 3) by v*v*v at compilation time (macro), 17x faster results
	 * Limitations: "pow" must be a constant Int [0-256], no variable allowed
	 */
	macro public static function pow(v:Expr, power:Expr) {
		var pos = haxe.macro.Context.currentPos();
		var v = { expr:EParenthesis(v), pos:pos }

		var ipow = switch( power.expr ) {
			case EConst(CInt(v)) : Std.parseInt(v);
			default : haxe.macro.Context.error("You can only use a constant Int here", power.pos);
		}

		if( ipow<=0 || ipow>256 )
			haxe.macro.Context.error("Only values between [0-256] are supported", power.pos);

		function recur(n:Int) : Expr {
			if( n>1 )
				return {expr:EBinop(OpMult, v, recur(n-1)), pos:pos}
			else
				return v;
		}
		return recur(ipow);
	}

	public static inline function distSqr(ax:Float,ay:Float,bx:Float,by:Float) : Float {
		return (ax-bx)*(ax-bx) + (ay-by)*(ay-by);
	}

	public static inline function idistSqr(ax:Int,ay:Int,bx:Int,by:Int) : Int {
		return (ax-bx)*(ax-bx) + (ay-by)*(ay-by);
	}

	public static inline function dist(ax:Float,ay:Float, bx:Float,by:Float) : Float {
		return Math.sqrt( distSqr(ax,ay,bx,by) );
	}


	/**
	 * Distance from point x,y to segment A(ax,ay)-B(bx,by)
	 */
	public static inline function distSegment(x:Float, y:Float, ax:Float, ay:Float, bx:Float, by:Float) { // point: x,y
		return Math.sqrt( distSegmentSqr(x,y, ax,ay, bx,by) );
	}

	/**
	 * Squared distance from point x,y to segment A(ax,ay)-B(bx,by)
	 */
	public static inline function distSegmentSqr(x:Float, y:Float, ax:Float, ay:Float, bx:Float, by:Float) {
		// Source: https://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
		var l2 = distSqr(ax,ay, bx,by);
		if( l2==0 )
			return distSqr(x,y, ax,ay);
		var t = fclamp( ( (x-ax)*(bx-ax) + (y-ay)*(by-ay) ) / l2, 0, 1 );
		return distSqr( x, y, ax+t*(bx-ax), ay+t*(by-ay) );
	}

	public static function factorial(v : Int) {
		var r = 1;
		for (i in 1...(v+1)) r *= i;
		return r;
	}



	public static inline function normalizeDeg(a:Float) { // [-180,180]
		while( a<-180 ) a+=360;
		while( a>180 ) a-=360;
		return a;
	}

	public static inline function normalizeRad(a:Float) { // [-PI,PI]
		while( a<-M.PI ) a+=M.PI2;
		while( a>M.PI ) a-=M.PI2;
		return a;
	}

	public static inline function degDistance(a:Float,b:Float) {
		return fabs( degSubstract(a,b) );
	}

	public static inline function degSubstract(a:Float,b:Float) { // returns a-b (normalized)
		return normalizeDeg( normalizeDeg(a) - normalizeDeg(b) );
	}

	public static inline function radClamp(a:Float, refAng:Float, maxDelta:Float) {
		var d = radSubstract(a,refAng);
		if( d>maxDelta ) return refAng+maxDelta;
		if( d<-maxDelta ) return refAng-maxDelta;
		return a;
	}

	public static inline function radDistance(a:Float,b:Float) {
		return fabs( radSubstract(a,b) );
	}

	public static inline function radCloseTo(curAng:Float, target:Float, maxAngDist:Float) {
		return radDistance(curAng, target) <= M.fabs(maxAngDist);
	}

	public static inline function radSubstract(a:Float,b:Float) { // returns a-b (normalized)
		a = normalizeRad(a);
		b = normalizeRad(b);
		return normalizeRad(a-b);
	}

	public static inline function angTo(fx:Float, fy:Float, tx:Float, ty:Float) {
		return Math.atan2(ty-fy, tx-fx);
	}

	/** Round a float to given precision **/
	public static inline function pretty(v:Float, precision=2) : Float {
		if( precision<=0 )
			return round(v);
		else {
			var d = Math.pow(10,precision);
			return round(v*d)/d;
		}
	}

	/**
		Round a float to given precision, adding leading zeros if needed.
		Examplex:
			0.1234, precision 2, returns 0.12
			0.1, precision 2, returns 0.10
	**/
	public static inline function prettyPad(v:Float, precision=2) : String {
		var str = Std.string( pretty(v,precision) );
		while( str.length-(str.lastIndexOf(".")+1) < precision )
			str+="0";
		return str;
	}

	public static inline function groupNumbers(v:Int, sep=" ") : String {
		var str = Std.string(v);
		if( str.length<=3 )
			return str;
		else {
			var i = 1;
			var out = "";
			while( i<=str.length ) {
				out = str.substr(-i,1) + out;
				if( i%3==0 && i<str.length )
					out = sep+out;
				i++;
			}
			return out;
		}
	}

	public static inline function unit(v:Float, precision=1) : String {
		return M.fabs(v)<1000 ? Std.string( pretty(v, precision) )
			: M.fabs(v)<1000000 ? M.pretty(v/1000, precision)+"K"
			: M.pretty(v/1000000, precision)+"M";
	}

	public static inline function unitMega(v:Float, precision=1) : String {
		return M.pretty(v/1000000, precision) + "M";
	}


	/**
		Print a signed Integer as binary
	**/
	public static function intToBitString(v:Int, ?pad=8) {
		var out = "";
		var i : Int = 0;
		while( setBit(0, i)<=v && i<31)
			out = ( hasBit(v, i++) ? "1" : "0" ) + out;

		while( out.length<pad )
			out = "0"+out;

		return out;
	}

	/**
		Print an unsigned Integer as binary
	**/
	public static function uIntToBitString(v:UInt, ?pad=8) {
		var out = "";
		var i : UInt = 0;
		while( setUnsignedBit(0, i)<=v && i<=31)
			out = ( hasUnsignedBit(v, i++) ? "1" : "0" ) + out;

		while( out.length<pad )
			out = "0"+out;

		return out;
	}

	/**
		Set a SIGNED integer bit to 1 (bit index starts from 0)
	**/
	public static inline function setBit(baseValue:Int, bitIdx:Int) : Int {
		return baseValue | ( 1<<bitIdx );
	}

	/**
		Set a SIGNED integer bit to 0 (bit index starts from 0)
	**/
	public static inline function unsetBit(baseValue:Int, bitIdx:Int) : Int {
		return baseValue & ~( 1<<bitIdx );
	}

	public static function makeBitsFromArray(bools:Array<Bool>) : Int {
		if( bools.length>32 )
			throw "Too many values (32bits max)";

		var v = 0;
		for(i in 0...bools.length)
			if( bools[i]==true )
				v = setBit(v, i);
		return v;
	}

	public static function makeBitsFromBools(
		b0=false,
		b1=false,
		b2=false,
		b3=false,
		b4=false,
		b5=false,
		b6=false,
		b7=false
	) {

		var v = 0;
		if( b0 ) v = setBit(v,0);
		if( b1 ) v = setBit(v,1);
		if( b2 ) v = setBit(v,2);
		if( b3 ) v = setBit(v,3);
		if( b4 ) v = setBit(v,4);
		if( b5 ) v = setBit(v,5);
		if( b6 ) v = setBit(v,6);
		if( b7 ) v = setBit(v,7);
		return v;
	}

	/**
		Check for bit presence in a SIGNED integer (index starts from 0)
	**/
	public static inline function hasBit(v:Int, bitIdx:Int) : Bool{
		return v & ( 1<<bitIdx ) != 0;
	}

	/**
		Set an UNSIGNED integer bit to 1 (index starts from 0)
	**/
	public static inline function setUnsignedBit(baseValue:UInt, bitIdx:Int) : UInt {
		return baseValue | ( 1<<bitIdx );
	}

	/**
		Check for bit presence in an UNSIGNED integer (index starts from 0)
	**/
	public static inline function hasUnsignedBit(v:UInt, bitIdx:Int) : Bool{
		var one : UInt = 1;
		return v & ( one<<bitIdx ) != 0;
	}


	/**
		Return TRUE if `v` is a valid number (not null, NaN or infinite)
	**/
	public static inline function isValidNumber(v:Null<Float>) {
		return v!=null && !Math.isNaN(v) && Math.isFinite(v);
	}


	/**
		Parse a String to an Int. If the parsing result is not a valid number, returns the provided default value.
	 **/
	public static inline function parseInt(str:String, defaultIfInvalid:Int) {
		if( str==null )
			return defaultIfInvalid;
		else {
			var v = Std.parseInt(str);
			return isValidNumber(v) ? v : defaultIfInvalid;
		}
	}

	/**
		Returns 4-points Bezier interpolation, `t` being the "time" (0-1) and `p0-p3` being control points.
		More: https://javascript.info/bezier-curve
		Online demo: https://www.desmos.com/calculator/cahqdxeshd?lang=fr
	**/
	public static inline function bezier4(t:Float, p0:Float, p1:Float,p2:Float, p3:Float) {
		t = M.fclamp(t,0,1);
		return
			fastPow3(1-t) * p0 +
			3*t*fastPow2(1-t) * p1 +
			3*fastPow2(t)*(1-t) * p2 +
			fastPow3(t) * p3;
	}

	/**
		Returns 3-points Bezier interpolation, `t` being the "time" (0-1) and `p0-p3` being control points.
		More: https://javascript.info/bezier-curve
	**/
	public static inline function bezier3(t:Float, p0:Float, p1:Float,p2:Float) {
		t = M.fclamp(t,0,1);
		return
			fastPow2(1-t) * p0 +
			2*t * (1-t) * p1 +
			fastPow2(t) * p2;
	}

	public static inline function bezierFull4(t:Float, x0:Float,x1:Float,x2:Float,x3:Float,  y0:Float,y1:Float,y2:Float,y3:Float ) {
		return bezier4( bezier4(t, x0, x1, x2, x3), y0, y1, y2, y3 );
	}

	static inline function fastPow2(n:Float):Float return n*n;
	static inline function fastPow3(n:Float):Float return n*n*n;


	public static inline function rotateX(x:Float, y:Float, rotCenterX:Float, rotCenterY:Float, ang:Float) {
		return rotCenterX  +  (x-rotCenterX) * Math.cos(ang)  +  (y-rotCenterY) * Math.sin(ang);
	}

	public static inline function rotateY(x:Float, y:Float, rotCenterX:Float, rotCenterY:Float, ang:Float) {
		return rotCenterY  -  (x-rotCenterX) * Math.sin(ang)  +  (y-rotCenterY) * Math.cos(ang);
	}


	/**
		Return a 0-1 ratio by "clamping" `r` to [min,max].
		 - If r<=min, this returns 0,
		 - If r>=min and r<=max, this returns 0 to 1,
		 - If r>=max, this returns 1,
	**/
	public static inline function subRatio(r:Float, min:Float, max:Float) : Float {
		return M.fclamp( (r-min) / (max-min), 0, 1 );
	}

	@:noCompletion
	public static function __test() {
		// TODO more tests
		CiAssert.isTrue( M.round(1.2)==1 );
		CiAssert.isTrue( M.round(1.5)==2 );
		CiAssert.isTrue( M.round(-1.5)==-2 );
		CiAssert.isTrue( M.ceil(-1.5)==-1 );
		CiAssert.isTrue( M.floor(-1.5)==-2 );
		CiAssert.isTrue( M.isValidNumber(1.5) );
		CiAssert.isTrue( !M.isValidNumber(null) );
		CiAssert.isTrue( !M.isValidNumber(1/0) );

		// Bit set
		CiAssert.equals( M.setBit(0,0), 1 );
		CiAssert.equals( M.setBit(0,3), 8 );
		CiAssert.equals( M.setBit(16,0), 17 );
		CiAssert.equals( M.setBit(16,1), 18 );

		// Bit unset
		CiAssert.equals( M.unsetBit(9,0), 8 );
		CiAssert.equals( M.unsetBit(9,3), 1 );
		CiAssert.equals( M.unsetBit(25,0), 24 );
		CiAssert.equals( M.unsetBit(25,1), 25 );
		CiAssert.equals( M.unsetBit(25,3), 17 );
		CiAssert.equals( M.unsetBit(25,4), 9 );
		CiAssert.equals( M.unsetBit(25,5), 25 );
		CiAssert.equals( M.unsetBit(1073741824,30), 0 );

		// Bit has
		CiAssert.isTrue( M.hasBit(1,0) );
		CiAssert.isTrue( M.hasBit(3,0) );
		CiAssert.isTrue( M.hasBit(3,1) );
		CiAssert.isTrue( M.hasBit(1073741824,30) );


		var uIntWithBit31 = M.setUnsignedBit(0,31);
		CiAssert.isTrue( M.hasUnsignedBit(uIntWithBit31,31) );
		CiAssert.isTrue( uIntWithBit31>0 );
		var intWithBit31 = M.setBit(0,31);
		CiAssert.isTrue( M.hasUnsignedBit(intWithBit31,31) );
		CiAssert.isTrue( intWithBit31<0 );
		CiAssert.equals( intToBitString(17,8), "00010001" );
		CiAssert.equals( uIntToBitString( M.setUnsignedBit(0,31) ), "10000000000000000000000000000000" );
		CiAssert.equals( intToBitString( M.setUnsignedBit(0,31), 0 ), "" );

		CiAssert.equals( makeBitsFromBools(), 0 );
		CiAssert.equals( makeBitsFromBools(true), 1 );
		CiAssert.equals( makeBitsFromBools(true,false,true), 5 );
		CiAssert.equals( makeBitsFromBools(true,true,true,true,true,true,true,true), 0xff );
		CiAssert.equals( makeBitsFromArray([]), 0 );
		CiAssert.equals( makeBitsFromArray([true]), 1 );
		CiAssert.equals( makeBitsFromArray([true,true,true,true,true,true,true,true]), 0xff );

		CiAssert.equals( parseInt("59", -1), 59 );
		CiAssert.equals( parseInt("??", -1), -1 );
		CiAssert.equals( parseInt("59foo", -1), 59 );
		CiAssert.equals( parseInt("foo59bar", -1), -1 );
		CiAssert.equals( parseInt("1.9", -1), 1 );
		CiAssert.equals( parseInt("-99", -1), -99 );

		CiAssert.equals( bezier3(0,  0, 1, 0.5 ), 0 );
		CiAssert.equals( bezier3(0.5,  0, 1, 0.5 ), 0.625 );
		CiAssert.equals( bezier3(1,  0, 1, 0.5 ), 0.5 );

		CiAssert.equals( bezier4(0,  0, 0.4, 0.9, 1 ), 0 );
		CiAssert.equals( bezier4(0.5,  0, 0.4, 0.9, 1 ), 0.6125 );
		CiAssert.equals( bezier4(1,  0, 0.4, 0.9, 1 ), 1 );

		// Prettifiers
		CiAssert.equals( M.pretty(1.123,1), 1.1 );
		CiAssert.equals( M.pretty(1.123,2), 1.12 );

		CiAssert.equals( M.groupNumbers(123), "123" );
		CiAssert.equals( M.groupNumbers(1234), "1 234" );
		CiAssert.equals( M.groupNumbers(12345), "12 345" );
		CiAssert.equals( M.groupNumbers(1234567), "1 234 567" );

		CiAssert.equals( M.unit(1000), "1K" );
		CiAssert.equals( M.unit(1234), "1.2K" );
		CiAssert.equals( M.unit(1234,2), "1.23K" );
		CiAssert.equals( M.unit(1000000), "1M" );
		CiAssert.equals( M.unit(1500000), "1.5M" );

		CiAssert.equals( M.unitMega(1234), "0M" );
		CiAssert.equals( M.unitMega(123456), "0.1M" );
		CiAssert.equals( M.unitMega(1234567), "1.2M" );
		CiAssert.equals( M.unitMega(1234567,2), "1.23M" );
		CiAssert.equals( M.unitMega(1500000), "1.5M" );

		CiAssert.equals( M.subRatio(0.1,  0.5, 0.7), 0 );
		CiAssert.equals( M.subRatio(0.5,  0.5, 0.7), 0 );
		CiAssert.equals( M.subRatio(0.6,  0.5, 0.7), 0.5 );
		CiAssert.equals( M.subRatio(0.7,  0.5, 0.7), 1 );
		CiAssert.equals( M.subRatio(0.9,  0.5, 0.7), 1 );
	}
}
