package dn;

import dn.TinyTween;

class TinyTweenManager {
	public var fps(default,null) : Int;
	var pool : Array<RecyclableTinyTween> = [];

	public function new(fps, alloc=128) {
		this.fps = fps;
		for(i in 0...alloc)
			pool.push( new RecyclableTinyTween(this) );
	}


	public function start(fromValue:Float, toValue:Float, durationS:Float, interp:TinyTweenInterpolation=EaseInOut, setter:Float->Void) {
		for(t in pool)
			if( !t.isCurrentlyRunning() ) {
				t.reset();
				t.applyValue = setter;
				t.start(fromValue, toValue, durationS, interp);
				return;
			}

		// Out of tweens
		trace("TinyTweenManager: pool exhausted (size="+pool.length+")");
		var t = new RecyclableTinyTween(this);
		pool.push(t);
		t.applyValue = setter;
		t.start(fromValue, toValue, durationS, interp);
	}

	public function update(tmod:Float) {
		for(t in pool)
			t.update(tmod);
	}
}



class RecyclableTinyTween extends TinyTween implements dn.struct.RecyclablePool.Recyclable {
	var manager : TinyTweenManager;

	public function new(manager:TinyTweenManager) {
		super(manager.fps);
		this.manager = manager;
	}

	public function recycle() {
		reset();
		applyValue = _applyNothing;
	}

	override function complete() {
		super.complete();
		recycle();
	}
}
