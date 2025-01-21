package dn;

enum abstract TinyTweenInterpolation(Int) to Int {
	var Linear;
	var EaseIn;
	var EaseOut;
	var EaseInOut;
	var BackForth;
}

class TinyTween {
	var fps : Int;
	var fromValue : Float;
	var toValue : Float;
	var elapsedS : Float;
	var durationS : Float;
	var interp : TinyTweenInterpolation = Linear;
	public var curValue(get,never) : Float;

	public inline function new(fps) {
		this.fps = fps;
		reset();
	}

	public inline function reset() {
		fromValue = toValue = 0;
		durationS = elapsedS = 0;
	}

	inline function get_curValue() {
		if( isComplete() )
			return switch interp {
				case BackForth: fromValue;
				case _: toValue;
			}

		final ratio = switch interp {
			case Linear: elapsedS/durationS;
			case EaseIn: M.bezier4( elapsedS/durationS, 0, 0, 0.5, 1 );
			case EaseOut: M.bezier4( elapsedS/durationS, 0, 0.5, 1, 1 );
			case EaseInOut: M.bezierFull4( elapsedS/durationS,   0, 0.5, 0.5, 1,   0, 0, 1, 1 );
			case BackForth: M.bezier4( elapsedS/durationS, 0, 1+1/3, 1+1/3, 0 );
		}
		return fromValue + ( toValue - fromValue ) * ratio;
	}

	public inline function isComplete() {
		return elapsedS>=durationS;
	}

	public inline function getElapsedRatio() : Float {
		return isComplete() ? 1 : elapsedS/durationS;
	}

	public inline function start(from:Float, to:Float, durationS:Float, interp:TinyTweenInterpolation=EaseInOut) {
		this.fromValue = from;
		this.toValue = to;
		this.durationS = durationS;
		this.elapsedS = 0;
		this.interp = interp;
	}

	/** Advance the tween, return TRUE if complete **/
	public inline function update(tmod:Float) : Bool {
		if( isComplete() )
			return false;

		elapsedS = M.fmin( durationS, elapsedS + tmod/fps );
		return true;
	}


	#if deepnightLibsTests
	public static function test() {
		var v = 0.;
		var fps = 10;
		var t = new TinyTween(fps);

		// Linear
		t.start(10, 20, 1, Linear);
		CiAssert.equals( t.curValue, 10 );
		CiAssert.equals( t.isComplete(), false );
		t.update(fps*0.5);
		CiAssert.equals( M.round(t.curValue), 15 );
		CiAssert.equals( t.isComplete(), false );
		t.update(fps*0.5);
		CiAssert.equals( M.round(t.curValue), 20 );
		CiAssert.equals( t.isComplete(), true );

		t.start(10, 20, 1, EaseIn);
		CiAssert.equals( t.curValue, 10 );
		t.update(fps);
		CiAssert.equals( t.curValue, 20 );

		t.start(10, 20, 1, EaseOut);
		CiAssert.equals( t.curValue, 10 );
		t.update(fps);
		CiAssert.equals( t.curValue, 20 );

		t.start(10, 20, 1, EaseInOut);
		CiAssert.equals( t.curValue, 10 );
		t.update(fps);
		CiAssert.equals( t.curValue, 20 );

		t.start(10, 20, 1, BackForth);
		CiAssert.equals( t.curValue, 10 );
		t.update(fps*0.5);
		CiAssert.equals( M.round(t.curValue), 20 );
		t.update(fps*0.5);
		CiAssert.equals( t.curValue, 10 );
	}
	#end
}

