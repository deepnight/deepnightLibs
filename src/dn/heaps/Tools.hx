package dn.heaps;

class Tools {
	public static function maximizeWindow() {
		#if( hlsdl || hldx )
		@:privateAccess hxd.Window.getInstance().window.maximize();
		#end
	}

	public static function setWindowPos(x:Int,y:Int) {
		#if( hlsdl || hldx )
		@:privateAccess hxd.Window.getInstance().window.setPosition(x,y);
		#end
	}
}
