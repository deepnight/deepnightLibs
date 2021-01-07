package dn;

class LocalStorage {

	#if( sys || hl || hxnodejs )

	/** Base path to the storage folder **/
	public static var BASE_PATH : Null<String> =
		try {
			#if hxnodejs
			js.node.Require.require("process").cwd();
			#else
			Sys.getCwd();
			#end
		} catch(e) null;

	/** Default storage sub-folder **/
	public static var SUB_FOLDER_NAME : Null<String> = "userSettings";

	/** Return path to the storage file for specified storage name **/
	static function getStoragePath(storageName:String) : dn.FilePath {
		var fp = FilePath.fromFile(
			( BASE_PATH==null ? "" : BASE_PATH+"/" )
			+ ( SUB_FOLDER_NAME==null ? "" : SUB_FOLDER_NAME + "/" )
			+ storageName + ".cfg"
		);
		fp.useSlashes();
		return fp;
	}

	#end


	/** Return TRUE if this platform supports local storage **/
	public static function isSupported() : Bool {
		#if( hl || sys || hxnodejs || flash )
		return true;
		#elseif js
		return js.Browser.getLocalStorage()!=null;
		#else
		return false;
		#end
	}

	/**
		Read unparsed String for specified storage name
	**/
	static function _loadRawStorage(storageName:String) : Null<String> {
		if( storageName==null )
			return null;

		return {
			#if flash

				try flash.net.SharedObject.getLocal( storageName ).data.content catch(e:Dynamic) null;

			#elseif( sys || hl || hxnodejs )

				var fp = getStoragePath(storageName);
				#if hxnodejs
				try js.node.Fs.readFileSync(fp.full).toString() catch(e) null;
				#else
				try sys.io.File.getContent(fp.full) catch( e : Dynamic ) null;
				#end

			#elseif js

				var jsStorage = js.Browser.getLocalStorage();
				if( jsStorage!=null )
					jsStorage.getItem(storageName);
				else
					null;

			#else

				throw "Platform not supported";

			#end
		}
	}

	/**
		Save raw storage data.
	**/
	static function _saveStorage(storageName:String, raw:String) : Bool {
		try {
			#if flash

				var so = flash.net.SharedObject.getLocal( storageName );
				so.data.content = raw;
				so.flush();

			#elseif( sys || hl || hxnodejs )

				var fp = getStoragePath(storageName);

				#if hxnodejs

				if( !js.node.Fs.existsSync(fp.directory) )
					js.node.Fs.mkdirSync(fp.directory);
				js.node.Fs.writeFileSync( fp.full, raw );

				#else

				if( !sys.FileSystem.exists(fp.directory) )
					sys.FileSystem.createDirectory(fp.directory);
				sys.io.File.saveContent(fp.full, raw);

				#end

			#elseif js

				var jsStorage = js.Browser.getLocalStorage();
				if( jsStorage!=null )
					jsStorage.setItem(storageName, raw);
				else
					null;

			#else

				throw "Platform not supported";

			#end
			return true;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}

	/**
		Read the specified storage as a String.
	**/
	public static function readString(storageName:String, ?defValue:String) : Null<String> {
		var raw = _loadRawStorage(storageName);
		return raw==null ? defValue : raw;
	}

	/**
		Save a String to specified storage.
	**/
	public static function writeString(storageName:String, raw:String) {
		_saveStorage(storageName, raw);
	}

	/**
		Read an anonymous object right from storage.
	**/
	public static function readObject<T>(storageName:String, isJsonStorage:Bool, ?defValue:T) : T {
		var raw = _loadRawStorage(storageName);
		if( raw==null )
			return defValue;
		else {
			var obj =
				try isJsonStorage ? haxe.Json.parse(raw) : haxe.Unserializer.run(raw)
				catch( err:Dynamic ) null;

			if( obj==null )
				return defValue;

			if( defValue==null )
				return obj;

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

	/**
		Write an anonymous object to specified storage name. If `storeAsJson` is FALSE, the object will be serialized.
	**/
	public static function writeObject<T>(storageName:String, storeAsJson:Bool, obj:T) {
		if( storeAsJson )
			_saveStorage( storageName, JsonPretty.stringify(obj, Full) );
		else
			_saveStorage( storageName, haxe.Serializer.run(obj) );
	}


	/**
		Return TRUE if specified storage data exists.
	**/
	public static function exists(storageName:String) : Bool {
		try return _loadRawStorage(storageName)!=null
		catch( e:Dynamic ) return false;
	}


	/**
		Remove specified storage data.
	**/
	public static function delete(storageName:String) {
		try {
			#if flash

				var so = flash.net.SharedObject.getLocal( storageName );
				if( so==null )
					return;
				so.clear();

			#elseif( sys || hl || hxnodejs )

				var fp = getStoragePath(storageName);
				#if hxnodejs
				js.node.Fs.unlinkSync(fp.full);
				#else
				sys.FileSystem.deleteFile(fp.full);
				#end

			#elseif js

				js.Browser.window.localStorage.removeItem(storageName);

			#else

				throw "Platform not supported";

			#end
		}
		catch( e:Dynamic ) {
		}
	}


	@:noCompletion
	public static function __test() {
		var storageName = "test";
		delete(storageName);
		CiAssert.isTrue( !exists(storageName) );

		CiAssert.println("LocaleStorage for Strings:");

		// Object: default value
		var v = readString(storageName, "foo");
		CiAssert.isTrue( !exists(storageName) );
		CiAssert.isTrue( v!=null );
		CiAssert.equals( v, "foo" );

		// String: writing
		if( isSupported() ) {
			v = "bar";
			writeString(storageName, v);
			CiAssert.isTrue( exists(storageName) );
			var v = readString(storageName);
			CiAssert.equals(v, "bar");
			delete(storageName);
		}

		CiAssert.println("LocaleStorage for objects:");

		// Object: default value
		var obj = readObject(storageName, false, { a:0, b:10, str:"foo" });
		CiAssert.isTrue( !exists(storageName) );
		CiAssert.isTrue( obj!=null );
		CiAssert.equals( obj.a, 0 );
		CiAssert.equals( obj.b, 10 );
		CiAssert.equals( obj.str, "foo" );

		// Writing
		if( isSupported() ) {
			obj.a++;
			obj.b++;
			obj.str = null;

			// Json format
			CiAssert.println("Json format:");
			writeObject(storageName, true, obj);
			CiAssert.isTrue( exists(storageName) );
			var obj = readObject(storageName, true);
			CiAssert.equals( obj.a, 1 );
			CiAssert.equals( obj.b, 11 );
			CiAssert.equals( obj.str, null );

			// Serialized format
			CiAssert.println("Serialized format:");
			delete(storageName);
			writeObject(storageName, false, obj);
			CiAssert.isTrue( exists(storageName) );
			var obj = readObject(storageName, false);
			CiAssert.equals( obj.a, 1 );
			CiAssert.equals( obj.b, 11 );
			CiAssert.equals( obj.str, null );

			delete(storageName);
			CiAssert.isTrue( !exists(storageName) );
		}
		else
			CiAssert.println("WARNING: LocaleStorage isn't supported on this platform!");
	}
}
