package dn.heaps.input;

import hxd.Pad;
import hxd.Key;
import dn.heaps.input.Controller;


/**
	This class should only be created through `Controller.createAccess()`.
**/
class ControllerAccess<T:EnumValue> {
	public var input(default,null) : Controller<T>;

	var destroyed(get,never) : Bool;
	var bindings(get,never) : Map<T, Array< InputBinding<T> >>;
	var pad(get,never) : hxd.Pad;
	var locked = false;

	@:allow(dn.heaps.input.Controller)
	function new(m:Controller<T>) {
		input = m;
	}

	inline function get_destroyed() return input==null || input.destroyed;
	inline function get_bindings() return destroyed ? null : input.bindings;
	inline function get_pad() return destroyed ? null : input.pad;

	/** Current `ControllerDebug` instance, if it exists. This can be created using `createDebugger()` **/
	public var debugger(default,null) : Null<ControllerDebug<T>>;


	public function dispose() {
		input.unregisterAccess(this);
		input = null;

		if( debugger!=null ) {
			debugger.destroy();
			debugger = null;
		}
	}


	@:keep public function toString() {
		return 'ControllerAccess[ $input ]';
	}


	public function isActive() {
		return !destroyed && !locked && !isLockedCustom() && ( input.exclusive==null || input.exclusive==this );
	}

	/**
		Create a `ControllerDebug` for debugging purpose.
	**/
	public function createDebugger(parent:dn.Process, ?afterRender:ControllerDebug<T>->Void) : ControllerDebug<T> {
		if( debugger!=null )
			debugger.destroy();
		debugger = new ControllerDebug(this, parent, afterRender);
		return debugger;
	}



	/**
		Return analog float value (-1.0 to 1.0) associated with given action Enum.
	**/
	public function getAnalogValue(action:T) : Float {
		var out = 0.;
		if( isActive() && input.bindings.exists(action) )
			for(b in input.bindings.get(action) ) {
				out = b.getValue(input.pad);
				if( out!=0 )
					return out;
			}
		return 0;
	}



	/**
		Return analog Radian angle (-PI to PI).
		@param xAction Enum action associated with horizontal analog
		@param yAction Enum action associated with vertical analog
	**/
	public inline function getAnalogAngle(xAction:T, yAction:T) {
		return Math.atan2( getAnalogValue(yAction), getAnalogValue(xAction) );
	}


	/**
		Return analog controller distance (0 to 1).
		@param xAction Enum action associated with horizontal analog
		@param yAction Enum action associated with vertical analog. If omitted, only the xAction enum is considered
		@param clamp If false, the returned distance might be greater than 1 (like 1.06), for corner directions.
	**/
	public inline function getAnalogDist(xAction:T, ?yAction:T, clamp=true) {
		return
			yAction==null
				? dn.M.fabs( getAnalogValue(xAction) )
				: clamp
					? dn.M.fmin( dn.M.dist(0,0, getAnalogValue(xAction), getAnalogValue(yAction)), 1 )
					: dn.M.dist(0,0, getAnalogValue(xAction), getAnalogValue(yAction));
	}


	/**
		Return TRUE if given action Enum is "down". For a digital binding, this means the button/key is pushed. For an analog binding, this means it is pushed beyond a specific threshold.
	**/
	public function isDown(v:T) : Bool {
		if( isActive() && bindings.exists(v) )
			for(b in bindings.get(v))
				if( b.isDown(pad) )
					return true;

		return false;
	}


	/**
		Return TRUE if given action Enum is "pressed" (ie. pushed while it was previously released). By definition, this only happens during 1 frame, when control is pushed.
	**/
	public function isPressed(v:T) : Bool {
		if( isActive() && bindings.exists(v) )
			for(b in bindings.get(v))
				if( b.isPressed(pad) )
					return true;

		return false;
	}


	public inline function isKeyboardDown(k:Int) {
		return isActive() ? hxd.Key.isDown(k) : false;
	}

	public inline function isKeyboardPressed(k:Int) {
		return isActive() ? hxd.Key.isPressed(k) : false;
	}


	/** Rumbles physical controller, if supported **/
	public function rumble(strength:Float, seconds:Float) {
		if( pad.index>=0 )
			pad.rumble(strength, seconds);
	}

	public dynamic function isLockedCustom() return false;

	public inline function lock() {
		locked = true;
	}

	public inline function unlock() {
		locked = false;
	}

	public inline function takeExclusivity() {
		input.makeExclusive(this);
	}

	public inline function releaseExclusivity() {
		input.releaseExclusivity();
	}
}
