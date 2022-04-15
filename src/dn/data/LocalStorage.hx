package dn.data;

enum StorageFormat {
	Json;
	Serialized;
}

class LocalStorage {

	/** Relative path to the store the data files (only relevant on platformss that support file writing) **/
	public static var STORAGE_PATH : Null<String> =
		try {
			#if hxnodejs
				js.node.Require.require("process").cwd();
			#elseif sys
				Sys.getCwd();
			#else
				null;
			#end
		} catch(e) null;


	#if( sys || hl || hxnodejs )

	/** Return path to the storage file for specified storage name **/
	static function getStoragePath(storageName:String) : dn.FilePath {
		var fp = FilePath.fromDir( STORAGE_PATH==null ? "" : STORAGE_PATH );
		fp.fileName = storageName;
		fp.extension = "cfg";
		fp.useSlashes();
		return fp;
	}

	#end

	/** Defines the type of "prettifying applied to the JSON output. Only applies if the data is stored as JSON.  **/
	public static var JSON_PRETTY_LEVEL : dn.data.JsonPretty.JsonPrettyLevel = Compact;

	/** If TRUE, a checksum will be written along with data, which will be verified on loading. **/
	public static var CRC = false;


	/** Build checksum for given string **/
	static function makeCRC(data:String) {
		return haxe.crypto.Sha1.encode( data + haxe.crypto.Sha1.encode(data + SALT) ).substr(4, 32);
	}
	static var SALT = "s*al!t";
	static var CHECKSUM_SEPARATOR = "/||/";


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

		var raw : Null<String> = {
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

		if( CRC ) {
			// Check CRC
			var parts = raw.split(CHECKSUM_SEPARATOR);
			if( parts.length!=2 )
				return null;

			if( makeCRC( parts[1] ) != parts[0] )
				return null;
			else
				return parts[1];
		}
		else
			return raw;
	}

	/**
		Save raw storage data.
	**/
	static function _saveStorage(storageName:String, raw:String) : Bool {
		try {
			if( CRC )
				raw = makeCRC(raw) + CHECKSUM_SEPARATOR + raw;

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
	public static function readObject<T>(storageName:String, format:StorageFormat, ?defValue:T) : T {
		var raw = _loadRawStorage(storageName);
		if( raw==null )
			return defValue;
		else {
			var obj = switch format {
				case Json: try haxe.Json.parse(raw) catch(_) null;
				case Serialized: try haxe.Unserializer.run(raw) catch(_) null;
			}

			if( obj==null )
				return defValue;

			if( defValue!=null ) {
				// Remove old fields
				for(k in Reflect.fields(obj))
					if( !Reflect.hasField(defValue,k) )
						Reflect.deleteField(obj, k);

				// Add missing fields
				for(k in Reflect.fields(defValue))
					if( !Reflect.hasField(obj,k) )
						Reflect.setField(obj, k, Reflect.field(defValue,k));
			}

			// Fix final object
			switch format {
				case Json:
					// Remap JsonPretty enums
					var enumError = false;
					Lib.iterateObjectRec(obj, (v,setter)->{
						if( Type.typeof(v)==TObject ) {
							var enumObj : Dynamic = cast v;
							if( enumObj.__jsonEnum!=null ) {
								try {
									var enumStr : String = enumObj.__jsonEnum;
									var e = Type.resolveEnum(enumStr);
									var ev = e.createByName(enumObj.v, enumObj.p==null ? [] : enumObj.p);
									setter(ev);
								}
								catch(err:Dynamic) {
									enumError = true;
								}
							}
						}
					});

					if( enumError )
						return defValue;

				case Serialized:
			}

			return obj;
		}
	}

	/**
		Write an anonymous object to specified storage name. If `storeAsJson` is FALSE, the object will be serialized.
	**/
	public static function writeObject<T>(storageName:String, format:StorageFormat, obj:T) {
		var str = switch format {
			case Json:
				JsonPretty.stringify(obj, JSON_PRETTY_LEVEL, UseEnumObject);

			case Serialized:
				haxe.Serializer.run(obj);
		}
		_saveStorage( storageName, str );
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
		var baseStorageName = "test";
		delete(baseStorageName);
		CiAssert.isTrue( !exists(baseStorageName) );

		CiAssert.printIfVerbose("LocaleStorage for Strings:");

		// Object: default value
		var v = readString(baseStorageName, "foo");
		CiAssert.isTrue( !exists(baseStorageName) );
		CiAssert.isTrue( v!=null );
		CiAssert.equals( v, "foo" );

		// String: writing
		if( isSupported() ) {
			v = "bar";
			writeString(baseStorageName, v);
			CiAssert.isTrue( exists(baseStorageName) );
			var v = readString(baseStorageName);
			CiAssert.equals(v, "bar");
			delete(baseStorageName);
		}

		CiAssert.printIfVerbose("LocaleStorage for objects:");

		// Default value test
		var firstLoaded = readObject(baseStorageName, Json, { a:0, b:10, str:"foo", enu:ValueA });
		CiAssert.isTrue( !exists(baseStorageName) );
		CiAssert.isTrue( firstLoaded!=null );
		CiAssert.equals( firstLoaded.a, 0 );
		CiAssert.equals( firstLoaded.b, 10 );
		CiAssert.equals( firstLoaded.str, "foo" );
		CiAssert.equals( firstLoaded.enu, ValueA );

		// Writing
		if( isSupported() ) {
			CRC = false;
			JSON_PRETTY_LEVEL = Full;
			firstLoaded.a++;
			firstLoaded.b++;
			firstLoaded.str = null;


			// Json format
			var name = baseStorageName+"_json";
			CiAssert.printIfVerbose("Json format:");
			writeObject(name, Json, firstLoaded);
			CiAssert.isTrue( exists(name) );

			var jsonLoaded = readObject(name, Json);
			CiAssert.equals( jsonLoaded.a, 1 );
			CiAssert.equals( jsonLoaded.b, 11 );
			CiAssert.equals( jsonLoaded.str, null );
			CiAssert.equals( jsonLoaded.enu, ValueA );
			delete(name);
			CiAssert.isFalse( exists(name) );


			// Json format with CRC
			CRC = true;
			var name = baseStorageName+"_jsonCrc";
			CiAssert.printIfVerbose("Json format:");
			writeObject(name, Json, firstLoaded);
			CiAssert.isTrue( exists(name) );

			var jsonLoaded = readObject(name, Json);
			CiAssert.equals( jsonLoaded.enu, ValueA );
			delete(name);
			CiAssert.isFalse( exists(name) );
			CRC = false;


			// Serialized format
			var name = baseStorageName+"_ser";
			CiAssert.printIfVerbose("Serialized format:");
			writeObject(name, Serialized, firstLoaded);
			CiAssert.isTrue( exists(name) );

			var serializedLoaded = readObject(name, Serialized);
			CiAssert.equals( serializedLoaded.a, 1 );
			CiAssert.equals( serializedLoaded.b, 11 );
			CiAssert.equals( serializedLoaded.str, null );
			delete(name);
			CiAssert.isFalse( exists(name) );


			// Serialized format with CRC
			var name = baseStorageName+"_serCrc";
			CRC = true;
			CiAssert.printIfVerbose("Serialized format:");
			writeObject(name, Serialized, firstLoaded);
			CiAssert.isTrue( exists(name) );

			var serializedLoaded = readObject(name, Serialized);
			CiAssert.equals( serializedLoaded.a, 1 );
			CiAssert.equals( serializedLoaded.b, 11 );
			CiAssert.equals( serializedLoaded.str, null );


			// Alter storage on disk to break CRC
			CRC = false;
			var alteredRaw = _loadRawStorage(name);
			alteredRaw+="_changed";
			CRC = true;

			// Write altered file
			var fp = getStoragePath(name);
			#if hxnodejs
				js.node.Fs.writeFileSync( fp.full, alteredRaw );
			#elseif sys
				sys.io.File.saveContent(fp.full, alteredRaw);
			#end

			// Check CRC breaking
			var o : Dynamic = readObject(name, Serialized);
			CiAssert.equals( o, null );
			delete(name);
			CiAssert.isFalse( exists(name) );
		}
		else
			CiAssert.printIfVerbose("WARNING: LocaleStorage isn't supported on this platform!");
	}
}

private enum StorageTestEnum {
	ValueA;
	ValueB;
	ValueC;
}

