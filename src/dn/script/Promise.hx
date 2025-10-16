package dn.script;


interface IPromisable {
	public var promise(default,null) : Promise;
}


enum PromiseFinalState {
	P_Unknown;
	P_Success;
	P_Failed;
	P_Canceled;
}


@:keep @:rtti
class Promise implements IPromisable {
	static var UID = 0;

	public var name : Null<String>;
	public var uid(default,null) : Int;
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
			+ "(" + ( isComplete() ? finalState.getName() : listeners!=null ? listeners.length+" listeners" : "No listener" ) +")";
	}

	public function addOnCompleteListener(cb:Void->Void) {
		if( isComplete() )
			cb();
		else if( listeners==null )
			listeners = [cb];
		else if( !listeners.contains(cb) )
			listeners.push(cb);
	}

	public function complete(state:PromiseFinalState=P_Unknown) {
		if( listeners==null || isComplete() )
			return;

		finalState = state;
		for(cb in listeners)
			cb();

		listeners = null;
	}


	public function isComplete() {
		return finalState!=null;
	}

	public function isSuccess() return finalState==P_Success;
	public function isFailed() return finalState==P_Failed;
	public function isCanceled() return finalState==P_Canceled;

	public function canBeSkipped() : Bool {
		return !isComplete() && onSkip!=null;
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