package dn.data;

enum SaveFormat {
	Serialized;
	Json;
}

/**
	A simple system to save and load data. The Serialized format is highly recommended as it supports mroe variable types.
**/
class SavedData {
	public static var DEFAULT_SAVE_FOLDER = "";
	public static var DEFAULT_FILE_EXT = "dnsav";


	/**
		Save given anonymous structure using specified SaveFormat. "Saving" has different meanings depending on current platform (write to disk, use cookies etc.)
	**/
	public static function save<T>(name:String, object:T, format:SaveFormat=Serialized) : Bool {
		if( !checkSupport(object, format) )
			return false;

		var ser = switch format {
			case Serialized:
				haxe.Serializer.run(object);

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
	public static function load<T>(name:String, def:T, format:SaveFormat=Serialized) : T {
		var ser = read(name);
		if( ser==null )
			return def;

		var loaded : T = switch format {
			case Serialized:
				try haxe.Unserializer.run(ser) catch(_) def;

			case Json:
				try haxe.Json.parse(ser) catch(_) def;
		}

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

		// Upgrade loaded object by adding missing fields.
		// WARNING: objects nested in sub-arrays won't be crawled (nor upgraded)!
		_iterateObj(def, loaded);

		return loaded;
	}



	/**
		Read raw data
	**/
	static function read(name:String) : Null<String> {
		#if sys

		var ser = try sys.io.File.getContent( makeFilePath(name) ) catch(_) null;
		return ser;

		#else

		#error "Requires Sys platform";
		trace("Unsupported on this platform");
		return null;

		#end
	}


	/**
		Write raw data
	**/
	static function write(name:String, ser:String) : Bool {
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

		#error "Requires Sys platform";
		trace("Unsupported on this platform");
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
	static function checkSupport(v:Dynamic, format:SaveFormat) {
		inline function _unsupported(v:Dynamic) {
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