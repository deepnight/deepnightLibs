package dn.script;

@:keep @:rtti
class Promise {
	static var UID = 0;

	public var name : Null<String>;
	public var uid(default,null) : Int;
	public var completed(default,null) = false;
	var listeners : Null< Array<Void->Void> > = [];

	public inline function new(?name:String) {
		uid = UID++;
		this.name = name;
	}

	@:keep public function toString() {
		return '${name!=null?name:"Promise"}#$uid '
			+ "(" + ( completed ? "COMPLETED" : listeners!=null ? listeners.length+" listeners" : "No listener" ) +")";
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

		completed = true;
		for(cb in listeners)
			cb();

		listeners = null;
	}
}