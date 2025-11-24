package dn.script;


interface IPromisable {
	public var promise(default,null) : Promise;
}


enum PromiseState {
	P_Pending;
	P_Fulfilled;
	P_Rejected;
}


@:keep @:rtti
class Promise implements IPromisable {
	static var UID = 0;

	public var name : Null<String>;
	public var uid(default,null) : Int;
	public var state(default,null) : PromiseState = P_Pending;
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
		return '${name!=null?name:"Promise"}#$uid<$state> '
			+ ( isFinished()
				? ""
				: "("+(listeners!=null ? listeners.length+" listeners" : "No listener")+")"
			);
	}

	public function addOnCompleteListener(cb:Void->Void) {
		if( isFinished() )
			cb();
		else if( listeners==null )
			listeners = [cb];
		else if( !listeners.contains(cb) )
			listeners.push(cb);
	}

	public function complete(success:Bool) {
		if( listeners==null || isFinished() )
			return this;

		state = success ? P_Fulfilled : P_Rejected;
		for(cb in listeners)
			cb();

		listeners = null;
		return this;
	}


	public inline function isPending() return state==P_Pending;
	public inline function isFinished() return state!=P_Pending;
	public inline function isFulfilled() return state==P_Fulfilled;
	public inline function isRejected() return state==P_Rejected;

	public function canBeSkipped() : Bool {
		return !isFinished() && onSkip!=null;
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