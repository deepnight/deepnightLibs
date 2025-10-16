package dn.script;


interface IPromisable {
	public var promise(default,null) : Promise;
}


enum PromiseFinalState {
	P_Success;
	P_Fail;
	P_Cancel;
}


@:keep @:rtti
class Promise implements IPromisable {
	static var UID = 0;

	public var name : Null<String>;
	public var uid(default,null) : Int;
	public var completed(default,null) = false;
	public var finalState : Null<PromiseFinalState> = null;
	var listeners : Null< Array<Void->Void> > = [];

	/** For usage comfort, a Promise is also considered as a Promisable object. **/
	@:noCompletion
	public var promise(default,null) : Promise;

	public var onSkip : Null< Void->Void >;


	public inline function new(?name:String) {
		uid = UID++;
		this.name = name;
		promise = this;
	}

	@:keep public function toString() {
		return '${name!=null?name:"Promise"}#$uid '
			+ "(" + ( completed ? "COMPLETED" : listeners!=null ? listeners.length+" listeners" : "No listener" ) +")";
	}

	public function addOnCompleteListener(cb:Void->Void) {
		if( completed )
			cb();
		else if( listeners==null )
			listeners = [cb];
		else if( !listeners.contains(cb) )
			listeners.push(cb);
	}

	public function complete(state:PromiseFinalState=P_Success) {
		if( listeners==null || completed )
			return;

		completed = true;
		finalState = state;
		for(cb in listeners)
			cb();

		listeners = null;
	}


	public function canBeSkipped() : Bool {
		return !completed && onSkip!=null;
	}

	public function tryToSkip() {
		if( !canBeSkipped() )
			return false;

		var cb = onSkip;
		onSkip = null;
		cb();
		return true;
	}
}