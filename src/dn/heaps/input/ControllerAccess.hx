package dn.heaps.input;

import hxd.Pad;
import hxd.Key;
import dn.heaps.input.Controller;


/**
	This class should only be created through `Controller.createAccess()`.
**/
class ControllerAccess<T:Int> {
	public var controller(default,null) : Controller<T>;

	public var disableRumble(get,set) : Bool;
	public var rumbleMultiplicator(get,set) : Float;

	var destroyed(get,never) : Bool;
	var bindings(get,never) : Map<T, Array< InputBinding<T> >>;
	var pad(get,never) : hxd.Pad;
	var lockedUntilS = -1.;
	var holdTimeS : Map<T,Float> = new Map();
	var autoFireFirstDone : Map<T,Bool> = new Map();
	var autoFireNextS : Map<T,Float> = new Map();
	var postLockUntilS = -1.;

	@:allow(dn.heaps.input.Controller)
	function new(c:Controller<T>) {
		controller = c;
	}

	inline function get_destroyed() return controller==null || controller.destroyed;
	inline function get_bindings() return destroyed ? null : controller.bindings;
	inline function get_pad() return destroyed ? null : controller.pad;
	inline function get_disableRumble() return destroyed ? false : controller.disableRumble;
	inline function set_disableRumble(v) { if(!destroyed) controller.disableRumble = v; return disableRumble; }
	inline function get_rumbleMultiplicator() return destroyed ? 0 : controller.rumbleMultiplicator;
	inline function set_rumbleMultiplicator(v) { if(!destroyed) controller.rumbleMultiplicator = v; return rumbleMultiplicator; }

	/** Current `ControllerDebug` instance, if it exists. This can be created using `createDebugger()` **/
	public var debugger(default,null) : Null<ControllerDebug<T>>;


	public function dispose() {
		controller.unregisterAccess(this);
		controller = null;
		holdTimeS = null;

		if( debugger!=null ) {
			debugger.destroy();
			debugger = null;
		}
	}


	@:keep public function toString() {
		return 'ControllerAccess[ $controller ]'
			+ ( !isActive()?"<LOCKED>":"" );
	}


	/**
		To return TRUE, all the following conditions must be true too:
		- this Access must not be locked,
		- it must not be disposed,
		- another Access must not have taken "exclusivity".
	**/
	public function isActive() {
		if( lockCondition() )
			postLockUntilS = haxe.Timer.stamp()+0.06;
		return !destroyed
			&& ( postLockUntilS<0 || haxe.Timer.stamp()>=postLockUntilS )
			&& ( lockedUntilS<0 || haxe.Timer.stamp()>=lockedUntilS )
			&& !lockCondition()
			&& ( controller.exclusive==null || controller.exclusive==this );
	}

	/**
		Create a `ControllerDebug` for debugging purpose.
		@param parent The target dn.Process to host the debugger
		@param afterRender This optional callback is called after the Debugger was created, if you need to adjust it.
	**/
	public function createDebugger(parent:dn.Process, ?afterRender:ControllerDebug<T>->Void) : ControllerDebug<T> {
		if( debugger!=null )
			debugger.destroy();
		debugger = new ControllerDebug(this, parent, afterRender);
		return debugger;
	}

	/** Return TRUE if a ControllerDebug instance exists. **/
	public inline function hasDebugger() return debugger!=null;

	/** Destroy existing ControllerDebug instance. **/
	public inline function removeDebugger() {
		if( debugger!=null ) {
			debugger.destroy();
			debugger = null;
		}
	}

	/**
		Create a new or destroy existing ControllerDebug instance.
		@param parent The target dn.Process to host the debugger
		@param afterRender This optional callback is called after the Debugger was created, if you need to adjust it.
	**/
	public function toggleDebugger(parent:dn.Process, ?afterRender:ControllerDebug<T>->Void) {
		if( hasDebugger() )
			removeDebugger();
		else
			createDebugger(parent, afterRender);
	}



	/**
		Return analog float value (-1.0 to 1.0) associated with given action Enum.
	**/
	public inline function getAnalogValue(action:T) : Float {
		if( isActive() && controller.bindings.exists(action) ) {
			var out = 0.;
			for(b in controller.bindings.get(action) ) {
				out = b.getValue(controller.pad);
				if( out!=0 )
					break;
			}
			return out;
		}
		else
			return 0;
	}



	/**
		Return analog float value (-1.0 to 1.0) associated with given the 2 action Enum (this implies that these 2 actions refer to the negative/positive directions of the analog).
	**/
	public inline function getAnalogValue2(negativeAction:T, positiveAction:T) : Float {
		return -M.fabs(getAnalogValue(negativeAction)) + M.fabs(getAnalogValue(positiveAction));
	}



	/**
		Return analog Radian angle (-PI to PI).
		@param xAxisAction Enum action associated with horizontal analog axis (both positive and negative)
		@param yAxisAction Enum action associated with vertical analog axis (both positive and negative)
	**/
	public inline function getAnalogAngleXY(xAxisAction:T, yAxisAction:T) {
		return Math.atan2( getAnalogValue(yAxisAction), getAnalogValue(xAxisAction) );
	}



	/**
		Return analog Radian angle (-PI to PI) using 4 actions.
		@param leftAction Enum action associated with the LEFT analog direction
		@param rightAction Enum action associated with the RIGHT analog direction
		@param upAction Enum action associated with the UP analog direction
		@param downAction Enum action associated with the DOWN analog direction
	**/
	public inline function getAnalogAngle4(leftAction:T, rightAction:T, upAction:T, downAction:T) {
		return Math.atan2(
			getAnalogValue2(upAction,downAction),
			getAnalogValue2(leftAction,rightAction)
		);
	}


	/**
		Return analog controller distance (0 to 1).
		@param xAction Enum action associated with horizontal analog
		@param yAction Enum action associated with vertical analog. If omitted, only the xAction enum is considered
		@param clamp If false, the returned distance might be greater than 1 (like 1.06), for corner directions.
	**/
	public inline function getAnalogDistXY(xAction:T, ?yAction:T, clamp=true) {
		inline function _dist() {
			return dn.M.dist( 0, 0, getAnalogValue(xAction), getAnalogValue(yAction) );
		}
		return
			yAction==null
				? dn.M.fabs( getAnalogValue(xAction) )
				: clamp
					? dn.M.fmin( _dist(), 1 )
					: _dist();
	}


	/**
		Return analog controller distance (0 to 1).
		@param leftAction Enum action associated with the LEFT analog direction
		@param rightAction Enum action associated with the RIGHT analog direction
		@param upAction Enum action associated with the UP analog direction
		@param downAction Enum action associated with the DOWN analog direction
		@param clamp If false, the returned distance might be greater than 1 (like 1.06), for corner directions.
	**/
	public inline function getAnalogDist4(leftAction:T, rightAction:T, upAction:T, downAction:T, clamp=true) : Float {
		inline function _dist(){
			return dn.M.dist( 0,0, getAnalogValue(leftAction)+getAnalogValue(rightAction), getAnalogValue(upAction)+getAnalogValue(downAction) );
		}

		return clamp ? M.fmin(_dist(),1) : _dist();
	}


	/**
		Return analog controller distance (0 to 1) of a single axis.
		@param negativeAction Enum action associated with the NEGATIVE analog direction
		@param positiveAction Enum action associated with the POSITIVE analog direction
	**/
	public inline function getAnalogDist2(negativeAction:T, positiveAction:T) : Float {
		return M.fabs( getAnalogValue2(negativeAction, positiveAction) );
	}


	/**
		Return TRUE if given action Enum is "down". For a digital binding, this means the button/key is pushed. For an analog binding, this means it is pushed beyond a specific threshold.
	**/
	public function isDown(v:T) : Bool {
		if( isActive() && bindings.exists(v) ) {
			for(b in bindings.get(v))
				if( b.isDown(pad) )
					return true;
		}

		return false;
	}


	/**
		Return TRUE if given action Enum is "pressed" (ie. pushed while it was previously released). By definition, this only happens during 1 frame, when control is pushed.
	**/
	public function isPressed(v:T) : Bool {
		if( isActive() && bindings.exists(v) ) {
			for(b in bindings.get(v))
				if( b.isPressed(pad) )
					return true;
		}

		return false;
	}


	/**
		Return TRUE if given action Enum is "released" (ie. released while it was previously pushed). By definition, this only happens during 1 frame, when control is released.
	**/
	public function isReleased(v:T) : Bool {
		if( isActive() && bindings.exists(v) ) {
			for(b in bindings.get(v))
				if( b.isReleased(pad) )
					return true;
		}

		return false;
	}


	public inline function initHeldState(action:T) {
		if( holdTimeS.exists(action) )
			holdTimeS.remove( action );
	}

	/**
		Update the "held" state of an action.

		NOTE: most of the time, this method shouldn't be required, as the "held" state is automatically updated through calls to `isHeld` and `getHoldRatio`. But in some situations, you might need to manually call this update at the *beginning* of your frames, to ensure the held state is properly updated.

		If in doubt, just call it. You will not break anything doing so.
	**/
	public inline function updateHeldState(action:T) {
		if( !isDown(action) && holdTimeS.exists(action) )
			holdTimeS.remove( action );
		else if( isDown(action) && !holdTimeS.exists(action) )
			holdTimeS.set( action, haxe.Timer.stamp() );
	}

	/**
		Return TRUE if given action Enum is "held down" for more than `seconds` seconds.

		WARNING: the method will actually start its internal "held timer" when it will see the action as being down. This means the method should be called continuously for this to happen correctly.
	**/
	public inline function isHeld(action:T, seconds:Float) : Bool {
		updateHeldState(action);
		if( !isDown(action) )
			return false;
		else {
			if( holdTimeS.get(action)>0 && getRawHoldTimeS(action) >= seconds ) {
				holdTimeS.set(action, -1);
				return true;
			}
			else
				return false;
		}
	}

	/** Return hold time for given action, without calling internal "held update" **/
	inline function getRawHoldTimeS(action:T) : Float {
		return holdTimeS.exists(action) ? haxe.Timer.stamp() - holdTimeS.get(action) : 0;
	}

	/**
		Return a ratio (float between 0 and 1) representing how long given `action` was held down.
	**/
	public inline function getHoldRatio(action:T, seconds:Float) : Float {
		updateHeldState(action);
		return !holdTimeS.exists(action)
			? 0
			: holdTimeS.get(action)<0
				? 1
				: M.fclamp( getRawHoldTimeS(action) / seconds, 0, 1 );
	}

	/**
		Return current "held time" in seconds of `action`.
	**/
	public inline function getHoldTimeS(action:T) : Float {
		updateHeldState(action);
		return getRawHoldTimeS(action);
	}


	/**
		Return TRUE if given action is "pressed", and this will repeatedly return TRUE, just like a keyboard key that is held down for an extended period of time.
		@param firstDelayS Delay in seconds after the first press to start firing other presses.
		@param repeatDelayS Delay in seconds between presses after the first one.
	**/
	public inline function isPressedAutoFire(action:T, firstDelayS=0.28, repeatDelayS=0.07) {
		if( !isDown(action) ) {
			autoFireNextS.set(action, 0);
			autoFireFirstDone.remove(action);
			return false;
		}
		else {
			var now = haxe.Timer.stamp();
			if( !autoFireNextS.exists(action) || now>=autoFireNextS.get(action) ) {
				autoFireNextS.set(action, now + ( !autoFireFirstDone.exists(action) ? firstDelayS : repeatDelayS ));
				autoFireFirstDone.set(action, true);
				return true;
			}
			else
				return false;
		}
	}



	/**
		Return TRUE if given action Enum has a negative value.
		NOTE: Only works with Analog bindings (ie. pad stick or its corresponding keyboard bindings).

		@param threshold If provided, this will be an additional threshold to check against, like the "dead-zone" factor of the Controller.
	**/
	public inline function isNegative(action:T, threshold=0.) {
		return getAnalogValue(action) < -M.fabs(threshold);
	}


	/**
		Return TRUE if given action Enum has a positive value.
		NOTE: Only works with Analog bindings (ie. pad stick or its corresponding keyboard bindings).

		@param threshold If provided, this will be an additional threshold to check against, like the "dead-zone" factor of the Controller.
	**/
	public inline function isPositive(action:T, threshold=0.) {
		return getAnalogValue(action) > M.fabs(threshold);
	}


	/**
		Return TRUE if any **button** of the pad is pressed (doesn't apply to stick or dpad, use `anyMovement()` for that).
	**/
	public inline function anyPadButtonPressed() {
		return isPadPressed(A) || isPadPressed(B) || isPadPressed(X) || isPadPressed(Y)
			|| isPadPressed(LT) || isPadPressed(RT)
			|| isPadPressed(LB) || isPadPressed(RB)
			|| isPadPressed(START) || isPadPressed(SELECT);
	}


	/**
		Return TRUE if any **button** of the pad is down (doesn't apply to stick or dpad, use `anyMovement()` for that).
	**/
	public inline function anyPadButtonDown() {
		return isPadDown(A) || isPadDown(B) || isPadDown(X) || isPadDown(Y)
			|| isPadDown(LT) || isPadDown(RT)
			|| isPadDown(LB) || isPadDown(RB)
			|| isPadDown(START) || isPadDown(SELECT);
	}


	/**
		Return TRUE if any movement input is detected (analog sticks or dpad).
	**/
	public inline function anyAxisMovement() {
		return pad.xAxis!=0 || pad.yAxis!=0 || pad.rxAxis!=0 || pad.ryAxis!=0
			|| isPadDown(DPAD_LEFT) || isPadDown(DPAD_RIGHT) || isPadDown(DPAD_UP) || isPadDown(DPAD_DOWN);
	}


	/**
		Return TRUE if any movement input is detected (analog sticks or dpad).
	**/
	public inline function anythingDown() {
		return anyAxisMovement() || anyPadButtonDown();
	}


	/**
		Return the first PadButton detected as "pressed"
	**/
	public inline function getPressedPadButton() : Null<PadButton> {
		return
			if( isPadPressed(A) ) A;
			else if( isPadPressed(B) ) B;
			else if( isPadPressed(X) ) X;
			else if( isPadPressed(Y) ) Y;
			else if( isPadPressed(LT) ) LT;
			else if( isPadPressed(LB) ) LB;
			else if( isPadPressed(RT) ) RT;
			else if( isPadPressed(RB) ) RB;
			else if( isPadPressed(START) ) START;
			else if( isPadPressed(SELECT) ) SELECT;
			else if( isPadPressed(DPAD_LEFT) ) DPAD_LEFT;
			else if( isPadPressed(DPAD_RIGHT) ) DPAD_RIGHT;
			else if( isPadPressed(DPAD_UP) ) DPAD_UP;
			else if( isPadPressed(DPAD_DOWN) ) DPAD_DOWN;
			else if( isPadPressed(LSTICK_PUSH) ) LSTICK_PUSH;
			else if( isPadPressed(RSTICK_PUSH) ) RSTICK_PUSH;
			else null;
	}


	/**
		Directly check if a keyboard key is pushed.
	**/
	public inline function isKeyboardDown(k:Int) {
		return isActive() ? hxd.Key.isDown(k) : false;
	}


	/**
		Return TRUE if any key among Control, Shift or Alt is down.
	**/
	public inline function anyKeyboardToggleDown() {
		return isKeyboardDown(Key.ALT) || isKeyboardDown(Key.CTRL) || isKeyboardDown(Key.SHIFT);
	}

	/**
		Check if a pad or keyboard button traditionally associated with "Continuing" is pressed (eg. for a "Press any key to continue").
	**/
	public inline function anyStandardContinuePressed() {
		return anyPadButtonPressed()
			|| isKeyboardPressed(Key.E)
			|| isKeyboardPressed(Key.F)
			|| isKeyboardPressed(Key.ESCAPE)
			|| isKeyboardPressed(Key.SPACE)
			|| isKeyboardPressed(Key.ENTER)
			|| isKeyboardPressed(Key.NUMPAD_ENTER);
	}
	/**
		Check if a pad or keyboard button traditionally associated with "Continuing" is down (eg. for a "Press any key to continue").
	**/
	public inline function anyStandardContinueDown() {
		return anyPadButtonDown()
			|| isKeyboardDown(Key.E)
			|| isKeyboardDown(Key.F)
			|| isKeyboardDown(Key.ESCAPE)
			|| isKeyboardDown(Key.SPACE)
			|| isKeyboardDown(Key.ENTER)
			|| isKeyboardDown(Key.NUMPAD_ENTER);
	}

	/**
		Directly check if a keyboard key is pressed (ie. it wasn't pushed in previous frame and it's now pushed).
	**/
	public inline function isKeyboardPressed(k:Int) {
		return isActive() ? hxd.Key.isPressed(k) : false;
	}

	/**
		Directly check if a gamepad button is pushed.
	**/
	public inline function isPadDown(button:PadButton) {
		return isActive() ? pad.isDown( controller.getPadButtonId(button) ) : false;
	}

	/**
		Directly check if a gamepad button is pressed (ie. previously not pushed, and now it is).
	**/
	public inline function isPadPressed(button:PadButton) {
		return isActive() ? pad.isPressed( controller.getPadButtonId(button) ) : false;
	}

	/**
		Directly check gamepad left stick dist (0->1)
	**/
	public inline function getPadLeftStickDist() {
		return M.dist(0,0, pad.xAxis, pad.yAxis);
	}

	/**
		Directly check gamepad left stick dist (0->1)
	**/
	public inline function getPadRightStickDist() {
		return M.dist(0,0, pad.rxAxis, pad.ryAxis);
	}

	/** Rumbles physical controller, if supported **/
	public inline function rumble(strength:Float, seconds:Float) {
		controller.rumble(strength, seconds);
	}

	/**
		This method is meant be re-assigned. The function should either return TRUE if this Access should be marked as "locked", FALSE otherwise. A locked Access will stop checking for inputs.
	**/
	public dynamic function lockCondition() return false;

	/**
		Lock controller for specificed duration (in seconds), which defaults to "long enough to be considered as infinite".
	**/
	public inline function lock(durationSeconds=999999.) {
		lockedUntilS = haxe.Timer.stamp() + durationSeconds;
	}

	/**
		Remove previous locked status from `lock()` call. This doesn't remove the potential lock from `lockCondition()`.
	**/
	public inline function unlock() {
		lockedUntilS = -1;
	}


	/**
		Take exclusivity over all other `ControllerAccess` (they will not receive any input while this access has exclusivity)
	**/
	public inline function takeExclusivity() {
		controller.makeExclusive(this);
	}

	/**
		Release current exclusivity (even if it wasn't taken by this access)
	**/
	public inline function releaseExclusivity() {
		controller.releaseExclusivity();
	}
}
