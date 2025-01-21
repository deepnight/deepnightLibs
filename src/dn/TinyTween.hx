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
	var interp : TinyTweenInterpolation = EaseInOut;
	public var curValue(get,never) : Float;

	public inline function new(fps) {
		this.fps = fps;
		reset();
	}

	/** Reset the tween completely **/
	public inline function reset() {
		fromValue = toValue = 0;
		durationS = elapsedS = -1;
	}

	/** Return TRUE if the tween has any valid value (ie. it's either started, or completed). Reseting makes this function FALSE. **/
	public inline function hasAnyValue() {
		return durationS>0;
	}

	inline function get_curValue() {
		if( !hasAnyValue() )
			return 0;

		if( isComplete() )
			return switch interp {
				case BackForth: fromValue;
				case _: toValue;
			}

		final ratio = switch interp {
			case Linear: elapsedS/durationS;
			case EaseIn: M.bezier4( elapsedS/durationS, 0, 0, 0.5, 1 );
			case EaseOut: M.bezier4( elapsedS/durationS, 0, 0.5, 1, 1 );
			case EaseInOut: M.bezierFull4( elapsedS/durationS,   0, 0.66, 0.66, 1,   0, 0, 1, 1 );
			case BackForth: M.bezier4( elapsedS/durationS, 0, 1+1/3, 1+1/3, 0 );
		}
		return fromValue + ( toValue - fromValue ) * ratio;
	}

	public inline function isComplete() {
		return hasAnyValue() && elapsedS>=durationS;
	}

	public inline function getElapsedRatio() : Float {
		return !hasAnyValue() ? 0 : isComplete() ? 1 : elapsedS/durationS;
	}

	public inline function start(from:Float, to:Float, durationS:Float, interp:TinyTweenInterpolation = EaseInOut) {
		this.fromValue = from;
		this.toValue = to;
		this.durationS = durationS;
		this.elapsedS = 0;
		this.interp = interp;
	}

	public function restartFrom(from:Float) {
		elapsedS = 0;
		fromValue = from;
	}

	/** Advance the tween, return TRUE if the tween is running and curValue changed **/
	public inline function update(tmod:Float) : Bool {
		if( !hasAnyValue() || isComplete() )
			return false;

		elapsedS = M.fmin( durationS, elapsedS + tmod/fps );
		return true;
	}


	#if deepnightLibsTests
	public static function test() {
		var v = 0.;
		var fps = 10;
		var t = new TinyTween(fps);
		CiAssert.equals( t.hasAnyValue(), false );

		// Linear
		t.start(10, 20, 1, Linear);
		CiAssert.equals( t.hasAnyValue(), true );
		CiAssert.equals( t.curValue, 10 );
		CiAssert.equals( t.isComplete(), false );
		t.update(fps*0.5);
		CiAssert.equals( M.round(t.curValue), 15 );
		CiAssert.equals( t.isComplete(), false );
		t.update(fps*0.5);
		CiAssert.equals( M.round(t.curValue), 20 );
		CiAssert.equals( t.isComplete(), true );
		CiAssert.equals( t.hasAnyValue(), true );

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

