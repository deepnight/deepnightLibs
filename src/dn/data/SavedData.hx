package dn.data;

enum SaveFormat {
	Serialized;
	SerializedCRC;
	Json;
}

/**
	A simple system to save and load data. The Serialized format is highly recommended as it supports mroe variable types.
**/
class SavedData {
	public static var DEFAULT_SAVE_FOLDER = "";
	public static var DEFAULT_FILE_EXT = "dnsav";

	/** This requires hlsteam API **/
	public static var USE_STEAM_CLOUD = false;


	public static function exists(name:String) {
		var raw = read(name);
		return raw!=null;
	}


	static var SALT = "s*al!t";
	static function makeCRC(data:String) {
		return haxe.crypto.Sha1.encode(data + haxe.crypto.Sha1.encode(data + SALT)).substr(4, 32);
	}


	/**
		Save given anonymous structure using specified SaveFormat. "Saving" has different meanings depending on current platform (write to disk, use cookies etc.)
	**/
	public static function save<T>(name:String, object:T, format:SaveFormat=Serialized) : Bool {
		if( !checkSupport(object, format) )
			return false;

		var ser : String = switch format {
			case Serialized:
				haxe.Serializer.run(object);

			case SerializedCRC:
				var ser = haxe.Serializer.run(object);
				var crc = makeCRC(ser);
				ser + "|||" + crc;

			case Json:
				haxe.Json.stringify(object, (k:Dynamic,v:Dynamic)->{
					switch Type.typeof(v) {
						case TEnum(e):
							var id:Dynamic = Std.string(v); // Enums are stored using name instead of index
							return id;

						case _:
							return v;
					}
				}, "\t");
		}
		return write(name, ser);
	}


	/**
		Load previously saved data, using provided "default" anonymous structure to add missing fields (doesn't work with anonymous objects nested in arrays, lists and maps).
	**/
	public static function load<T>(name:String, def:T, format:SaveFormat=Serialized, ?patchData:T->Void) : T {
		var ser = read(name);
		if( ser==null )
			return def;

		var loaded : T = switch format {
			case Serialized:
				try haxe.Unserializer.run(ser) catch(_) def;

			case SerializedCRC:
				var parts = ser.split("|||");
				var ser = parts[0];
				var crc = parts[1];
				if( crc!=makeCRC(ser) )
					def;
				else
					try haxe.Unserializer.run(ser) catch(_) def;

			case Json:
				try haxe.Json.parse(ser) catch(_) def;
		}

		// Update low-level data
		if( patchData!=null )
			patchData(loaded);

		function _iterateObj(defObj:Dynamic, loadObj:Dynamic) {
			for(k in Reflect.fields(defObj)) {
				var defVal : Dynamic = Reflect.field(defObj, k);

				// Missing field
				if( !Reflect.hasField(loadObj,k) ) {
					Reflect.setField(loadObj,k,defVal);
					continue;
				}

				var loadVal : Dynamic = Reflect.field(loadObj, k);

				// Crawl deeper
				switch Type.typeof(defVal) {
					case TObject:
						_iterateObj(defVal, loadVal);

					case TClass(Array):
						// not supported

					case _:
				}
			}
		}

		if( loaded==null )
			return def;

		// Upgrade loaded object by adding missing fields.
		// WARNING: objects nested in sub-arrays won't be crawled (nor upgraded)!
		_iterateObj(def, loaded);

		return loaded;
	}


	/**
		Deletes saved data under the given name.
	**/
	public static function delete(name:String) {
		// Steam cloud
		#if hlsteam
			if( USE_STEAM_CLOUD && steam.Cloud.isEnabled() && steam.Cloud.exists(name) ) {
				try steam.Cloud.delete(name) catch(_) return false;
				return true;
			}
		#end

		// Local
		#if sys
			var path = makeFilePath(name);
			try sys.FileSystem.deleteFile(path) catch(_) return false;
			return true;
		#else
			#error "SavedData is not yet supported on this platform.";
			return false;
		#end
	}



	/**
		Read raw data
	**/
	static function read(name:String) : Null<String> {
		// Steam cloud
		#if hlsteam
			if( USE_STEAM_CLOUD && steam.Cloud.isEnabled() && steam.Cloud.exists(name) ) {
				try {
					trace("found cloud for "+name);
					var bytes = steam.Cloud.read(name);
					if( bytes.length>0 ) {
						trace("returned cloud for "+name);
						return bytes.toString();
					}
				}
				catch(_) {}
			}
		#end

		// Local
		#if sys
			var ser = try sys.io.File.getContent( makeFilePath(name) ) catch(_) null;
			return ser;
		#else
			#error "SavedData is not yet supported on this platform.";
			return null;
		#end
	}


	/**
		Write raw data
	**/
	static function write(name:String, ser:String) : Bool {
		// Steam cloud
		#if hlsteam
			if( USE_STEAM_CLOUD && steam.Cloud.isEnabled() )
				steam.Cloud.write( name, haxe.io.Bytes.ofString(ser) );
		#end

		// Local
		#if sys
			// Create missing dir
			if( !sys.FileSystem.exists( getSaveFolder() ) ) {
				try sys.FileSystem.createDirectory( getSaveFolder() )
				catch(_) {
					trace("Couldn't create dir "+getSaveFolder());
					return false;
				}
			}

			try sys.io.File.saveContent( makeFilePath(name) , ser) catch(_) return false;
			return true;
		#else
			#error "SavedData is not yet supported on this platform.";
			return false;
		#end
	}


	static function getSaveFolder() {
		if( DEFAULT_SAVE_FOLDER==null || StringTools.trim(DEFAULT_SAVE_FOLDER)=="" )
			return ".";
		else
			return DEFAULT_SAVE_FOLDER;
	}

	static function makeFilePath(name:String) {
		return FilePath.fromDir( getSaveFolder() )+"/"+name+"."+DEFAULT_FILE_EXT;
	}


	/**
		Throws an exception if given anonymous struct contains fields that aren't supported in specified SaveFormat.
	**/
	public static function checkSupport(v:Dynamic, format:SaveFormat, throwIfFail=true) {

		inline function _unsupported(v:Dynamic) {
			if( throwIfFail )
				throw format+" format doesn't support value type "+Type.typeof(v);
			return false;
		}

		switch Type.typeof(v) {
			case TNull:
			case TInt:
			case TFloat:
			case TBool:

			case TClass(String):

			case TClass(Array):
				var arr : Array<Dynamic> = cast v;
				for(av in arr)
					if( !checkSupport(av, format) )
						return _unsupported(av);

			case TClass(haxe.ds.StringMap), TClass(haxe.ds.IntMap), TClass(List):
				if( format==Json )
					return _unsupported(v);

			case TClass(_):
				return false;

			case TObject:
				for(k in Reflect.fields(v)) {
					var ov = Reflect.field(v,k);
					if( !checkSupport(ov, format) )
						return _unsupported(ov);
				}

			case TEnum(e):
				if( format==Json )
					return _unsupported(v);

			case TFunction, TUnknown:
				return false;

		}

		return true;
	}
}