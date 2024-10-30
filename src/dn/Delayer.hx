package dn;


private class Task { // Classes are faster
	public var frames : Float;
	public var id : String;
	public var cb : Void->Void;

	public inline function new(id, frames,cb) { // Inline new classes are faster faster
		this.frames = frames;
		this.cb = cb;
		this.id = id;
	}

	@:keep public function toString() return frames+"f "+cb;
}

class Delayer {
	var delays : Array<Task> = [];
	var fps : Float;

	public function new(fps:Float) {
		this.fps = fps;
	}

	@:keep public function toString() {
		return "Delayer(timers=" + delays.map( d->M.pretty(d.frames/fps,1)+"s" ).join(",") + ")";
	}

	public inline function isDestroyed() return delays == null;

	@:deprecated("Use dispose() instead") @:noCompletion
	public inline function destroy() {
		dispose();
	}

	public function dispose() {
		delays = null;
	}

	// public function skip() {
	// 	var limit = delays.length+100;
	// 	while( delays.length>0 && limit-->0 ) {
	// 		var d = delays.shift();
	// 		d.cb();
	// 		d.cb = null;
	// 	}
	// }

	public function cancelEverything() {
		delays = [];
	}

	public function hasId(id:String) {
		for(e in delays)
			if( e.id==id )
				return true;
		return false;
	}

	public function cancelById(id:String) {
		var i = 0;
		while( i<delays.length )
			if( delays[i].id==id )
				delays.splice(i,1);
			else
				i++;
	}

	public function runImmediately(id:String) {
		var i = 0;
		while( i<delays.length )
			if( delays[i].id==id ) {
				var cb = delays[i].cb;
				delays.splice(i,1);
				cb();
			}
			else
				i++;
	}

	inline function cmp(a:Task, b:Task) {
		return a.frames < b.frames ? -1
			: a.frames > b.frames ? 1
			: 0;
	}

	public function addMs(?id:String, cb:Void->Void, ms:Float) {
		if( ms<=0 )
			cb();
		else {
			delays.push( new Task( id, fps*ms/1000, cb) );
			haxe.ds.ArraySort.sort(delays, cmp);
		}
	}

	public function addS(?id:String, cb:Void->Void, sec:Float) {
		if( sec<=0 )
			cb();
		else {
			delays.push( new Task( id, fps*sec, cb) );
			haxe.ds.ArraySort.sort(delays, cmp);
		}
	}

	public function addF(?id:String, cb:Void->Void, frames:Float) {
		if( frames<=0 )
			cb();
		else {
			delays.push( new Task( id, frames, cb ) );
			haxe.ds.ArraySort.sort(delays, cmp);
		}
	}

	public inline function nextFrame(cb:Void->Void) {
		addF(cb, 0.000001);
	}

	public inline function hasAny() return !isDestroyed() && delays.length>0;

	public function update(tmod:Float) {
		var i = 0;
		while( i<delays.length ) {
			delays[i].frames -= tmod;
			if( delays[i].frames <= 0 ) {
				delays[i].cb();
				if( delays==null || delays[i]==null ) // can happen if cb() called a cancel or dispose method
					break;
				delays[i].cb = null;
				delays.shift();
			}
			else
				i++;
		}
	}

	#if deepnightLibsTests
	public static function test() {
		var fps = 30;
		var delayer = new Delayer(fps);

		// Test a 2 sec delay
		var done = false;
		delayer.addS("test", ()->done=true, 2);
		CiAssert.isTrue( delayer.hasId("test") );
		CiAssert.isFalse( done );

		for(i in 0...fps) delayer.update(1); // 1s
		CiAssert.isFalse( done );

		for(i in 0...fps) delayer.update(1); // 2s
		CiAssert.isTrue( done );
		CiAssert.isFalse( delayer.hasId("test") );

		// Cancelling
		delayer.addF("test", ()->throw "exception", 1);
		delayer.cancelById("test");
		delayer.update(1);

		// Next frame
		var done = false;
		delayer.nextFrame( ()->done=true );
		CiAssert.isFalse( done );
		delayer.update(1);
		CiAssert.isTrue( done );
	}
	#end
}
