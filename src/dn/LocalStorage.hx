package dn;

class LocalStorage {
	#if hl
	public static var DEFAULT_FOLDER = "userSettings";
	#end

	static function _getCookieData(cookieName:String) : String {
		return {
			#if flash
				try flash.net.SharedObject.getLocal( cookieName ).data.content catch(e:Dynamic) null;
			#elseif hl
				var path = Sys.getCwd()+"/"+DEFAULT_FOLDER+"/"+cookieName;
				try sys.io.File.getContent(path) catch( e : Dynamic ) null;
			#elseif js
				var raw = js.Browser.window.localStorage.getItem(cookieName);
				raw;
			#else
				throw "Platform not supported";
			#end
		}
	}

	public static function exists(cookieName:String) : Bool {
		try {
			return _getCookieData(cookieName)!=null;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}

	public static function readString(cookieName:String, ?defValue:String) : String {
		try {
			var data = _getCookieData(cookieName);
			var serializedReg = ~/^y[0-9]+:/gim;
			if( serializedReg.match(data) ) // Fix old double-serialized data
				data = try haxe.Unserializer.run(data) catch(e:Dynamic) data;
			return data!=null ? data : defValue;
		}
		catch( e:Dynamic ) {
			return defValue;
		}
	}

	public static function writeString(cookieName:String, value:String) {
		try {
			#if flash
				var so = flash.net.SharedObject.getLocal( cookieName );
				so.data.content = value;
				so.flush();
			#elseif hl
				var d = Sys.getCwd()+"/"+DEFAULT_FOLDER;
				if( !sys.FileSystem.exists(d) )
					sys.FileSystem.createDirectory(d);

				var file = Sys.getCwd()+"/"+DEFAULT_FOLDER+"/"+cookieName;
				sys.io.File.saveContent(file, value);
			#elseif js
				js.Browser.window.localStorage.setItem(cookieName, value);
			#else
				throw "Platform not supported";
			#end
		}
		catch( e:Dynamic ) {
		}
	}


	public static function readObject<T>(cookieName:String, ?defValue:T) : T {
		var raw = readString(cookieName);
		if( raw==null )
			return defValue;
		else {
			var obj =
				try haxe.Unserializer.run(raw)
				catch( err:Dynamic ) return defValue;

			// Remove old fields
			for(k in Reflect.fields(obj))
				if( !Reflect.hasField(defValue,k) )
					Reflect.deleteField(obj, k);

			// Add missing fields
			for(k in Reflect.fields(defValue))
				if( !Reflect.hasField(obj,k) )
					Reflect.setField(obj, k, Reflect.field(defValue,k));

			return obj;
		}
	}

	public static function writeObject<T>(cookieName:String, obj:T) {
		writeString(cookieName, haxe.Serializer.run(obj));
	}


	public static function readJson(cookieName:String, ?defValue:Dynamic) : Dynamic {
		var raw = readString(cookieName);
		if( raw==null )
			return defValue;
		else {
			return
				try haxe.Json.parse(raw)
				catch(err:Dynamic) defValue;

		}
	}

	public static function writeJson(cookieName:String, json:Dynamic) {
		writeString(cookieName, haxe.Json.stringify(json));
	}


	public static function delete(cookieName:String) {
		try {
			#if flash
				var so = flash.net.SharedObject.getLocal( cookieName );
				if( so==null )
					return;
				so.clear();
			#elseif hl
				var file = Sys.getCwd()+"/"+DEFAULT_FOLDER+"/"+cookieName;
				sys.FileSystem.deleteFile(file);
			#elseif js
				js.Browser.window.localStorage.removeItem(cookieName);
			#else
				throw "Platform not supported";
			#end
		}
		catch( e:Dynamic ) {
		}
	}
}
