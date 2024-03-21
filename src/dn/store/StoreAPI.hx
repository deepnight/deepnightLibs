package dn.store;

class StoreAPI {
	public var name(default,null) : String;

	public function new() {
		name = "??";
	}

	/** This must be called before anything else **/
	public function preBootInit() {}

	/** This must be called after the App instance was created **/
	public function appInit() {}

	public function isActive() return false;

	public dynamic function onOverlay(active:Bool) {}

	function print(msg:String) {
		Sys.println('$name: $msg');
	}
}