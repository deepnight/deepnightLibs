package dn.script;

@:keep @:rtti
class ScriptPromise {
	static var UID = 0;

	public var uid(default,null) : Int;
	public var completed(default,null) = false;
	var listeners : Null< Array<Void->Void> > = [];

	public inline function new() {
		uid = UID++;
	}

	@:keep public function toString() {
		return 'ScriptPromise#$uid($completed)';
	}

	public function addListener(cb:Void->Void) {
		if( completed )
			cb();
		else if( listeners==null )
			listeners = [cb];
		else if( !listeners.contains(cb) )
			listeners.push(cb);
	}

	public function complete() {
		if( listeners==null || completed )
			return;

		for(cb in listeners)
			cb();

		listeners = null;
	}
}