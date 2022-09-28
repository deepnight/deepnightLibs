package dn.heaps.input;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.Tools;
#else
import hxd.Pad;
import hxd.Key;
#end

enum abstract PadButton(Int) {
	var A;
	var B;
	var X;
	var Y;

	var RT;
	var RB;

	var LT;
	var LB;

	var START;
	var SELECT;

	var DPAD_UP;
	var DPAD_DOWN;
	var DPAD_LEFT;
	var DPAD_RIGHT;

	var LSTICK_PUSH;
	var RSTICK_PUSH;

	var LSTICK_X;
	var LSTICK_Y;
	var LSTICK_UP;
	var LSTICK_DOWN;
	var LSTICK_LEFT;
	var LSTICK_RIGHT;

	var RSTICK_X;
	var RSTICK_Y;
	var RSTICK_UP;
	var RSTICK_DOWN;
	var RSTICK_LEFT;
	var RSTICK_RIGHT;
}


enum abstract ControllerType(Int) {
	var Keyboard;
	var Gamepad;
}



/**
	Controller wrapper for `hxd.Pad` and `hxd.Key` which provides a *much* more convenient binding system, to make keyboard/gamepad usage fully transparent.
	For example, you may bind analog controls (ie. pad left stick) with keyboard keys, or have as many bindings as you want per game action.

	**Example:**
	```haxe
	enum abstract MyGameActions(Int) to Int {
		var MoveX;
		var MoveY;
		var Jump;
		var Attack;
	}
	var ctrl = Controller.createFromAbstractEnum(MyGameActions);
	ctrl.bindKeyboardAsStickXY(MoveX,MoveY, hxd.Key.UP, hxd.Key.LEFT, hxd.Key.DOWN, hxd.Key.RIGHT);
	ctrl.bindKeyboardAsStickXY(MoveX,MoveY, hxd.Key.W, hxd.Key.A, hxd.Key.S, hxd.Key.D);
	ctrl.bindKeyboard(Jump, hxd.Key.SPACE);
	ctrl.bindKeyboard(Attack, [hxd.Key.X, hxd.Key.CTRL, hxd.Key.W, hxd.Key.Z] );

	ctrl.bindPad(MoveLeft, LSTICK_LEFT);
	ctrl.bindPad(MoveRight, LSTICK_RIGHT);
	ctrl.bindPad(Jump, A);
	ctrl.bindPad(Attack, [X, RT, LT]);
	ctrl.bindPadCombo(SuperAttack, [A, B]);

	var access = ctrl.createAccess();
	trace( access.isDown(MoveRight) );
	trace( access.isPressed(Jump) );
	trace( access.isPressed(SuperAttack) );
	trace( access.getAnalogAngleXY(MoveX, MoveY) );

	var debug = access.createDebugger(myParentProcess);
	```
**/
@:allow(dn.heaps.input.ControllerAccess)
class Controller<T:Int> {

	/**
		Create a new Controller instance using an existing **Int based Abstract Enum**.

		```haxe
		enum abstract MyGameActions(Int) to Int {
			var MoveX;
			var MoveY;
			var Jump;
		}
		var c = Controller.createFromAbstractEnum(MyGameActions);
		```
	**/
	public static macro function createFromAbstractEnum(abstractEnumType:haxe.macro.Expr) {
		var allValues = MacroTools.getAbstractEnumValuesForMacros(abstractEnumType);

		// Check enum underlying type
		for(v in allValues)
			switch v.valueExpr.expr {
				case EConst(CInt(_)):
				case _: Context.fatalError("Only abstract enum of Int is supported.", abstractEnumType.pos);
			}

		// Build `0=>"ValueName"` expressions
		var valueInitExprs = [];
		for(v in allValues)
			valueInitExprs.push( macro $e{v.valueExpr} => $v{v.name} );

		// Build Map declaration as `[ 0=>"ValueName", 1=>"ValueName" ]`
		var mapInitExpr : Expr = { pos:Context.currentPos(), expr: EArrayDecl(valueInitExprs) }
		return macro @:privateAccess new dn.heaps.input.Controller( $mapInitExpr );
	}




	#if !macro

	#if heaps_aseprite
	/**
		Embed icons in Aseprite-Base64 format
	 **/
	static var _iconsAsepriteBase64 = dn.MacroTools.embedClassPathFile("assets/deepnightControllerIcons.aseprite");

	/**
		The dictionnary of all the tags present in the Aseprite.
	**/
	public static var ICONS_DICT = dn.heaps.assets.Aseprite.getDictFromFile("assets/deepnightControllerIcons.aseprite");

	/**
		Embed icons SpriteLib
	**/
	public static var ICONS_LIB(get,never) : Null<dn.heaps.slib.SpriteLib>;
		static inline function get_ICONS_LIB() {
			if( _cachedLib==null ) {
				var bytes = haxe.crypto.Base64.decode(_iconsAsepriteBase64);
				var ase = aseprite.Aseprite.fromBytes(bytes);
				_cachedLib = dn.heaps.assets.Aseprite.convertToSLib(60,ase);
			}
			return _cachedLib;
		}
	static var _cachedLib : dn.heaps.slib.SpriteLib;
	#end

	/**
		Default h2d.Font to render keyboard keys icons
	**/
	public static var ICON_FONT(get,never) : h2d.Font;
		static inline function get_ICON_FONT() {
			if( _cachedFont==null )
				_cachedFont = hxd.res.DefaultFont.get();
			return _cachedFont;
		}
	static var _cachedFont : h2d.Font;


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

	/** Resolve an action Int to a human readable String. **/
	var actionNames : Map<Int,String> = new Map();


	var allAccesses : Array<ControllerAccess<T>> = [];
	var bindings : Map<T, Array< InputBinding<T> >> = new Map();
	var destroyed = false;
	var enumMapping : Map<PadButton,Int> = new Map();
	var exclusive : Null<ControllerAccess<T>>;
	var globalDeadZone = 0.1;

	var padButtonNames : Map<Int,String> = new Map();
	var padButtonResolver : Map<String,Int> = new Map();


	/**
		Create a Controller that will bind keyboard or gamepad inputs with "actions" represented by the values of the `actionsEnum` parameter.
	**/
	private function new(actionNames:Map<Int,String>) {
		this.actionNames = actionNames;

		var all = MacroTools.getAbstractEnumValues(PadButton);
		for(v in all) {
			padButtonNames.set(v.value, v.name);
			padButtonResolver.set(v.name, v.value);
		}

		waitForPad();
	}


	public inline function getPadButtonName(b:PadButton) : String {
		return padButtonNames.get(cast b);
	}

	public inline function resolvePadButton(name:String) : Null<PadButton> {
		return cast padButtonResolver.get(name);
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
	public inline function getPadButtonId(bt:Null<PadButton>) {
		return bt!=null && enumMapping.exists(bt) ? enumMapping.get(bt) : -1;
	}

	public var disableRumble : Bool = false;
	public var rumbleMultiplicator : Float = 1;

	/** Rumbles physical controller, if supported **/
	public inline function rumble(strength:Float, seconds:Float) {
		if( pad.index>=0 && !disableRumble)
			pad.rumble(strength*rumbleMultiplicator, seconds);
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
		@param fullAxis If TRUE, then the method will only return TRUE if the action is bound to both positive/negative directions of the axis.
	**/
	public function isBoundToAnalog(act:T, fullAxis:Bool) {
		if( destroyed || !bindings.exists(act) )
			return false;

		for(b in bindings.get(act))
			if( ( b.isLStick || b.isRStick ) && (!fullAxis || b.signLimit==0 ) )
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
		actionNames = null;
		destroyed = true;
	}

	inline function storeBinding(action:T, b:InputBinding<T>) : Bool {
		if( destroyed )
			return false;
		else {
			if( !bindings.exists(action) )
				bindings.set(action, []);
			bindings.get(action).push(b);
			return true;
		}
	}



	public inline function bindPadLStickXY(xAction:T, yAction:T, invertX=false, invertY=false) {
		var b = InputBinding.createPadStickAxis(this, xAction, 0, true, invertX);
		storeBinding(xAction, b);

		var b = InputBinding.createPadStickAxis(this, yAction, 0, false, invertY);
		storeBinding(yAction, b);
	}


	public inline function bindPadLStick4(left:T, right:T, up:T, down:T) {
		bindPad( left, LSTICK_LEFT );
		bindPad( right, LSTICK_RIGHT );
		bindPad( up, LSTICK_UP );
		bindPad( down, LSTICK_DOWN );
	}

	public inline function bindPadRStickXY(xAction:T, yAction:T, invertX=false, invertY=false) {
		var b = InputBinding.createPadStickAxis(this, xAction, 1, true, invertX);
		storeBinding(xAction, b);

		var b = InputBinding.createPadStickAxis(this, yAction, 1, false, invertY);
		storeBinding(yAction, b);
	}


	public inline function bindPadButtonsAsStickXY(xAction:T, yAction:T,  up:PadButton, left:PadButton, down:PadButton, right:PadButton) {
		_bindPadButtonsAsStick(xAction, true, left, right);
		_bindPadButtonsAsStick(yAction, false, up, down);
	}

	public inline function bindPadButtonsAsStickX(action:T, negativeKey:PadButton, positiveKey:PadButton, invert=false) {
		_bindPadButtonsAsStick(action, true, negativeKey, positiveKey, invert);
	}

	public inline function bindPadButtonsAsStickY(action:T, negativeKey:PadButton, positiveKey:PadButton, invert=false) {
		_bindPadButtonsAsStick(action, false, negativeKey, positiveKey, invert);
	}



	public inline function bindKeyboardAsStickXY(xAction:T, yAction:T,  up:Int, left:Int, down:Int, right:Int) {
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
		storeBinding(action, b);
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
		storeBinding(action, b);
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
			var b = InputBinding.createKeyboard(this, action, k);
			bindings.get(action).push(b);
		}
	}



	/**
		Bind an action to a combination of multiple keybaord keys (all of them are REQUIRED)
	**/
	public function bindKeyboardCombo(action:T, combo:Array<Int>) {
		if( combo.length==0 )
			return;
		else if( combo.length==1 )
			bindKeyboard(action, combo[0]);
		else {
			var b = InputBinding.createKeyboard(this, action, combo[0]);
			for(i in 1...combo.length)
				b.comboBindings.push( InputBinding.createKeyboard(this, action, combo[i]) );
			storeBinding(action, b);
		}

	}


	/**
		Change dead-zone ratio for all Pad sticks.
	**/
	public function setGlobalAxisDeadZone(dz:Float) {
		pad.axisDeadZone = globalDeadZone = M.fclamp(dz, 0, 1);
	}



	/**
		Render an empty "error" Tile when something is wrong with icon rendering
	**/
	@:allow(dn.heaps.input.InputBinding)
	inline function _errorTile() {
		return h2d.Tile.fromColor(0xff0000, 16, 16);
	}


	/**
		Return a visual representation (as h2d.Tile) of given gamepad button.
	**/
	public function getPadIconTile(b:PadButton) : h2d.Tile {
		#if heaps_aseprite
			var baseId = getPadButtonName(b);

			// Suffix for vendor specific icons
			var suffix = "";
			var name = pad.name.toLowerCase();
			if( name.indexOf("xinput")>=0 || name.indexOf("xbox")>=0 )
				suffix = "_xbox";

			if( ICONS_LIB.exists(baseId+suffix) )
				return ICONS_LIB.getTile(baseId+suffix);
			else if( ICONS_LIB.exists(baseId) )
				return ICONS_LIB.getTile(baseId);
			else
				return _errorTile();
		#else
			// Placeholder tile
			var c = switch b {
				case A: 0x81d94e;
				case B: 0xf33a1e;
				case X: 0x3d7df5;
				case Y: 0xe9c200;
				case _: 0xb1a6d1;
			}
			return h2d.Tile.fromColor(c, 16,16, 1);
		#end
	}


	/**
		Return the first binding visual representation of given Action. If no binding is found, an empty h2d.Flow is returned.
		@param action The action to lookup
		@param ctrlType Optionally, only show bindings associated with the given controller type
		@param parent  Optional display object to add the icon to.
	**/
	public function getFirstBindindIconFor(action:T, ?ctrlType:ControllerType, filterAxisSign=0, ?parent:h2d.Object) : h2d.Flow {
		if( !bindings.exists(action) || bindings.get(action).length==0 )
			return new h2d.Flow(parent);

		for( b in bindings.get(action) )
			if( ctrlType==null || ctrlType==Keyboard && b.isKeyboard() || ctrlType==Gamepad && b.isGamepad() ) {
				var f = b.getIcon();
				if( parent!=null )
					parent.addChild(f);
				return f;
			}

		return new h2d.Flow(parent);
	}



	/**
		Return the first binding visual representation of given Action.
		@param action The action to lookup
		@param ctrlType Optionally, only show bindings associated with the given controller type
		@param parent  Optional display object to add the icon to.
	**/
	public function getAllBindindIconsFor(action:T, ?ctrlType:ControllerType) : Array<h2d.Flow> {
		if( !bindings.exists(action) || bindings.get(action).length==0 )
			return [];

		var all = [];
		for( b in bindings.get(action) )
			if( ctrlType==null || ctrlType==Keyboard && b.isKeyboard() || ctrlType==Gamepad && b.isGamepad() )
				all.push( b.getIcon() );

		return all;
	}



	/**
		Return the first binding visual representation of given Action.
		@param action The action to lookup
		@param ctrlType Optionally, only show bindings associated with the given controller type
		@param parent  Optional display object to add the icon to.
	**/
	public function getAllBindindTextsFor(action:T, ?ctrlType:ControllerType) : Array<String> {
		if( !bindings.exists(action) || bindings.get(action).length==0 )
			return [];

		var all = [];
		for( b in bindings.get(action) )
			if( ctrlType==null || ctrlType==Keyboard && b.isKeyboard() || ctrlType==Gamepad && b.isGamepad() )
				all.push( b.toString() );

		return all;
	}



	/**
		Return a visual representation (as h2d.Flow) of given gamepad button.
	**/
	public function getPadIcon(b:PadButton, ?parent:h2d.Object) : h2d.Flow {
		var f = new h2d.Flow(parent);
		#if heaps_aseprite
			new h2d.Bitmap( getPadIconTile(b), f );
		#else
			f.backgroundTile = getPadIconTile(b);
			f.paddingHorizontal = 2;
			f.paddingBottom = 2;
			var tf = new h2d.Text(ICON_FONT, f);
			tf.text = getPadButtonName(b);
			tf.textColor = 0x0;
			tf.alpha = 0.5;
		#end

		return f;
	}



	/**
		Return a visual representation (as h2d.Flow) of given keyboard key.
	**/
	public function getKeyboardIcon(keyId:Int, ?parent:h2d.Object) : h2d.Flow {
		var f = new h2d.Flow(parent);
		#if heaps_aseprite
			f.backgroundTile = ICONS_LIB.getTile("keyBg");
			f.borderWidth = 6;
			f.borderHeight = 7;
			f.paddingTop = -1;
			f.paddingHorizontal = 5;
			f.paddingBottom = 6;
			f.minHeight = f.minWidth = 8;
		#else
			f.backgroundTile = h2d.Tile.fromColor(0xbdc8e9);
			f.padding = 3;
			f.paddingTop = 0;
		#end

		#if heaps_aseprite
		inline function _useKeyIcon(id:String) {
			if( !ICONS_LIB.exists(id) )
				new h2d.Bitmap( _errorTile(), f );
			else {
				f.minWidth = 18;
				f.minHeight = 19;
				var i = ICONS_LIB.getBitmap(id, f);
				i.tile.setCenterRatio();
				i.x = Std.int( f.minWidth*0.5 );
				i.y = Std.int( f.minHeight*0.5-1 );
				f.getProperties(i).isAbsolute = true;
			}
		}
		#end

		switch keyId {

			#if heaps_aseprite
			// Special key icons
			case Key.LEFT:  _useKeyIcon("iconLeft");
			case Key.RIGHT:  _useKeyIcon("iconRight");
			case Key.UP:  _useKeyIcon("iconUp");
			case Key.DOWN:  _useKeyIcon("iconDown");
			#end

			case _:
				// Key with text
				var tf = new h2d.Text(hxd.res.DefaultFont.get(), f);
				switch keyId {
					case Key.ESCAPE:
						tf.text = "ESC";

					case Key.DELETE:
						tf.text = "DEL";

					case Key.SPACE:
						tf.text = "SPACE";
						f.paddingLeft+=8;
						f.paddingRight+=8;

					case _:
						tf.text = Key.getKeyName(keyId).toUpperCase();
				}
				tf.textColor = 0x242234;
		}

		return f;
	}

	#end
}


#if !macro

/**
	Internal binding definition
**/
class InputBinding<T:Int> {
	final analogDownDeadZone = 0.84;

	var input : Controller<T>;
	public var action : T;

	public var padButton : Null<PadButton>;
	public var isLStick = false;
	public var isRStick = false;

	public var kbPos = -1;
	public var kbNeg = -1;

	/** Button for negative axis (`padPos` and `padNeg` are tied, both are null or are not null) **/
	public var padPos : Null<PadButton>;
	/** Button for positive axis (`padPos` and `padNeg` are tied, both are null or are not null) **/
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
		if( isLStick && padNeg==null && signLimit==0 ) all.push( "Pad<LSTICK_" + (isX?"X":"Y") + (invert?"-":"+") + ">" );
		if( isRStick && padNeg==null && signLimit==0 ) all.push( "Pad<RSTICK_" + (isX?"X":"Y") + (invert?"-":"+") + ">" );
		if( isLStick && padNeg==null && signLimit!=0 ) all.push( "Pad<LSTICK_" + (isX?signLimit<0?"LEFT":"RIGHT":signLimit<0?"UP":"DOWN") + (invert?"-":"+") + ">" );
		if( isRStick && padNeg==null && signLimit!=0 ) all.push( "Pad<RSTICK_" + (isX?signLimit<0?"LEFT":"RIGHT":signLimit<0?"UP":"DOWN") + (invert?"-":"+") + ">" );
		if( padNeg!=null ) all.push( getPadButtonAsString(padNeg) );
		if( padPos!=null ) all.push( getPadButtonAsString(padPos) );
		if( padButton!=null ) all.push( getPadButtonAsString(padButton) );
		if( kbNeg>=0 ) all.push( Key.getKeyName(kbNeg) );
		if( kbPos>=0 && kbNeg!=kbPos ) all.push( Key.getKeyName(kbPos) );
		return all.join("/");
	}

	inline function getPadButtonAsString(b:PadButton) {
		return 'Pad<$b>';
	}


	/**
		Return the visual representation of this binding
	**/
	public function getIcon() : h2d.Flow {
		var f = new h2d.Flow();
		f.horizontalSpacing = 1;
		f.verticalAlign = Middle;

		if( isLStick && padNeg==null && signLimit!=0 ) {
			// Left stick dir
			signLimit>0 && isX ? input.getPadIcon(LSTICK_RIGHT, f)
			: signLimit<0 && isX ? input.getPadIcon(LSTICK_LEFT, f)
			: signLimit<0 && !isX ? input.getPadIcon(LSTICK_UP, f)
			: input.getPadIcon(LSTICK_DOWN, f);
		}
		if( !isLStick && padNeg==null && signLimit!=0 ) {
			// Right stick dir
			signLimit>0 && isX ? input.getPadIcon(RSTICK_RIGHT, f)
			: signLimit<0 && isX ? input.getPadIcon(RSTICK_LEFT, f)
			: signLimit<0 && !isX ? input.getPadIcon(RSTICK_UP, f)
			: input.getPadIcon(RSTICK_DOWN, f);
		}
		// Left stick axis
		if( isLStick && signLimit==0 ) {
			if( padNeg==null )
				input.getPadIcon(isX ? LSTICK_X : LSTICK_Y, f);
			else {
				input.getPadIcon(padNeg, f);
				input.getPadIcon(padPos, f);
			}
		}
		// Right stick axis
		if( isRStick && signLimit==0 ) {
			if( padNeg==null )
				input.getPadIcon(isX ? RSTICK_X : RSTICK_Y, f);
			else {
				input.getPadIcon(padNeg, f);
				input.getPadIcon(padPos, f);
			}
		}

		if( padButton!=null ) input.getPadIcon(padButton, f);
		if( kbNeg>=0 ) input.getKeyboardIcon(kbNeg, f);
		if( kbPos>=0 && kbPos!=kbNeg ) input.getKeyboardIcon(kbPos, f);

		if( comboBindings.length>0 ) {
			for(b in comboBindings) {
				_addText("+",f);
				f.addChild( b.getIcon() );
			}
		}

		return f;
	}


	inline function _addText(t:String, f:h2d.Flow) {
		var tf = new h2d.Text(Controller.ICON_FONT, f);
		tf.text = t;
		return tf;
	}


	/**
		Return TRUE if this InputBinding is using the Keyboard
	**/
	public inline function isKeyboard() {
		return kbPos>=0 || kbNeg>=0;
	}


	/**
		Return TRUE if this InputBinding is using the Gamepad
	**/
	public inline function isGamepad() {
		return !isKeyboard();
	}


	/**
		Create a binding for a stick axis (X/Y)
	**/
	public static function createPadStickAxis<E:Int>(c:Controller<E>, action:E, stick:Int, isXaxis:Bool, invert=false) : InputBinding<E> {
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
	public static inline function createPadStickDirection<E:Int>(c:Controller<E>, action:E, isLStick:Bool, isX:Bool, sign:Int) : InputBinding<E> {
		var b = new InputBinding(c, action);
		if( isLStick )
			b.isLStick = true;
		else
			b.isRStick = true;
		b.isX = isX;
		b.signLimit = sign;
		return b;
	}


	/**
		Create a basic keyboard key binding
	**/
	public static inline function createKeyboard<E:Int>(c:Controller<E>, action:E, key:Int) : InputBinding<E> {
		var b = new InputBinding(c, action);
		b.kbNeg = b.kbPos = key;
		return b;
	}


	/**
		Return the current value (-1 to 1 usually) of this binding
	**/
	var _comboBreak = false;
	public inline function getValue(pad:hxd.Pad) : Float {
		// Check if a binding in the combo (not including current one) is not down
		_comboBreak = false;
		for(cb in comboBindings)
			if( cb.getValue(pad)==0 ) {
				_comboBreak = true;
				break;
			}
		if( _comboBreak )
			return 0;

		// Left stick X
		if( isLStick && padNeg==null && kbNeg<0 && isX && pad.xAxis!=0 )
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
		else if( Key.isDown(kbNeg) && kbPos!=kbNeg || pad.isDown( input.getPadButtonId(padNeg) ) )
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


	/**
		Return TRUE if this binding is considered as "down"
	**/
	public inline function isDown(pad:hxd.Pad) {
		_comboBreak = false;
		for(cb in comboBindings)
			if( !cb.isDown(pad) ) {
				_comboBreak = true;
				break;
			}

		if( _comboBreak )
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


	/**
		Return TRUE if this binding is considered as "pressed". NOTE: this will only work for buttons and keys, NOT axis movements.
	**/
	var _pressedLocked = false;
	public inline function isPressed(pad:hxd.Pad) {
		// Specific check for combos
		if( comboBindings.length>0 ) {
			// Check if a binding in the combo (not including current one) is not down
			_comboBreak = false;
			for(cb in comboBindings)
				if( !cb.isDown(pad) ) {
					_comboBreak = true;
					break;
				}
			if( _comboBreak ) {
				_pressedLocked = false;
				return false;
			}

			if( _pressedLocked )
				return false;
			else {
				_pressedLocked = pad.isDown( input.getPadButtonId(padButton) ) || Key.isDown(kbPos) || Key.isDown(kbNeg);
				return _pressedLocked;
			}
		}
		else {
			// General case
			return pad.isPressed( input.getPadButtonId(padButton) ) || Key.isPressed(kbPos) || Key.isPressed(kbNeg);
		}
	}

	/**
		Return TRUE if this binding is considered as "released". NOTE: this will only work for buttons and keys, NOT axis movements.
	**/
	public inline function isReleased(pad:hxd.Pad) {
		_comboBreak = false;
		for(cb in comboBindings)
			if( !cb.isReleased(pad) ) {
				_comboBreak = true;
				break;
			}

		if( _comboBreak )
			return false;
		else
			return
				!isLStick && !isRStick && pad.isReleased( input.getPadButtonId(padButton) )
				|| Key.isReleased(kbPos) || Key.isReleased(kbNeg)
				|| pad.isReleased( input.getPadButtonId(padPos) ) || pad.isReleased( input.getPadButtonId(padNeg) )
				|| ( isLStick || isRStick ) && signLimit==0 && dn.M.fabs( getValue(pad) ) < analogDownDeadZone
				|| ( isLStick || isRStick ) && signLimit==1 && getValue(pad) < analogDownDeadZone
				|| ( isLStick || isRStick ) && signLimit==-1 && getValue(pad) > -analogDownDeadZone;
	}
}

#end