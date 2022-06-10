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
	public static function forceRun() {
		#if hl
		hl.Gc.enable(true);
		hl.Gc.major();
		hl.Gc.enable(_active);
		#end
	}
}