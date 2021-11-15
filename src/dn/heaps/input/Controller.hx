package dn.heaps.input;

import hxd.Pad;
import hxd.Key;


enum PadButton {
	A;
	B;
	X;
	Y;

	RT;
	RB;

	LT;
	LB;

	START;
	SELECT;

	DPAD_UP;
	DPAD_DOWN;
	DPAD_LEFT;
	DPAD_RIGHT;
}



/**
	Controller wrapper for `hxd.Pad` and `hxd.Key` which provides a *much* more convenient binding system, to make keyboard/gamepad usage fully transparent.

	For example, you may bind analog controls (ie. pad left stick) with keyboard keys, or have as many bindings as you want per game action.

	**Example:**
	```haxe
	enum MyGameActions {
		MoveX;
		MoveY;
		Jump;
		Attack;
	}
	var ctrl = new Controller(MyGameActions);
	ctrl.bindKeyboardAsStick(MoveX,MoveY, hxd.Key.UP, hxd.Key.LEFT, hxd.Key.DOWN, hxd.Key.RIGHT);
	ctrl.bindKeyboardAsStick(MoveX,MoveY, hxd.Key.W, hxd.Key.A, hxd.Key.S, hxd.Key.D);
	ctrl.bindKeyboard(Jump, hxd.Key.SPACE);
	ctrl.bindKeyboard(Attack, [hxd.Key.X, hxd.Key.CTRL, hxd.Key.W, hxd.Key.Z] );

	ctrl.bindPadLStick(MoveX,MoveY);
	ctrl.bindPadButtonsAsStick(MoveX,MoveY, DPAD_UP, DPAD_LEFT, DPAD_DOWN, DPAD_RIGHT);
	ctrl.bindPad(Jump, A);
	ctrl.bindPad(Attack, [X,RT,LT]);

	var access = ctrl.createAccess();
	trace( access.isPressed(Jump) );
	trace( access.getAnalogAngle(MoveX,MoveY) );
	trace( access.isPositive(MoveY) );

	var debug = access.createDebugger(myParentProcess);
	```
**/
@:allow(dn.heaps.input.ControllerAccess)
class Controller<T:EnumValue> {
	/**
		Actual `hxd.Pad` behind
	**/
	public var pad : hxd.Pad;

	/**
		This callback is fired:
		- when game pad is ready,
		- when it reconnects after disconnection,
		- immediately if the pad was already connected when callback was set.
	**/
	public var onConnect(default,set) : Void->Void;

	/**
		This callback is fired when the pad is disconnected.
	**/
	public var onDisconnect : Void->Void;

	/**
		Enum type associated with this Controller
	**/
	public var actionsEnum(default,null) : Enum<T>;


	var allAccesses : Array<ControllerAccess<T>> = [];
	var bindings : Map<T, Array< InputBinding<T> >> = new Map();
	var destroyed = false;
	var enumMapping : Map<PadButton,Int> = new Map();
	var exclusive : Null<ControllerAccess<T>>;
	var globalDeadZone = 0.1;


	/**
		Create a Controller that will bind keyboard or gamepad inputs with "actions" represented by the values of the `actionsEnum` parameter.
	**/
	public function new(actionsEnum:Enum<T>) {
		this.actionsEnum = actionsEnum;
		waitForPad();
	}



	@:keep public function toString() {
		return "Controller"
			+ "(access="+allAccesses.length +", "+ ( pad==null || pad.index<0 ? '<NoPad>' : '"'+pad.name+'"#'+pad.index ) + ")";
	}




	public function releaseExclusivity() {
		exclusive = null;
	}

	public function makeExclusive(ia:ControllerAccess<T>) {
		exclusive = ia;
	}

	/**
		Create a `ControllerAccess` instance for this Controller.
	**/
	public function createAccess() : ControllerAccess<T> {
		var ia = new ControllerAccess(this);
		allAccesses.push(ia);
		return ia;
	}


	function unregisterAccess(ia:ControllerAccess<T>) {
		allAccesses.remove(ia);
		if( exclusive==ia )
			releaseExclusivity();
	}


	function waitForPad() {
		pad = hxd.Pad.createDummy();
		updateEnumMapping();
		hxd.Pad.wait( p->{
			_onPadConnected( p );
		});
	}


	public inline function isPadConnected() {
		return !destroyed && pad!=null && pad.connected;
	}

	function updateEnumMapping() {
		enumMapping = new Map();

		enumMapping.set(A, pad.config.A);
		enumMapping.set(B, pad.config.B);
		enumMapping.set(X, pad.config.X);
		enumMapping.set(Y, pad.config.Y);

		enumMapping.set(LT, pad.config.LT);
		enumMapping.set(LB, pad.config.LB);

		enumMapping.set(RT, pad.config.RT);
		enumMapping.set(RB, pad.config.RB);

		enumMapping.set(START, pad.config.start);
		enumMapping.set(SELECT, pad.config.back);

		enumMapping.set(DPAD_UP, pad.config.dpadUp);
		enumMapping.set(DPAD_DOWN, pad.config.dpadDown);
		enumMapping.set(DPAD_LEFT, pad.config.dpadLeft);
		enumMapping.set(DPAD_RIGHT, pad.config.dpadRight);
	}


	@:noCompletion
	public inline function getPadButtonId(bt:PadButton) {
		return bt!=null && enumMapping.exists(bt) ? enumMapping.get(bt) : -1;
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
		pad.axisDeadZone = globalDeadZone;
		updateEnumMapping();
		pad.onDisconnect = _onPadDisconnected;

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



	/**
		Return TRUE if given Enum is bound to at least one analog control.
	**/
	public function isBoundToAnalog(act:T) {
		if( destroyed || !bindings.exists(act) )
			return false;

		for(b in bindings.get(act))
			if( b.isLStick || b.isRStick )
				return true;
		return false;
	}


	public function dispose() {
		for(a in allAccesses.copy())
			a.dispose();
		allAccesses = null;

		exclusive = null;
		pad = null;
		enumMapping = null;
		bindings = null;
		actionsEnum = null;
		destroyed = true;
	}


	function _bindPadStick(action:T, stick:Int, isXaxis:Bool, invert=false) {
		if( destroyed )
			return;

		if( !bindings.exists(action) )
			bindings.set(action, []);

		var b = new InputBinding(this,action);
		bindings.get(action).push(b);
		if( stick==0 )
			b.isLStick = true;
		else
			b.isRStick = true;
		b.isX = isXaxis;
		b.invert = invert;
	}

	public inline function bindPadLStick(xAction:T, yAction:T) {
		_bindPadStick(xAction, 0, true);
		_bindPadStick(yAction, 0, false);
	}

	public inline function bindPadRStick(xAction:T, yAction:T) {
		_bindPadStick(xAction, 1, true);
		_bindPadStick(yAction, 1, false);
	}

	public inline function bindPadLStickX(action:T) {
		_bindPadStick(action, 0, true);
	}

	public inline function bindPadLStickY(action:T) {
		_bindPadStick(action, 0, false);
	}


	public inline function bindPadButtonsAsStick(xAction:T, yAction:T,  up:PadButton, left:PadButton, down:PadButton, right:PadButton) {
		_bindPadButtonsAsStick(xAction, true, left, right);
		_bindPadButtonsAsStick(yAction, false, up, down);
	}

	public inline function bindPadButtonsAsStickX(action:T, negativeKey:PadButton, positiveKey:PadButton, invert=false) {
		_bindPadButtonsAsStick(action, true, negativeKey, positiveKey, invert);
	}

	public inline function bindPadButtonsAsStickY(action:T, negativeKey:PadButton, positiveKey:PadButton, invert=false) {
		_bindPadButtonsAsStick(action, false, negativeKey, positiveKey, invert);
	}



	public inline function bindKeyboardAsStick(xAction:T, yAction:T,  up:Int, left:Int, down:Int, right:Int) {
		_bindKeyboardAsStick(xAction, true, left, right);
		_bindKeyboardAsStick(yAction, false, up, down);
	}


	public inline function bindKeyboardAsStickX(action:T, negativeKey:Int, positiveKey:Int, invert=false) {
		_bindKeyboardAsStick(action, true, negativeKey, positiveKey, invert);
	}

	public inline function bindKeyboardAsStickY(action:T, negativeKey:Int, positiveKey:Int, invert=false) {
		_bindKeyboardAsStick(action, false, negativeKey, positiveKey, invert);
	}

	function _bindKeyboardAsStick(action:T, isXaxis:Bool, negativeKey:Int, positiveKey:Int, invert=false) {
		if( destroyed )
			return;

		if( !bindings.exists(action) )
			bindings.set(action, []);
		var b = new InputBinding(this,action);
		bindings.get(action).push(b);
		b.isX = isXaxis;
		b.kbNeg = negativeKey;
		b.kbPos = positiveKey;
		b.invert = invert;
	}


	function _bindPadButtonsAsStick(action:T, isXaxis:Bool, negativeKey:PadButton, positiveKey:PadButton, invert=false) {
		if( destroyed )
			return;

		if( !bindings.exists(action) )
			bindings.set(action, []);
		var b = new InputBinding(this,action);
		bindings.get(action).push(b);
		b.isLStick = true;
		b.isX = isXaxis;
		b.padNeg = negativeKey;
		b.padPos = positiveKey;
		b.invert = invert;
	}



	public function bindPad(action:T, ?button:PadButton, ?buttons:Array<PadButton>) {
		if( destroyed )
			return;

		if( buttons==null && button==null || buttons!=null && button!=null )
			throw "Need exactly 1 button argument";

		if( buttons==null )
			buttons = [button];

		if( !bindings.exists(action) )
			bindings.set(action, []);

		for(bt in buttons) {
			var b = new InputBinding(this,action);
			b.padButton = bt;
			bindings.get(action).push(b);
		}
	}


	public function bindKeyboard(action:T, ?key:Int, ?keys:Array<Int>) {
		if( destroyed )
			return;

		if( keys==null && key==null || keys!=null && key!=null )
			throw "Need exactly 1 key argument";

		if( keys==null )
			keys = [key];

		if( !bindings.exists(action) )
			bindings.set(action, []);

		for(k in keys) {
			var b = new InputBinding(this,action);
			b.kbNeg = k;
			b.kbPos = k;
			bindings.get(action).push(b);
		}
	}


	/**
		Change dead-zone ratio for all Pad sticks.
	**/
	public function setGlobalAxisDeadZone(dz:Float) {
		pad.axisDeadZone = globalDeadZone = M.fclamp(dz, 0, 1);
	}
}



/**
	Internal binding definition
**/
class InputBinding<T:EnumValue> {
	var input : Controller<T>;
	public var action : T;

	public var padButton : Null<PadButton>;
	public var isLStick = false;
	public var isRStick = false;

	public var kbPos = -1;
	public var kbNeg = -1;

	public var padPos : Null<PadButton>;
	public var padNeg : Null<PadButton>;

	public var invert = false;
	public var isX = false;
	var analogDownDeadZone = 0.84;


	public function new(i:Controller<T>, a:T) {
		input = i;
		action = a;
	}

	@:keep
	public function toString() {
		var all = [];
		if( isLStick && padPos==null ) all.push( "LSTICK" + (isX?"_X":"_Y") + (invert?"-":"+") );
		if( isRStick && padPos==null ) all.push("RSTICK");
		if( padNeg!=null ) all.push( Std.string(padNeg) );
		if( padPos!=null ) all.push( Std.string(padPos) );
		if( padButton!=null ) all.push( Std.string(padButton) );
		if( kbNeg>=0 ) all.push( Key.getKeyName(kbNeg) );
		if( kbPos>=0 && kbNeg!=kbPos ) all.push( Key.getKeyName(kbPos) );
		return all.join("/");
	}

	public inline function getValue(pad:hxd.Pad) : Float {
		if( isLStick && padNeg==null && kbNeg<0 && isX && pad.xAxis!=0 )
			return pad.xAxis * (invert?-1:1);
		else if( isLStick && padNeg==null && kbNeg<0 && !isX && pad.yAxis!=0 )
			return pad.yAxis * (invert?-1:1);
		else if( isRStick && padNeg==null && kbNeg<0 && isX && pad.rxAxis!=0 )
			return pad.rxAxis * (invert?-1:1);
		else if( isRStick && padNeg==null && kbNeg<0 && !isX && pad.ryAxis!=0 )
			return pad.ryAxis * (invert?-1:1);
		else if( Key.isDown(kbNeg) || pad.isDown( input.getPadButtonId(padNeg) ) )
			return invert ? 1 : -1;
		else if( Key.isDown(kbPos) || pad.isDown( input.getPadButtonId(padPos) ) )
			return invert ? -1 : 1;
		else
			return 0;
	}

	public inline function isDown(pad:hxd.Pad) {
		return
			!isLStick && pad.isDown( input.getPadButtonId(padButton) )
			|| Key.isDown(kbPos) || Key.isDown(kbNeg)
			|| pad.isDown( input.getPadButtonId(padPos) ) || pad.isDown( input.getPadButtonId(padNeg) )
			|| isLStick && dn.M.fabs( getValue(pad) ) > analogDownDeadZone;
	}

	public inline function isPressed(pad:hxd.Pad) {
		return pad.isPressed( input.getPadButtonId(padButton) ) || Key.isPressed(kbPos) || Key.isPressed(kbNeg);
	}
}
