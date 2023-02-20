package dn.heaps.input;

class ControlQueue<T:Int> {
	var ca : ControllerAccess<T>;
	var curTimeS : Float;

	var allWatches : Array<T> = [];
	var initialDownS : Map<Int,Float> = new Map();
	var lastDownS : Map<Int,Float> = new Map();
	var lastReleaseS : Map<Int,Float> = new Map();
	var maxQueueTimeS : Float;
	var upRequired : Map<Int,Bool> = new Map();

	public function new(ca:ControllerAccess<T>, watcheds:Array<T>, maxQueueTimeS=0.3) {
		this.ca = ca;
		this.maxQueueTimeS = maxQueueTimeS;
		this.allWatches = watcheds.copy();
	}

	@:keep public function toString() {
		return allWatches.map( (c:T)->{
			return c+"=>"
				+ M.pretty(getHoldTimeS(c),1)+"s"
				+ (downNowOrRecently(c)?"D":"_")
				+ (releasedNowOrRecently(c)?"R":"_");
				// + (heldDownNowOrRecentlyFor(c,0.3)?"H":"_");
		} ).join(", ");
	}

	public function earlyFrameUpdate(curTimeS:Float) {
		this.curTimeS = curTimeS;

		for(c in allWatches) {
			if( upRequired.exists(c) && ca.isDown(c) )
				continue;

			if( upRequired.exists(c) )
				upRequired.remove(c);

			if( !ca.isDown(c) && initialDownS.exists(c) )
				initialDownS.remove(c);

			if( ca.isDown(c) && !initialDownS.exists(c) )
				initialDownS.set(c, curTimeS);

			if( ca.isDown(c) )
				lastDownS.set(c, curTimeS);
			else if( !ca.isDown(c) && downNowOrRecently(c) && !releasedNowOrRecently(c) )
				lastReleaseS.set(c, curTimeS);
		}
	}

	public inline function unqueue(c:T) {
		lastDownS.remove(c);
		lastReleaseS.remove(c);
	}

	public function requireKeyUp(c:T) {
		upRequired.set(c,true);
		unqueue(c);
	}

	public function downNowOrRecently(c:T) {
		return ca.isDown(c)  ||  downRecently(c);
	}

	function downRecently(c:T) {
		return !upRequired.exists(c)  &&  lastDownS.exists(c)  &&  curTimeS - lastDownS.get(c) <= maxQueueTimeS;
	}

	public function releasedNowOrRecently(c:T) {
		return !upRequired.exists(c)  &&  lastReleaseS.exists(c)  &&  curTimeS - lastReleaseS.get(c) <= maxQueueTimeS;
	}

	public function getHoldTimeS(c:T) : Float {
		return initialDownS.exists(c) ? curTimeS-initialDownS.get(c) : 0;
	}

	// public function heldDownNowOrRecentlyFor(c:T, seconds:Float) {
		// return getHoldTimeS(c)==0
		// if( !downNowOrRecently(c) )
		// 	return false;
		// else
		// 	return lastDownS.get(c) - initialDownS.get(c);
	// }
}