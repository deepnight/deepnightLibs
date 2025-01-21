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
	var fromValue = 0.;
	var toValue = 0.;
	var elapsedS = 0.;
	var durationS = 0.;
	var interp : TinyTweenInterpolation = Linear;
	public var curValue(get,never) : Float;

	public inline function new(fps) {
		this.fps = fps;
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
			case EaseInOut: M.bezier4( elapsedS/durationS, 0, 0, 1, 1 );
			case BackForth: M.bezier4( elapsedS/durationS, 0, 1.33, 1.33, 0 );
		}
		return fromValue + ( toValue - fromValue ) * ratio;
	}

	public inline function isComplete() {
		return elapsedS>=durationS;
	}

	public inline function getElapsedRatio() : Float {
		return isComplete() ? 1 : elapsedS/durationS;
	}

	public inline function clear() {
		durationS = elapsedS = 0;
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
}