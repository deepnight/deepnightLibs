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

	LSTICK_PUSH;
	RSTICK_PUSH;

	LSTICK_X;
	LSTICK_Y;
	LSTICK_UP;
	LSTICK_DOWN;
	LSTICK_LEFT;
	LSTICK_RIGHT;

	RSTICK_X;
	RSTICK_Y;
	RSTICK_UP;
	RSTICK_DOWN;
	RSTICK_LEFT;
	RSTICK_RIGHT;
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
	var actionsEnum(default,null) : Enum<T>;


	var allAccesses : Array<ControllerAccess<T>> = [];
	var bindings : Map<T, Array< InputBinding<T> >> = new Map();
	var destroyed = false;
	var enumMapping : Map<PadButton,Int> = new Map();
	var exclusive : Null<ControllerAccess<T>>;
	var globalDeadZone = 0.1;

	var iconLib : Null<dn.heaps.slib.SpriteLib>;
	var libAlloc = false;
	public var iconForcedSuffix : Null<String> = null;


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

		enumMapping.set(LSTICK_PUSH, pad.config.analogClick);
		enumMapping.set(RSTICK_PUSH, pad.config.ranalogClick);
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

	inline function storeBinding(action:T, b:InputBinding<T>) : Bool {
		if( destroyed )
			return false;
		else {
			if( action!=null && !bindings.exists(action) )
				bindings.set(action, []);
			bindings.get(action).push(b);
			return true;
		}
	}



	public inline function bindPadLStick(xAction:T, yAction:T, invertX=false, invertY=false) {
		var b = InputBinding.createPadStickAxis(this, xAction, 0, true, invertX);
		storeBinding(xAction, b);

		var b = InputBinding.createPadStickAxis(this, yAction, 0, false, invertY);
		storeBinding(yAction, b);
	}

	public inline function bindPadRStick(xAction:T, yAction:T, invertX=false, invertY=false) {
		var b = InputBinding.createPadStickAxis(this, xAction, 1, true, invertX);
		storeBinding(xAction, b);

		var b = InputBinding.createPadStickAxis(this, yAction, 1, false, invertY);
		storeBinding(yAction, b);
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


	function createBindingFromPadButton(action:T, bt:PadButton, invertAxis=false) : InputBinding<T> {
		var binding = switch bt {
			// Simple button
			case A, B, X, Y, RT, RB, LT, LB, START, SELECT,
			  DPAD_UP, DPAD_DOWN, DPAD_LEFT, DPAD_RIGHT,
			  LSTICK_PUSH, RSTICK_PUSH:
				var b = new InputBinding(this,action);
				b.padButton = bt;
				b;

			// Single Left stick direction (up, left etc.)
			case LSTICK_UP: InputBinding.createPadStickDirection(this, action, true, false, -1);
			case LSTICK_DOWN: InputBinding.createPadStickDirection(this, action, true, false, 1);
			case LSTICK_LEFT: InputBinding.createPadStickDirection(this, action, true, true, -1);
			case LSTICK_RIGHT: InputBinding.createPadStickDirection(this, action, true, true, 1);

			// Left stick axis
			case LSTICK_X: InputBinding.createPadStickAxis(this, action, 0, true, invertAxis);
			case LSTICK_Y: InputBinding.createPadStickAxis(this, action, 0, false, invertAxis);

			// Single Right stick direction (up, left etc.)
			case RSTICK_UP: InputBinding.createPadStickDirection(this, action, false, false, -1);
			case RSTICK_DOWN: InputBinding.createPadStickDirection(this, action, false, false, 1);
			case RSTICK_LEFT: InputBinding.createPadStickDirection(this, action, false, true, -1);
			case RSTICK_RIGHT: InputBinding.createPadStickDirection(this, action, false, true, 1);

			// Right stick axis
			case RSTICK_X: InputBinding.createPadStickAxis(this, action, 1, true, invertAxis);
			case RSTICK_Y: InputBinding.createPadStickAxis(this, action, 1, false, invertAxis);
		}

		return binding;
	}


	/**
		Bind an action <T> to a single PadButton or to multiple ones.
		@param action The action enum
		@param button A single PadButton assigned to the action
		@param buttons An array of PadButtons, all assigned to the action. NOTE: only one of them needs to be pressed for the action to be marked as "pressed".
		@param invert If TRUE, the value of the button will be inverted (only for axis, like `LSTICK_X`)
	**/
	public function bindPad(action:T, ?button:PadButton, ?buttons:Array<PadButton>, invertAxis=false) {
		if( destroyed )
			return;

		if( buttons==null && button==null || buttons!=null && button!=null )
			throw "Need exactly 1 button argument";

		if( buttons==null )
			buttons = [button];

		if( !bindings.exists(action) )
			bindings.set(action, []);

		for(bt in buttons) {
			var binding = createBindingFromPadButton(action, bt, invertAxis);
			storeBinding(action, binding);
		}
	}


	/**
		Bind an action to a combination of multiple PadButtons (all of them are REQUIRED)
	**/
	public function bindPadCombo(action:T, combo:Array<PadButton>) {
		if( combo.length==0 )
			return;
		else if( combo.length==1 )
			bindPad(action, combo[0]);
		else {
			var b = createBindingFromPadButton(action, combo[0]);
			for(i in 1...combo.length)
				b.comboBindings.push( createBindingFromPadButton(action, combo[i]) );
			storeBinding(action, b);
		}
	}


	/**
		Bind an action to a single keyboard key or to multiple ones.
		@param action The action enum
		@param key A single key ID (integer) assigned to the action
		@param keys An array of key IDs, all assigned to the action. NOTE: only one of them needs to be pressed for the action to be marked as "pressed".
	**/
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


	public function bindKeyboardCombo(action:T, keys:Array<Int>) {}


	/**
		Change dead-zone ratio for all Pad sticks.
	**/
	public function setGlobalAxisDeadZone(dz:Float) {
		pad.axisDeadZone = globalDeadZone = M.fclamp(dz, 0, 1);
	}




	/**
		Remove existing icons SpriteLib
	**/
	function disposeIconLib() {
		if( iconLib!=null && libAlloc )
			iconLib.destroy();
		iconLib = null;
	}


	/**
		Use a `dn.heaps.slib.SpriteLib` for icons rendering
	**/
	public function useSpriteLibForIcons(slib:dn.heaps.slib.SpriteLib) {
		disposeIconLib();
		iconLib = slib;
		libAlloc = false;
	}


	#if "heaps-aseprite"
	/**
		Use an Aseprite file (as Heaps resource) for icons rendering
	**/
	public function useAsepriteForIcons(ase:aseprite.Aseprite, fps:Int) {
		disposeIconLib();
		iconLib = dn.heaps.assets.Aseprite.convertToSLib(fps, ase);
		libAlloc = true;
	}
	#end

	/**
		Return TRUE if an atlas was provided to render button icons
	**/
	public inline function hasIconsAtlas() : Bool {
		return iconLib!=null;
	}


	/**
		Render an empty "error" Tile when something is wrong with icon rendering
	**/
	@:allow(dn.heaps.input.InputBinding)
	inline function _errorTile() {
		return h2d.Tile.fromColor(0xff0000, 16, 16);
	}

	public function getPadIcon(b:PadButton) : h2d.Tile {
		if( iconLib==null )
			return _errorTile();

		var baseId = Std.string(b);

		// Suffix for vendor specific icons
		var suffix = "";
		if( iconForcedSuffix!=null )
			suffix = iconForcedSuffix;
		else {
			var name = pad.name.toLowerCase();
			if( name.indexOf("xinput")>=0 || name.indexOf("xbox")>=0 )
				suffix = "_xbox";
		}

		if( iconLib.exists(baseId+suffix) )
			return iconLib.getTile(baseId+suffix);
		else if( iconLib.exists(baseId) )
			return iconLib.getTile(baseId);
		else
			return _errorTile();
	}

	public function getKeyboardKey(keyId:Int) : h2d.Flow {
		var f = new h2d.Flow();
		if( !hasIconsAtlas() )
			return f;
	}

}



/**
	Internal binding definition
**/
class InputBinding<T:EnumValue> {
	final analogDownDeadZone = 0.84;

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

	/** For axis, if not zero, this will ignore values of the opposite sign (ie. signLimit=1 ignores negative values) **/
	public var signLimit = 0;

	public var comboBindings : Array<InputBinding<T>> = [];


	public function new(i:Controller<T>, a:T) {
		input = i;
		action = a;
	}

	@:keep
	public function toString() {
		var all = [];
		if( isLStick && padPos==null && signLimit==0 ) all.push( "Pad<LSTICK_" + (isX?"X":"Y") + (invert?"-":"+") + ">" );
		if( isRStick && padPos==null && signLimit==0 ) all.push( "Pad<RSTICK_" + (isX?"X":"Y") + (invert?"-":"+") + ">" );
		if( isLStick && padPos==null && signLimit!=0 ) all.push( "Pad<LSTICK_" + (isX?signLimit<0?"LEFT":"RIGHT":signLimit<0?"UP":"DOWN") + (invert?"-":"+") + ">" );
		if( isRStick && padPos==null && signLimit!=0 ) all.push( "Pad<RSTICK_" + (isX?signLimit<0?"LEFT":"RIGHT":signLimit<0?"UP":"DOWN") + (invert?"-":"+") + ">" );
		if( padNeg!=null ) all.push( getPadButtonAsString(padNeg) );
		if( padPos!=null ) all.push( getPadButtonAsString(padPos) );
		if( padButton!=null ) all.push( getPadButtonAsString(padButton) );
		if( kbNeg>=0 ) all.push( Key.getKeyName(kbNeg) );
		if( kbPos>=0 && kbNeg!=kbPos ) all.push( Key.getKeyName(kbPos) );
		return all.join("/");
	}

	public function getIcon() : h2d.Tile {
		return
			if( !input.hasIconsAtlas() ) input._errorTile();
			else if( isLStick && padPos==null && signLimit!=0 ) {
				// Left stick dir
				signLimit>0 && isX ? input.getPadIcon(LSTICK_RIGHT)
				: signLimit<0 && isX ? input.getPadIcon(LSTICK_LEFT)
				: signLimit<0 && !isX ? input.getPadIcon(LSTICK_UP)
				: input.getPadIcon(LSTICK_DOWN);
			}
			else if( !isLStick && padPos==null && signLimit!=0 ) {
				// Right stick dir
				signLimit>0 && isX ? input.getPadIcon(RSTICK_RIGHT)
				: signLimit<0 && isX ? input.getPadIcon(RSTICK_LEFT)
				: signLimit<0 && !isX ? input.getPadIcon(RSTICK_UP)
				: input.getPadIcon(RSTICK_DOWN);
			}
			else if( padButton!=null ) input.getPadIcon(padButton);
			else input._errorTile();
	}


	/**
		Create a binding for a stick axis (X/Y)
	**/
	public static function createPadStickAxis<E:EnumValue>(c:Controller<E>, action:E, stick:Int, isXaxis:Bool, invert=false) : InputBinding<E> {
		var b = new InputBinding(c, action);
		if( stick==0 )
			b.isLStick = true;
		else
			b.isRStick = true;
		b.isX = isXaxis;
		b.invert = invert;
		return b;
	}


	/**
		Create a binding for a specific stick direction (up, down, left or right)
	**/
	public static inline function createPadStickDirection<E:EnumValue>(c:Controller<E>, action:E, isLStick:Bool, isX:Bool, sign:Int) : InputBinding<E> {
		var b = new InputBinding(c, action);
		if( isLStick )
			b.isLStick = true;
		else
			b.isRStick = true;
		b.isX = isX;
		b.signLimit = sign;
		return b;
	}

	inline function getPadButtonAsString(b:PadButton) {
		return 'Pad<$b>';
	}

	var _tmpBool = false;
	public inline function getValue(pad:hxd.Pad) : Float {
		_tmpBool = false;
		for(cb in comboBindings)
			if( cb.getValue(pad)==0 ) {
				_tmpBool = true;
				break;
			}

		// Combo not active
		if( _tmpBool )
			return 0;
		// Left stick X
		else if( isLStick && padNeg==null && kbNeg<0 && isX && pad.xAxis!=0 )
			return applySignLimit( pad.xAxis * (invert?-1:1) );
		// Left stick Y
		else if( isLStick && padNeg==null && kbNeg<0 && !isX && pad.yAxis!=0 )
			return applySignLimit( pad.yAxis * (invert?-1:1) );
		// Right stick X
		else if( isRStick && padNeg==null && kbNeg<0 && isX && pad.rxAxis!=0 )
			return applySignLimit( pad.rxAxis * (invert?-1:1) );
		// Right stick Y
		else if( isRStick && padNeg==null && kbNeg<0 && !isX && pad.ryAxis!=0 )
			return applySignLimit( pad.ryAxis * (invert?-1:1) );
		// Negative button
		else if( Key.isDown(kbNeg) || pad.isDown( input.getPadButtonId(padNeg) ) )
			return invert ? 1 : -1;
		// Positive button
		else if( Key.isDown(kbPos) || pad.isDown( input.getPadButtonId(padPos) ) )
			return invert ? -1 : 1;
		// Regular button
		else if( padButton!=null && pad.isDown( input.getPadButtonId(padButton) ) )
			return invert ? -1 : 1;
		else
			return 0;
	}

	inline function applySignLimit(v:Float) {
		return signLimit==0
			? v
			: signLimit<0
				? M.fclamp(v, -1, 0)
				: M.fclamp(v, 0, 1);
	}

	public inline function isDown(pad:hxd.Pad) {
		_tmpBool = false;
		for(cb in comboBindings)
			if( !cb.isDown(pad) ) {
				_tmpBool = true;
				break;
			}

		if( _tmpBool )
			return false;
		else
			return
				!isLStick && !isRStick && pad.isDown( input.getPadButtonId(padButton) )
				|| Key.isDown(kbPos) || Key.isDown(kbNeg)
				|| pad.isDown( input.getPadButtonId(padPos) ) || pad.isDown( input.getPadButtonId(padNeg) )
				|| ( isLStick || isRStick ) && signLimit==0 && dn.M.fabs( getValue(pad) ) > analogDownDeadZone
				|| ( isLStick || isRStick ) && signLimit==1 && getValue(pad) > analogDownDeadZone
				|| ( isLStick || isRStick ) && signLimit==-1 && getValue(pad) < -analogDownDeadZone;
	}

	public inline function isPressed(pad:hxd.Pad) {
		_tmpBool = false;
		for(cb in comboBindings)
			if( !cb.isPressed(pad) ) {
				_tmpBool = true;
				break;
			}

		if( _tmpBool )
			return false;
		else
			return pad.isPressed( input.getPadButtonId(padButton) ) || Key.isPressed(kbPos) || Key.isPressed(kbNeg);
	}
}
