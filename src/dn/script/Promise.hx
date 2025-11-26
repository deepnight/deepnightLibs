package dn.script;


interface IPromisable {
	public var promise(default,null) : Promise;
}


enum PromiseState {
	P_Pending;
	P_Fulfilled;
	P_Rejected;
}

enum abstract PromiseListenerType(Int) to Int {
	var PL_AnyEnd;
	var PL_Fulfill;
	var PL_Reject;
}


@:keep @:rtti
class Promise implements IPromisable {
	static var UID = 0;

	public var name : Null<String>;
	public var uid(default,null) : Int;
	public var state(default,null) : PromiseState = P_Pending;
	var listeners : Null< Map<PromiseListenerType, Array<Void->Void>> > = new Map(); // set to null when finished

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
				: '(${countListeners(PL_AnyEnd)} AnyEnd, ${countListeners(PL_Fulfill)} Fulfill, ${countListeners(PL_Reject)} Reject)'
			);
	}

	inline function countListeners(type:PromiseListenerType) : Int {
		return listeners!=null && listeners.exists(type) ? listeners[type].length : 0;
	}

	function addListener(type:PromiseListenerType, cb:Void->Void) {
		if( isFinished() ) {
			switch type {
				case PL_AnyEnd: cb();
				case PL_Fulfill: if( isFulfilled() ) cb();
				case PL_Reject: if( isRejected() ) cb();
			}
		}
		else if( listeners!=null ) {
			if( !listeners.exists(type) )
				listeners.set(type, [cb]);
			else if( !listeners.get(type).contains(cb) )
				listeners.get(type).push(cb);
		}
	}

	function executeListeners(type:PromiseListenerType) {
		if( listeners!=null && listeners.exists(type) )
			for(cb in listeners.get(type))
				cb();
	}


	public inline function onAnyEnd(cb:Void->Void) {
		addListener(PL_AnyEnd, cb);
		return this;
	}

	public inline function onFulfill(cb:Void->Void) {
		addListener(PL_Fulfill, cb);
		return this;
	}

	public inline function onReject(cb:Void->Void) {
		addListener(PL_Reject, cb);
		return this;
	}

	public inline function fulfill() return end(true);
	public inline function reject() return end(false);

	function end(success:Bool) {
		if( isFinished() )
			return this;

		state = success ? P_Fulfilled : P_Rejected;
		executeListeners(PL_AnyEnd);
		executeListeners( success ? PL_Fulfill : PL_Reject );
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


	#if deepnightLibsTests
	public static function test() {
		var p = new Promise();
		CiAssert.equals( p.isPending(), true );
		CiAssert.equals( p.isFinished(), false );
		CiAssert.equals( p.isFulfilled(), false );
		CiAssert.equals( p.isRejected(), false );

		// Fulfill test
		p.fulfill();
		CiAssert.equals( p.isPending(), false );
		CiAssert.equals( p.isFinished(), true );
		CiAssert.equals( p.isFulfilled(), true );
		CiAssert.equals( p.isRejected(), false );
		p.reject();
		CiAssert.equals( p.state, P_Fulfilled );

		// Reject test
		var p = new Promise();
		p.reject();
		CiAssert.equals( p.isPending(), false );
		CiAssert.equals( p.isFinished(), true );
		CiAssert.equals( p.isFulfilled(), false );
		CiAssert.equals( p.isRejected(), true );
		p.fulfill();
		CiAssert.equals( p.state, P_Rejected );

		// Listeners (fulfill)
		var v = 0;
		var p = new Promise();
		p.onAnyEnd( ()->v++ );
		p.onFulfill( ()->v+=10 );
		p.onReject( ()->v+=100 );
		p.fulfill();
		CiAssert.equals( v, 11 );

		// Listeners (reject)
		var v = 0;
		var p = new Promise();
		p.onAnyEnd( ()->v++ );
		p.onFulfill( ()->v+=10 );
		p.onReject( ()->v+=100 );
		p.reject();
		CiAssert.equals( v, 101 );

		// Listeners after finished
		var v = 0;
		var p = new Promise();
		p.fulfill();
		p.onAnyEnd( ()->v++ );
		p.onFulfill( ()->v+=10 );
		p.onReject( ()->v+=100 );
		CiAssert.equals( v, 11 );
	}
	#end
}
