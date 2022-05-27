package dn;

/**
	This class should be imported with an alias for easier use.
	```haxe
	import RandomTools as R;
	```
**/

class RandomTools {

	/** Random Float value within specified range. If `sign` is true, the value will be either between [min,max] or [-max,-min].**/
	public static inline function rng(min:Float, max:Float, sign=false) {
		if( sign )
			return (min + Math.random()*(max-min)) * (Std.random(2)*2-1);
		else
			return min + Math.random()*(max-min);
	}

	/** Random Integer value within specified range. If `sign` is true, the value will be either between [min,max] or [-max,-min]. **/
	public static inline function irng(min:Int, max:Int, sign=false) {
		if( sign )
			return (min + Std.random(max-min+1)) * (Std.random(2)*2-1);
		else
			return min + Std.random(max-min+1);
	}

	/** Randomly variate given value `v` in +/- `pct`%. If `sign` is true, the value will some times be multiplied by -1. **/
	public static inline function around(v:Float, pct=10, sign=false) {
		return v * ( 1 + rng(0,pct/100,true) ) * ( sign ? RandomTools.sign() : 1 );
	}

	/** Returns -1 or 1 randomly **/
	public static inline function sign() {
		return Std.random(2)*2-1;
	}

	/** Randomly variate given value `v` in +/- `pct`%, and ensures result is in range [0,1] **/
	public static inline function aroundZTO(v:Float, pct=10) {
		return M.fclamp( v * ( 1 + rng(0,pct/100,true) ), 0, 1 );
	}

	/** Randomly variate given value `v` in +/- `pct`%, and ensures result is capped to 1 **/
	public static inline function aroundBO(v:Float, pct=10) {
		return M.fmin( v * ( 1 + rng(0,pct/100,true) ), 1 );
	}

	/** Random float value in range [0,v]. If `sign` is true, the value will be in [-v,v]. **/
	public static inline function zeroTo(v:Float, sign=false) {
		return rng(0,v,sign);
	}

	/** Random float in range [0,1]. If `sign` is true, the value will be in [-1,1]. **/
	public static inline function zto(sign=false) {
		return rng(0,1, sign);
	}

	/** Random color by interpolating R, G & B components **/
	public static inline function colorMix(minColor:UInt, maxColor:UInt) : UInt {
		return dn.legacy.Color.interpolateInt( minColor, maxColor, rng(0,1) );
	}

	/** Create a color with optional HSL parameters. If `hue` is omitted, it will be random. **/
	public static inline function color(?hue:Float, sat=1.0, lum=1.0) {
		return dn.legacy.Color.makeColorHsl( hue==null ? zto() : hue, sat, lum );
	}

	/** Random radian angle in range [0,2PI] **/
	public static inline function fullCircle() return rng(0, M.PI2);

	/** Random radian angle in range [0,PI] **/
	public static inline function halfCircle() return rng(0, M.PI);

	/** Random radian angle in range [0,PI/2] **/
	public static inline function quarterCircle() return rng(0, M.PIHALF);

	/** Random radian angle in range [ang-maxDist, ang+maxDist] **/
	public static inline function angleAround(ang:Float, maxDist:Float) {
		return ang + rng(0, maxDist, true);
	}

	/** Return TRUE if a random percentage (ie. 0-100) is below given threshold **/
	public static inline function pct(thresholdOrBelow:Int) {
		return Std.random(100) < thresholdOrBelow;
	}


	/** Pick a value randomly in an array **/
	public static inline function pick<T>(a:Array<T>) : Null<T> {
		return a.length==0 ? null : a[Std.random(a.length)];
	}


	/**
		Randomly spread `value` in `nbStacks` stacks. Example:
	**/
	public static function spreadInStacks(value:Int, nbStacks:Int, ?maxStackValue:Null<Int>, randFunc:Int->Int) : Array<Int> {
		if( value<=0 || nbStacks<=0 )
			return new Array();

		if( maxStackValue!=null && value/nbStacks>maxStackValue ) {
			var a = [];
			for(i in 0...nbStacks)
				a.push(maxStackValue);
			return a;
		}

		if( nbStacks>value ) {
			var a = [];
			for(i in 0...value)
				a.push(1);
			return a;
		}

		var plist = new Array();
		for (i in 0...nbStacks)
			plist[i] = 1;

		var remain = value-plist.length;
		while (remain>0) {
			var move = M.ceil(value*(randFunc(8)+1)/100);
			if (move>remain)
				move = remain;

			var p = randFunc(nbStacks);
			if( maxStackValue!=null && plist[p]+move>maxStackValue )
				move = maxStackValue - plist[p];
			plist[p]+=move;
			remain-=move;
		}
		return plist;
	}



	@:noCompletion
	public static function __test() {
		// TODO
	}

}