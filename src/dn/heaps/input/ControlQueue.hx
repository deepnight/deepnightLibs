package dn.heaps.input;

class ControlQueue<T:Int> {
	var ca : ControllerAccess<T>;
	var curTimeS : Float = 0;

	public var queueDurationS(default,null) : Float;
	var allWatches : Array<T> = [];

	var lastFrameDown : Map<Int,Bool> = new Map();
	var holdDurationS : Map<Int,Float> = new Map();
	var lastDownS : Map<Int,Float> = new Map();
	var lastReleaseS : Map<Int,Float> = new Map();
	var upRequired : Map<Int,Bool> = new Map();

	public function new(ca:ControllerAccess<T>, watcheds:Array<T>, queueDurationS=0.3) {
		this.ca = ca;
		this.queueDurationS = queueDurationS;
		this.allWatches = watcheds.copy();
	}

	@:keep public function toString() {
		return allWatches.map( (c:T)->{
			return c+"=>"
				+ (downNowOrRecently(c)?"D":"_")
				+ (releasedNowOrRecently(c)?"R":"_")
				+ "("+M.pretty(getHoldTimeS(c),1)+"s)";
		} ).join(", ");
	}

	public function earlyFrameUpdate(curTimeS:Float) {
		var deltaS = this.curTimeS<=0 ? 0 : curTimeS - this.curTimeS;
		this.curTimeS = curTimeS;

		for(c in allWatches) {
			// Hold duration
			if( ca.isDown(c) ) {
				if( !wasDownInLastFrame(c) )
					holdDurationS.set(c, 0);

				if( !holdDurationS.exists(c) )
					holdDurationS.set(c, deltaS);
				else
					holdDurationS.set(c, holdDurationS.get(c)+deltaS);
			}

			// Down/up/release
			if( upRequired.exists(c) && ca.isDown(c) )
				continue;

			if( upRequired.exists(c) )
				upRequired.remove(c);

			if( ca.isDown(c) )
				lastDownS.set(c, curTimeS);
			else if( !ca.isDown(c) && wasDownInLastFrame(c) )
				lastReleaseS.set(c, curTimeS);

			lastFrameDown.set(c, ca.isDown(c));
		}
	}

	public function emulateInstantDown(c:T) {
		lastDownS.set(c, curTimeS);
	}

	inline function wasDownInLastFrame(c:T) {
		return lastFrameDown.get(c)==true;
	}

	public inline function clear(c:T) {
		lastDownS.remove(c);
		lastReleaseS.remove(c);
		holdDurationS.remove(c);
	}

	public function clearAndRequireKeyUp(c:T) {
		upRequired.set(c,true);
		clear(c);
	}


	public function mostRecentDown() : Null<T> {
		var best : T = null;
		for(c in allWatches) {
			if( downNowOrRecently(c) && ( best==null || getLastDownTime(c)<getLastDownTime(best) ) )
				best = c;
		}
		return best;
	}

	public inline function downNowOrRecently(c:T) {
		return !upRequired.exists(c) && ca.isDown(c)  ||  downRecently(c);
	}

	inline function getLastDownTime(c:T) : Float {
		if( upRequired.exists(c) || !lastDownS.exists(c) )
			return 9999;

		var t = curTimeS - lastDownS.get(c);
		return t<=queueDurationS ? t : 9999;
	}

	inline function downRecently(c:T) {
		return !upRequired.exists(c)  &&  lastDownS.exists(c)  &&  curTimeS - lastDownS.get(c) <= queueDurationS;
	}

	public inline function releasedNowOrRecently(c:T) {
		return !upRequired.exists(c)  &&  downRecently(c)  &&  lastReleaseS.exists(c)  &&  curTimeS - lastReleaseS.get(c) <= queueDurationS;
	}

	public inline function getHoldTimeS(c:T) : Float {
		return !holdDurationS.exists(c) || !ca.isDown(c) && !releasedNowOrRecently(c) ? 0 : holdDurationS.get(c);
	}
}