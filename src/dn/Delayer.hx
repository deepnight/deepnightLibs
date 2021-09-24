package dn;


private class Task { // Classes are faster

	public var t	: Float;
	public var id	: String;
	public var cb	: Void->Void;

	public inline function new(id, t,cb) { // Inline new classes are faster faster
		this.t = t;
		this.cb = cb;
		this.id = id;
	}

	public inline function toString() return t + " " + cb;
}

class Delayer {
	var delays		: Array<Task>;
	var fps			: Float;

	public function new(fps:Float) { // No need for nullability because no other nullable args
		this.fps = fps;
		delays = new Array();
	}

	public function toString() {
		return "Delayer(timers="+delays.map(function(d) return d.t).join(",")+")";
	}

	public inline function isDestroyed() return delays == null;

	public function destroy() {
		delays = null;
	}

	public function skip() {
		var limit = delays.length+100;
		while( delays.length>0 && limit-->0 ) {
			var d = delays.shift();
			d.cb();
			d.cb = null;//help garbage
		}
	}

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
		return
			if ( a.t < b.t ) -1
			else if ( a.t > b.t ) 1;
			else 0;
	}

	public function addMs(?id:String, cb:Void->Void, ms:Float) {
		delays.push( new Task( id, ms / 1000 * fps, cb) );
		haxe.ds.ArraySort.sort(delays, cmp);
	}

	public function addS(?id:String, cb:Void->Void, sec:Float) {
		delays.push( new Task( id, sec*fps, cb) );
		haxe.ds.ArraySort.sort(delays, cmp);
	}

	public function addF(?id:String, cb:Void->Void, frames:Float) {
		delays.push( new Task( id, frames, cb ) );
		haxe.ds.ArraySort.sort(delays, cmp);
	}

	public inline function hasAny() return !isDestroyed() && delays.length>0;

	public function update(dt:Float) {
		var i = 0;
		while( i<delays.length ) {
			delays[i].t-=dt;
			if( delays[i].t<=0 ) {
				delays[i].cb();
				if( delays[i]==null ) // can happen if cb() called a cancel method
					break;
				delays[i].cb = null;
				delays.shift();
			}
			else
				i++;
		}
	}

	@:noCompletion
	public static function __test() {
		var fps = 30;
		var delayer = new Delayer(fps);
		var done = false;
		delayer.addS("test", function() done = true, 2);
		CiAssert.isTrue( delayer.hasId("test") );
		CiAssert.isFalse( done );

		for(i in 0...fps) delayer.update(1);
		CiAssert.isFalse( done );

		for(i in 0...fps) delayer.update(1);
		CiAssert.isFalse( delayer.hasId("test") );
		CiAssert.isTrue( done );

		delayer.addF("test", function() CiAssert.isFalse(true), 1);
		delayer.cancelById("test");
		delayer.update(1);
	}
}
