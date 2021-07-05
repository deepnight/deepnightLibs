package dn.data;

/**
	Reference: http://pology.nedohodnik.net/doc/user/en_US/ch-poformat.html
**/

private typedef LdtkOptions = {
	var entityFields : Array<LdtkEntityField>;
	var levelFieldIds : Array<String>;
	var ?globalContext:String;
}

private typedef LdtkEntityField = {
	var entityId : String;
	var fieldId : String;
}


class GetText2 {
	#if sys
	static var ERRORS : Array<String> = [];
	static var SRC_REG = ~/\._\(\s*"((\\"|[^"])+)"/i;

	/**
		Parse HX files
	**/
	public static function parseSourceCode(dir:String) : Array<PoEntry> {
		var all : Array<PoEntry>= [];
		var files = listFilesRec(["hx"], dir);
		for(file in files) {
			var raw = sys.io.File.getContent(file);
			while( SRC_REG.match(raw) ) {
				var id = SRC_REG.matched(1);
				var e = new PoEntry(id);
				e.references.push(file);
				all.push(e);
				raw = SRC_REG.matchedRight();
			}
		}
		return all;
	}

	/**
		Parse LDtk
	**/
	public static function parseLdtk(filePath:String, options:LdtkOptions) {
		var all : Array<PoEntry> = [];
		if( !sys.FileSystem.exists(filePath) )
			error(filePath, "File not found: "+filePath);
		else {
			// Create lookup Maps
			var entityLookup = new Map();
			for(ef in options.entityFields) {
				if( !entityLookup.exists(ef.entityId) )
					entityLookup.set(ef.entityId, new Map());
				entityLookup.get(ef.entityId).set(ef.fieldId, true);
			}
			var levelLookup = new Map();
			for(f in options.levelFieldIds)
				levelLookup.set(f, true);

			// Parse LDtk project file
			var fp = FilePath.fromFile(filePath);
			var projectJson = try haxe.Json.parse( sys.io.File.getContent(filePath) ) catch(_) null;

			// Iterate levels
			for(l in jsonArray(projectJson.levels)) {
				var levelJson : Dynamic = l;
				var levelPath = filePath;
				var globalContext = options.globalContext==null ? '$filePath' : options.globalContext;

				for(f in jsonArray(l.fieldInstances)) {
					if( levelLookup.exists(f.__identifier) ) {
						if( f.__value==null )
							continue;
						var e = new PoEntry(f.__value, globalContext);
						all.push(e);
						e.references.push(levelPath);
						e.comment = "Level_"+levelJson.identifier+"_"+f.__identifier;
					}
				}

				// Load external level
				if( projectJson.externalLevels ) {
					levelPath = fp.directoryWithSlash + levelJson.externalRelPath;

					var raw = sys.io.File.getContent(levelPath);
					levelJson = try haxe.Json.parse(raw) catch(_) {
						error(levelPath, "Couldn't parse external level");
						null;
					}
				}

				// Iterate layers
				for( layer in jsonArray(levelJson.layerInstances) ) {
					var type : String = layer.__type;
					switch type {
						case "Entities":

							// Iterate entities
							for(e in jsonArray(layer.entityInstances)) {
								if( !entityLookup.exists(e.__identifier) )
									continue;
								// Iterate fields
								for(f in jsonArray(e.fieldInstances)) {
									if( !entityLookup.get(e.__identifier).exists(f.__identifier) )
										continue;
									// Found localizable field
									var pt = jsonArray(e.__grid)[0]+"_"+jsonArray(e.__grid)[1];
									var ctx = "Level_"+levelJson.identifier+"_"+e.__identifier;
									if( isArray(f.__value) ) {
										// Array of strings
										var i = 0;
										var values = jsonArray(f.__value);
										for( v in values ) {
											var e = new PoEntry(v, globalContext);
											all.push(e);
											e.references.push(levelPath);
											e.comment = ctx + ( values.length>1 ? "_"+(i++) : "" ) + "_at_"+pt;
										}
									}
									else {
										var e = new PoEntry(f.__value, globalContext);
										all.push(e);
										e.references.push(levelPath);
										e.comment = ctx + "_at_"+pt;
									}
								}
							}
						case _:
					}
				}
			}
		}

		return all;
	}
	static inline function jsonArray(arr:Dynamic) : Array<Dynamic> {
		return arr==null ? [] : switch Type.typeof(arr) {
			case TClass(Array): cast arr;
			case _: [];
		}
	}
	static inline function isArray(v:Dynamic) {
		return v==null ? false : switch Type.typeof(v) {
			case TClass(Array): true;
			case _: false;
		}
	}


	static inline function error(file:String, msg:String) {
		Lib.println((file!=null?file+": ":"") + msg);
		Sys.exit(-1);
	}


	/**
		Merge duplicate entries
	**/
	static function removeDuplicates(entries:Array<PoEntry>) {
		var dones : Map<String,PoEntry> = new Map();
		var i = 0;
		while( i<entries.length ) {
			var e = entries[i];
			var k = e.getKey();
			if( dones.exists(k) ) {
				var orig = dones.get(k);
				orig.references = orig.references.concat(e.references);
				entries.splice(i,1);
			}
			else {
				dones.set(k,e);
				i++;
			}
		}
	}


	static function formatPoString(str:String) {
		str = StringTools.replace(str, '"', '\"');
		// var lines = str.split("\n");
		// str = lines.join('"\n"');
		return str;
	}


	/**
		Write a POT file from given PoEntries
	**/
	public static function writePOT(potPath:String, entries:Array<PoEntry>) {
		removeDuplicates(entries);

		var lines = [
			'msgid ""',
			'msgstr ""',
			'"Content-Type: text/plain; charset=UTF-8\\n"',
			'"Content-Transfer-Encoding: 8bit\\n"',
			'""MIME-Version: 1.0\\n"',
			'\n',
		];

		for(e in entries) {
			// References
			for(r in e.references)
				lines.push('#: "$r"');

			// Translator note
			if( e.translatorNote!=null )
				lines.push('#. ${e.translatorNote}');

			// Comment
			if( e.comment!=null )
				lines.push('# ${e.comment}');

			// Context disambiguation
			if( e.contextDisamb!=null )
				lines.push('msgctxt "${formatPoString(e.contextDisamb)}"');

			// String
			lines.push('msgid "${formatPoString(e.msgid)}"');
			lines.push('msgstr "${formatPoString(e.msgstr)}"');
			lines.push('');
		}

		// Write file
		var fo = sys.io.File.write(potPath, false);
		fo.writeString(lines.join("\n"));
		fo.close();
	}


	/**
		List all files in given dir (and sub dirs)
	**/
	static function listFilesRec(exts:Array<String>, dir:String) {
		var all = [];
		var pending = [dir];
		while( pending.length>0 ) {
			var dir = pending.shift();
			for(name in sys.FileSystem.readDirectory(dir)) {
				var path = dir+"/"+name;
				if( sys.FileSystem.isDirectory(path) )
					pending.push(path);
				else {
					for(e in exts)
						if( name.indexOf("."+e) == name.length-1-e.length )
							all.push(path);
				}
			}
		}
		return all;
	}
	#end
}



class PoEntry {
	public var msgid: String;
	public var msgstr = "";

	public var references : Array<String> = []; // #:
	public var comment : Null<String>; // #
	public var translatorNote : Null<String>; // #.
	public var contextDisamb : Null<String>; // msgctxt

	public inline function new(rawId:String, ?ctx:String) {
		msgid = rawId;
		contextDisamb = ctx;

		// Extract translator note
		if( msgid.indexOf("||?")>0 ) {
			var parts = rawId.split("||?");
			msgid = parts[0];
			translatorNote = parts[1];
		}

		// Extract custom context
		if( msgid.indexOf("||")>0 ) {
			var parts = rawId.split("||");
			msgid = parts[0];
			contextDisamb = parts[1];
		}
	}

	public inline function getKey() {
		return msgid + (contextDisamb==null ? "" : "@"+contextDisamb);
	}

	@:keep public inline function toString() {
		return msgid + (contextDisamb==null?"":"@"+contextDisamb);
	}
}
