package dn.heaps.input;

import hxd.Pad;
import hxd.Key;

/**
	Controller wrapper for `hxd.Pad` and `hxd.Key` which provides a *much* more convenient binding system, to make keyboard/gamepad usage fully transparent.

	**Usage:**
	```haxe
	enum MyGameActions {
		MoveX;
		Jump;
		Attack;
	}
	var gi = new GameInput(MyGameActions);
	gi.onConnect( padConfig->{
		gi.bindKeyboardToAnalogX(MoveX, hxd.Key.LEFT, hxd.Key.RIGHT);
		gi.bindPadButtonsToAnalogX(MoveX, padConfig.dpadLeft, padConfig.dpadRight);
	});
	trace( gi.getAnalogDist(MoveX) ); // 0-1
	trace( gi.isDown(Attack) );
	trace( gi.isPressed(Jump) );
	```

**/
@:allow(dn.heaps.input.GameInputAccess)
class GameInputManager<T:EnumValue> {
	/**
		Actual `hxd.Pad` behind
	**/
	public var pad : hxd.Pad;

	/**
		Current `hxd.Pad` buttons config, or null if not connected
	**/
	public var cfg(get,never) : Null<PadConfig>;
		inline function get_cfg() return isConnected() ? pad.config : null;

	/**
		This callback is fired when pad is ready, or when it reconnects after disconnection.

		**Note 1:** all your GameInput bindings should only be done in this callback.

		**Note 2:** the event might be fired immediately if the pad is *already* connected when callback is set.

		@param PadConfig This arg is the same as `this.cfg` field of this class and is only provided for convenience.
	**/
	public var onConnect(default,set) : Void->Void;

	/**
		This callback is fired when the pad is disconnected.
	**/
	public var onDisconnect : Void->Void;

	/**
		Enum type associated with this GameInput
	**/
	public var actionsEnum(default,null) : Enum<T>;


	var allAccesses : Array<GameInputAccess<T>> = [];
	var bindings : Map<T, Array< InputBinding<T> >> = new Map();
	var destroyed = false;
	var doBindings : (manager:GameInputManager<T>, cfg:PadConfig)->Void;


	public function new(actionsEnum:Enum<T>, doBindings:(manager:GameInputManager<T>, cfg:PadConfig)->Void) {
		this.actionsEnum = actionsEnum;
		this.doBindings = doBindings;
		waitForPad();
	}


	@:keep public function toString() {
		return "GameInputManager"
			+ "(access="+allAccesses.length +", "+ ( pad==null || pad.index<0 ? '<NoPad>' : '"'+pad.name+'"#'+pad.index ) + ")";
			// + "["+allAccesses.length+" access]";
	}


	public function createAccess() : GameInputAccess<T> {
		var ia = new GameInputAccess(this);
		allAccesses.push(ia);
		return ia;
	}

	function unregisterAccess(ia:GameInputAccess<T>) {
		allAccesses.remove(ia);
	}

	function waitForPad() {
		pad = hxd.Pad.createDummy();
		removeBindings();
		doBindings(this, hxd.Pad.DEFAULT_CONFIG);
		hxd.Pad.wait( p->{
			_onPadConnected( p );
		});
	}


	/** Return TRUE if current Pad is connected **/
	public inline function isConnected() {
		return !destroyed && pad!=null && pad.connected;
	}


	inline function set_onConnect(cb) {
		onConnect = cb;
		if( pad.connected )
			_onPadConnected(pad);
		return onConnect;
	}


	function _onPadDisconnected() {
		if( onDisconnect!=null )
			onDisconnect();
		waitForPad();
	}


	function _onPadConnected(p:hxd.Pad) {
		pad = p;
		pad.onDisconnect = _onPadDisconnected;

		removeBindings();
		doBindings(this, pad.config);

		if( onConnect!=null )
			onConnect();
	}


	/**
		Remove existing bindings.
		@param action If omitted, all existing bindings are removed. Otherwise, only given Enum action is unbound.
	**/
	public function removeBindings(?action:T) {
		if( action==null )
			bindings = new Map();
		else
			bindings.remove(action);
	}


	public function dispose() {
		for(a in allAccesses.copy())
			a.dispose();
		allAccesses = null;

		pad = null;
		bindings = null;
		actionsEnum = null;
		destroyed = true;
	}



	public inline function bindPadButtonsToAnalog(xAction:T, yAction:T,  up:Int, left:Int, down:Int, right:Int) {
		_bindPadButtonsToAnalog(xAction, true, left, right);
		_bindPadButtonsToAnalog(yAction, false, up, down);
	}

	public inline function bindPadButtonsToAnalogX(v:T, negative:Int, positive:Int, invert=false) {
		_bindPadButtonsToAnalog(v, true, negative, positive, invert);
	}

	public inline function bindPadButtonsToAnalogY(v:T, negative:Int, positive:Int, invert=false) {
		_bindPadButtonsToAnalog(v, false, negative, positive, invert);
	}



	public inline function bindKeyboardToAnalog(xAction:T, yAction:T,  up:Int, left:Int, down:Int, right:Int) {
		_bindKeyboardToAnalog(xAction, true, left, right);
		_bindKeyboardToAnalog(yAction, false, up, down);
	}


	public inline function bindKeyboardToAnalogX(v:T, negative:Int, positive:Int, invert=false) {
		_bindKeyboardToAnalog(v, true, negative, positive, invert);
	}

	public inline function bindKeyboardToAnalogY(v:T, negative:Int, positive:Int, invert=false) {
		_bindKeyboardToAnalog(v, false, negative, positive, invert);
	}


	/**
		Return TRUE if given Enum is bound to at least one analog control.
	**/
	public function isBoundToAnalog(act:T) {
		if( destroyed || !bindings.exists(act) )
			return false;

		for(b in bindings.get(act))
			if( b.isAnalog )
				return true;
		return false;
	}


	function _bindKeyboardToAnalog(v:T, isXaxis:Bool, negative:Int, positive:Int, invert=false) {
		if( destroyed )
			return;

		if( !bindings.exists(v) )
			bindings.set(v, []);
		var b = new InputBinding(v);
		bindings.get(v).push(b);
		b.isAnalog = true;
		b.isX = isXaxis;
		b.kbNeg = negative;
		b.kbPos = positive;
		b.invert = invert;
	}


	function _bindPadButtonsToAnalog(v:T, isXaxis:Bool, negative:Int, positive:Int, invert=false) {
		if( destroyed )
			return;

		if( !bindings.exists(v) )
			bindings.set(v, []);
		var b = new InputBinding(v);
		bindings.get(v).push(b);
		b.isAnalog = true;
		b.isX = isXaxis;
		b.padNeg = negative;
		b.padPos = positive;
		b.invert = invert;
	}



	public function bindPadToDigital(v:T, ?button:Int, ?buttons:Array<Int>) {
		if( destroyed )
			return;

		if( buttons==null && button==null || buttons!=null && button!=null )
			throw "Need exactly 1 button argument";

		if( buttons==null )
			buttons = [button];

		if( !bindings.exists(v) )
			bindings.set(v, []);

		for(bt in buttons) {
			var b = new InputBinding(v);
			b.padButton = bt;
			bindings.get(v).push(b);
		}
	}


	public function bindKeyboardToDigital(v:T, ?key:Int, ?keys:Array<Int>) {
		if( destroyed )
			return;

		if( keys==null && key==null || keys!=null && key!=null )
			throw "Need exactly 1 key argument";

		if( keys==null )
			keys = [key];

		if( !bindings.exists(v) )
			bindings.set(v, []);

		for(k in keys) {
			var b = new InputBinding(v);
			b.kbNeg = k;
			b.kbPos = k;
			bindings.get(v).push(b);
		}
	}
}



/**
	Internal binding definition
**/
class InputBinding<T> {
	public var action : T;

	public var padButton = -1;
	public var isAnalog = false;

	public var kbPos = -1;
	public var kbNeg = -1;

	public var padPos = -1;
	public var padNeg = -1;

	public var invert = false;
	public var isX = false;
	var analogDownDeadZone = 0.84;


	public function new(a:T) {
		action = a;
	}

	public inline function getValue(pad:hxd.Pad) : Float {
		if( isAnalog && isX && pad.xAxis!=0 )
			return pad.xAxis * (invert?-1:1);
		else if( isAnalog && !isX && pad.yAxis!=0 )
			return pad.yAxis * (invert?-1:1);
		else if( Key.isDown(kbNeg) || pad.isDown(padNeg) )
			return invert ? 1 : -1;
		else if( Key.isDown(kbPos) || pad.isDown(padPos) )
			return invert ? -1 : 1;
		else
			return 0;
	}

	public inline function isDown(pad:hxd.Pad) {
		return
			!isAnalog && pad.isDown(padButton)
			|| Key.isDown(kbPos) || Key.isDown(kbNeg)
			|| pad.isDown(padPos) || pad.isDown(padNeg)
			|| isAnalog && dn.M.fabs(getValue(pad)) > analogDownDeadZone;
	}

	public inline function isPressed(pad:hxd.Pad) {
		return pad.isPressed(padButton) || Key.isPressed(kbPos) || Key.isPressed(kbNeg);
	}
}
