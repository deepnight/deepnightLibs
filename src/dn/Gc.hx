package dn;

/**
	Abstract garbage collector controller
	(supports Hashlink only for now)
**/
class Gc {
	static var _active = true;

	/** Return TRUE if GC management is supported **/
	public static function isSupported() {
		#if hl
		return true;
		#else
		return false;
		#end
	}

	/** Return TRUE if GC is currently running. On unsupported platforms, this always returns FALSE. **/
	public static inline function isActive() return _active && isSupported();

	/** Enable or disable the GC **/
	public static inline function setState(active:Bool) {
		#if hl
		hl.Gc.enable(active);
		_active = active;
		#end
	}

	/** Enable the GC **/
	public static inline function enable() setState(true);

	/** Disable the GC **/
	public static inline function disable() setState(false);

	/** Try to force a GC sweeping immediately **/
	public static inline function runNow() {
		#if hl
		hl.Gc.enable(true);
		hl.Gc.major();
		hl.Gc.enable(_active);
		#end
	}


	/** Return currently "currently allocated memory" **/
	public static inline function getCurrentMem() : Float {
		#if hl
			var _ = 0., v = 0.;
			@:privateAccess hl.Gc._stats(_, _, v);
			return v;
		#else
			return 0;
		#end
	}

	/** Return current "allocation count" **/
	public static inline function getAllocationCount() : Float {
		#if hl
			var _ = 0., v = 0.;
			@:privateAccess hl.Gc._stats(_, v, _);
			return v;
		#else
			return 0;
		#end
	}

	/** Return current "total allocated" **/
	public static inline function getTotalAllocated() : Float {
		#if hl
			var _ = 0., v = 0.;
			@:privateAccess hl.Gc._stats(v, _, _);
			return v;
		#else
			return 0;
		#end
	}

}