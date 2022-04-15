package dn.data;

private enum StorageFormat {
	Json(prettyLevel:dn.data.JsonPretty.JsonPrettyLevel);
	Serialized;
}

/**
	Store strings and objects.
	Actual storage type depends on platform:
	 - File system for Sys targets and NodeJS
	 - Browser local storage for pure JS
	 - SharedObject for Flash
**/
class LocalStorage {
	static var CRC_SEPARATOR = "/||/";
	static var CRC_SALT = "s*al!t";

	/** If TRUE, a checksum will be written along with data, which will be verified on loading. **/
	public var useCRC = false;

	var storagePath : dn.FilePath;
	var format : StorageFormat;



	/**
		Create a storage where data uses JSON format
	**/
	public static function createJsonStorage(name:String, prettyLevel : dn.data.JsonPretty.JsonPrettyLevel = Full) : LocalStorage {
		var ls = new LocalStorage( name, Json(prettyLevel) );
		return ls;
	}

	/**
		Create a storage where data uses Haxe Serializer format
	**/
	public static function createSerializedStorage(name:String, useCrc=false) : LocalStorage {
		var ls = new LocalStorage(name, Serialized);
		ls.useCRC = useCrc;
		return ls;
	}



	function new(storageName:String, f:StorageFormat) {
		format = f;

		// Init path
		storagePath = FilePath.fromFile(storageName+".cfg");
		#if hxnodejs
			storagePath.setDirectory( try js.node.Require.require("process").cwd() catch(_) null );
		#elseif sys
			storagePath.setDirectory( Sys.getCwd() );
		#end
	}


	/**
		Change the extension of the storage file (only works for platforms that have file system access).
	**/
	public function setStorageFileExtension(ext:Null<String>) {
		if( ext.indexOf(".")==0 )
			ext = ext.substr(1);
		storagePath.extension = ext;
	}


	/**
		Change the extension of the storage file (only works for platforms that have file system access).
	**/
	public function setStorageFileDir(dir:Null<String>) {
		storagePath.setDirectory( dir );
	}


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


	/** Build checksum for given string **/
	function makeCRC(data:String) {
		return haxe.crypto.Sha1.encode( data + haxe.crypto.Sha1.encode(data + CRC_SALT) ).substr(4, 32);
	}


	/**
		Read unparsed String for specified storage name
	**/
	function fromStorage() : Null<String> {
		var raw : Null<String> = {
			#if flash

				try flash.net.SharedObject.getLocal( storagePath.fileName ).data.content catch(e:Dynamic) null;

			#elseif( sys || hl || hxnodejs )

				#if hxnodejs
				try js.node.Fs.readFileSync(storagePath.full).toString() catch(e) null;
				#else
				try sys.io.File.getContent(storagePath.full) catch( e : Dynamic ) null;
				#end

			#elseif js

				var jsStorage = js.Browser.getLocalStorage();
				if( jsStorage!=null )
					jsStorage.getItem(storagePath.full);
				else
					null;

			#else

				throw "Platform not supported";

			#end
		}

		if( useCRC ) {
			// Check CRC
			var parts = raw.split(CRC_SEPARATOR);
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
	function toStorage(raw:String) : Bool {
		try {
			if( useCRC )
				raw = makeCRC(raw) + CRC_SEPARATOR + raw;

			#if flash

				var so = flash.net.SharedObject.getLocal( storagePath.fileName );
				so.data.content = raw;
				so.flush();

			#elseif( sys || hl || hxnodejs )

				#if hxnodejs

				if( storagePath.directory!=null && !js.node.Fs.existsSync(storagePath.directory) )
					js.node.Fs.mkdirSync(storagePath.directory);
				js.node.Fs.writeFileSync( storagePath.full, raw );

				#else

				if( storagePath.directory!=null && !sys.FileSystem.exists(storagePath.directory) )
					sys.FileSystem.createDirectory(storagePath.directory);
				sys.io.File.saveContent(storagePath.full, raw);

				#end

			#elseif js

				var jsStorage = js.Browser.getLocalStorage();
				if( jsStorage!=null )
					jsStorage.setItem(storagePath.fileName, raw);
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
	public function readString(?defValue:String) : Null<String> {
		var raw = fromStorage();
		return raw==null ? defValue : raw;
	}

	/**
		Save a String to specified storage.
	**/
	public function writeString(raw:String) {
		toStorage(raw);
	}

	/**
		Read an anonymous object right from storage.
	**/
	public function readObject<T>(?defValue:T) : T {
		var raw = fromStorage();
		if( raw==null )
			return defValue;
		else {
			var obj = switch format {
				case Json(prettyLevel): try haxe.Json.parse(raw) catch(_) null;
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
				case Json(prettyLevel):
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
	public function writeObject<T>(obj:T) {
		var str = switch format {
			case Json(prettyLevel):
				JsonPretty.stringify(obj, prettyLevel, UseEnumObject);

			case Serialized:
				haxe.Serializer.run(obj);
		}
		toStorage( str );
	}


	/**
		Return TRUE if the storage file exists on disk
	**/
	public function exists() : Bool {
		return
			try fromStorage()!=null
			catch( e:Dynamic ) false;
	}


	/**
		Remove storage file from disk
	**/
	public function delete() {
		try {
			#if flash

				var so = flash.net.SharedObject.getLocal( storagePath.fileName );
				if( so==null )
					return;
				so.clear();

			#elseif( sys || hl || hxnodejs )

				#if hxnodejs
				js.node.Fs.unlinkSync(storagePath.full);
				#else
				sys.FileSystem.deleteFile(storagePath.full);
				#end

			#elseif js

				js.Browser.window.localStorage.removeItem(storagePath.fileName);

			#else

				throw "Platform not supported";

			#end
		}
		catch( e:Dynamic ) {
		}
	}


	@:noCompletion
	public static function __test() {
		CiAssert.isTrue( isSupported() );

		var baseName = "localStorage";
		CiAssert.printIfVerbose("LocalStorage for Strings:");

		// String: default value
		var ls = createJsonStorage(baseName);
		ls.delete();
		var v = ls.readString("foo");
		CiAssert.isTrue( v!=null );
		CiAssert.equals( v, "foo" );

		// String: writing
		v = "bar";
		ls.writeString(v);
		CiAssert.equals( ls.exists(), true);

		// String: reading
		var saved = ls.readString();
		CiAssert.equals(saved, "bar");
		ls.delete();
		CiAssert.equals( ls.exists(), false );


		CiAssert.printIfVerbose("LocalStorage for objects:");

		// Default value test
		var ls = createJsonStorage(baseName+"_defObject");
		var testObj = ls.readObject({ a:0, b:10, str:"foo", enu:ValueA });
		CiAssert.equals( ls.exists(), false );
		CiAssert.isTrue( testObj!=null );
		CiAssert.equals( testObj.a, 0 );
		CiAssert.equals( testObj.b, 10 );
		CiAssert.equals( testObj.str, "foo" );
		CiAssert.equals( testObj.enu, ValueA );
		ls.delete();
		CiAssert.equals( ls.exists(), false );

		// Writing
		if( isSupported() ) {
			testObj.a++;
			testObj.b++;
			testObj.str = null;


			// Json format
			CiAssert.printIfVerbose("Json format:");
			var ls = createJsonStorage(baseName+"_json");
			CiAssert.equals( ls.exists(), false );
			ls.writeObject(testObj);
			CiAssert.equals( ls.exists(), true );

			var jsonLoaded = ls.readObject();
			CiAssert.equals( jsonLoaded.a, 1 );
			CiAssert.equals( jsonLoaded.b, 11 );
			CiAssert.equals( jsonLoaded.str, null );
			CiAssert.equals( jsonLoaded.enu, ValueA );
			ls.delete();
			CiAssert.equals( ls.exists(), false );


			// Json format with CRC
			CiAssert.printIfVerbose("Json format with CRC:");
			var ls = createJsonStorage(baseName+"_jsonCrc");
			ls.useCRC = true;
			ls.writeObject(testObj);
			CiAssert.equals( ls.exists(), true );

			var jsonLoaded = ls.readObject();
			CiAssert.equals( jsonLoaded.enu, ValueA );
			ls.delete();
			CiAssert.equals( ls.exists(), false );


			// Serialized format
			CiAssert.printIfVerbose("Serialized format:");
			var ls = createSerializedStorage(baseName+"_ser");
			ls.writeObject(testObj);
			CiAssert.equals( ls.exists(), true );

			var serializedLoaded = ls.readObject();
			CiAssert.equals( serializedLoaded.a, 1 );
			CiAssert.equals( serializedLoaded.b, 11 );
			CiAssert.equals( serializedLoaded.str, null );
			ls.delete();
			CiAssert.equals( ls.exists(), false );


			// Serialized format with CRC
			CiAssert.printIfVerbose("Serialized format:");
			var ls = createSerializedStorage(baseName+"_serCrc", true);
			ls.writeObject(testObj);
			CiAssert.equals( ls.exists(), true );

			var serializedLoaded = ls.readObject();
			CiAssert.equals( serializedLoaded.a, 1 );
			CiAssert.equals( serializedLoaded.b, 11 );
			CiAssert.equals( serializedLoaded.str, null );


			// Alter storage on disk to break CRC
			ls.useCRC = false;
			var alteredRaw = ls.fromStorage();
			alteredRaw+="_changed";
			ls.toStorage(alteredRaw);

			// Check CRC breaking
			ls.useCRC = true;
			var o : Dynamic = ls.readObject();
			CiAssert.equals( o, null );

			ls.delete();
			CiAssert.equals( ls.exists(), false );
		}
		else
			CiAssert.printIfVerbose("WARNING: LocalStorage isn't supported on this platform!");
	}
}

private enum StorageTestEnum {
	ValueA;
	ValueB;
	ValueC;
}

