package dn.heaps.input;

import hxd.Pad;
import hxd.Key;
import dn.heaps.input.GameInputManager;


class GameInputAccess<T:EnumValue> {
	public var manager(default,null) : GameInputManager<T>;

	var destroyed(get,never) : Bool;
	var bindings(get,never) : Map<T, Array< InputBinding<T> >>;
	var pad(get,never) : hxd.Pad;


	@:allow(dn.heaps.input.GameInputManager)
	function new(m:GameInputManager<T>) {
		manager = m;
	}

	inline function get_destroyed() return manager==null || manager.destroyed;
	inline function get_bindings() return destroyed ? null : manager.bindings;
	inline function get_pad() return destroyed ? null : manager.pad;

	/** Current `GameInputTester` instance, if it exists. This can be created using `createTester()` **/
	public var tester(default,null) : Null<GameInputTester<T>>;


	public function dispose() {
		manager.unregisterAccess(this);
		manager = null;

		if( tester!=null ) {
			tester.destroy();
			tester = null;
		}
	}


	@:keep public function toString() {
		return 'GameInputAccess[ $manager ]';
	}


	/**
		Create a `GameInputTester` for debugging purpose.
	**/
	public function createTester(parent:dn.Process, ?afterRender:GameInputTester<T>->Void) : GameInputTester<T> {
		if( tester!=null )
			tester.destroy();
		tester = new GameInputTester(this, parent, afterRender);
		return tester;
	}



	/**
		Return analog float value (-1.0 to 1.0) associated with given action Enum.
	**/
	public function getAnalogValue(action:T) : Float {
		var out = 0.;
		if( !destroyed && manager.bindings.exists(action) )
			for(b in manager.bindings.get(action) ) {
				out = b.getValue(manager.pad);
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
		if( !destroyed && bindings.exists(v) )
			for(b in bindings.get(v))
				if( b.isDown(pad) )
					return true;

		return false;
	}


	/**
		Return TRUE if given action Enum is "pressed" (ie. pushed while it was previously released). By definition, this only happens during 1 frame, when control is pushed.
	**/
	public function isPressed(v:T) : Bool {
		if( !destroyed && bindings.exists(v) )
			for(b in bindings.get(v))
				if( b.isPressed(pad) )
					return true;

		return false;
	}

	/** Rumbles physical controller, if supported **/
	public function rumble(strength:Float, seconds:Float) {
		pad.rumble(strength, seconds);
	}
}
