package dn.legacy;

class Lib {
	#if( flash9 || openfl || sys )
	inline static function _getLocalCookie( cookieName ){
		#if (flash || openfl)
		return flash.net.SharedObject.getLocal( cookieName );
		#elseif sys
		return new LocalCookie( cookieName );
		#end
	}

	public static function getCookie(cookieName:String, varName:String, ?defValue:Dynamic) : Dynamic {
		try {
			var cookie = _getLocalCookie(cookieName);
			return
				if ( Reflect.hasField(cookie.data, varName) )
					Reflect.field(cookie.data, varName);
				else
					defValue;
		}
		catch( e:Dynamic ) {
			return defValue;
		}
	}

	public static function setCookie(cookieName:String, varName:String, value:Dynamic) {
		try {
			var cookie = _getLocalCookie(cookieName);
			Reflect.setField(cookie.data, varName, value);
			cookie.flush();
			return true;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}

	public static function removeCookie(cookieName:String, varName:String) {
		try {
			var cookie = _getLocalCookie(cookieName);
			if( cookie!=null ) {
				Reflect.deleteField(cookie.data, varName);
				cookie.flush();
			}
			return true;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}

	public static function resetCookie(cookieName:String, ?obj:Dynamic) {
		try {
			var cookie = _getLocalCookie(cookieName);
			cookie.clear();
			if (obj!=null)
				for (key in Reflect.fields(obj))
					Reflect.setField(cookie.data, key, Reflect.field(obj, key));
			cookie.flush();
			return true;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}
	#end


	#if (flash || openfl)
	public static inline function constraintBox(o:flash.display.DisplayObject, maxWid, maxHei) {
		var r = M.fmin( M.fmin(1, maxWid/o.width), M.fmin(1, maxHei/o.height) );
		o.scaleX = r;
		o.scaleY = r;
		return r;
	}

	public static inline function isOverlap(a:flash.geom.Rectangle, b:flash.geom.Rectangle) : Bool {
		return
			b.x>=a.x-b.width && b.x<=a.right &&
			b.y>=a.y-b.height && b.y<=a.bottom;
	}
	#end
}




#if (!(flash||openfl) && sys)
private class LocalCookie {
	public var name : String;
	public var data : Dynamic;

	public function new( name : String ){
		this.name = name;

		var p = path();
		if( sys.FileSystem.exists(p) )
			data = try haxe.Unserializer.run(sys.io.File.getContent(path())) catch( e : Dynamic ) {};
		else
			clear();
	}

	public function flush(){
		var d = Sys.getCwd()+"/_cookies";
		if( !sys.FileSystem.exists(d) )
			sys.FileSystem.createDirectory(d);

		sys.io.File.saveContent(path(), haxe.Serializer.run(data));
	}

	public inline function clear(){
		data = {};
	}

	inline function path(){
		return Sys.getCwd()+"/_cookies/"+name;
	}
}
#end
