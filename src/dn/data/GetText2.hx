package dn.data;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

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
	public static var VERBOSE = false;

	/*******************************************************************************
		CLIENT-SIDE API
	 *******************************************************************************/

	var dict : Map<String,String> = new Map();

	public function new() {
	}

	public function readPo(bytes:haxe.io.Bytes) {
		var msgidReg = ~/msgid\s+"(.*?)"\s*$/i;
		var msgstrReg = ~/msgstr\s+"(.*?)"\s*$/i;
		var stringReg = ~/^\s*"(.*?)"\s*$/i;
		var commentReg = ~/^#.*?$/i;

		// Init
		dict = new Map();
		var raw = bytes.toString();
		var lines = raw.split("\n");

		var lastId = null;
		var pendingMsgId = false;
		var pendingMsgStr = false;
		for( line in lines ) {
			if( msgidReg.match(line) ) {
				// Found msgid
				pendingMsgId = true;
				pendingMsgStr = false;
				lastId = msgidReg.matched(1);
			}
			else if( msgstrReg.match(line) ) {
				// Found msgstr
				pendingMsgId = false;
				pendingMsgStr = true;
				dict.set(lastId, msgstrReg.matched(1));
			}
			else if( stringReg.match(line) ) {
				// Continue on multilines
				if( pendingMsgId )
					lastId+="\n"+stringReg.matched(1);
				else if( pendingMsgStr )
					dict.set(lastId, dict.get(lastId) + "\n"+stringReg.matched(1) );
			}
			else {
				// Anything else
				pendingMsgId = pendingMsgStr = false;
			}
		}
	}


	/**
		Get a localized text entry, with optional in-text variables.
		Examples:
		 - `myGetText._("New game")`
		 - `myGetText._("Hello ::user::, this text should be translated", { user:"foo" })`

	**/
	public macro function _(ethis:Expr, msgId:ExprOf<String>, ?vars:ExprOf<Dynamic>) {
		switch msgId.expr {

			case EConst(CString(v)):
				// Check variables in text
				if( v.indexOf("::")>=0 ) {
					var parts = v.split("::");
					if( parts.length%2==0 )
						Context.fatalError('Invalid "::" sequence', msgId.pos);
					var i = 0;
					var textVars = new Map();
					for(p in parts)
						if( i++%2!=0 )
							textVars.set(p,p);

					switch vars.expr {
						case EConst( CIdent("null") ):
							if( Lambda.count(textVars)>0 )
								Context.fatalError('Missing variable values', Context.currentPos());

						case EObjectDecl(fields):
							var fieldVars = new Map();
							for(f in fields)
								if( !textVars.exists(f.field) )
									Context.fatalError('Unused variable ${f.field}', vars.pos);
								else
									fieldVars.set(f.field,f.field);
							for(v in textVars)
								if( !fieldVars.exists(v) )
									Context.fatalError('Missing variable ${v}', vars.pos);

						case EConst(CString(s, _)):
							if( Lambda.count(textVars)!=1 )
								Context.fatalError('String can only be used when text contains exactly 1 variable', msgId.pos);
							vars.expr = EObjectDecl([{
								field: Lambda.array(textVars)[0],
								expr: macro $v{s},
							}]);

						case EConst(CIdent(s)):
							if( Lambda.count(textVars)!=1 )
								Context.fatalError('Variable can only be passed when text contains exactly 1 variable', msgId.pos);
							vars.expr = EObjectDecl([{
								field: Lambda.array(textVars)[0],
								expr: macro Std.string( $i{s} ),
							}]);

						case _:
							Context.fatalError("Only anonymous structures are accepted here", vars.pos);
					}

				}

			case _: Context.fatalError("Only constant String values are accepted here.", msgId.pos);
		}

		return macro $ethis.get( $msgId, $vars );
	}



	@:noCompletion
	public inline function get(msgId:String, ?vars:Dynamic) {
		var str = dict.exists(msgId) && dict.get(msgId)!="" ? dict.get(msgId) : msgId;
		if( vars!=null )
			for(k in Reflect.fields(vars))
				str = StringTools.replace(str, '::$k::', Std.string( Reflect.field(vars,k) ));
		return str;
	}



	/*******************************************************************************
		PARSERS AND GENERATORS
	 *******************************************************************************/

	#if( sys && !macro )
	static var SRC_REG = ~/\._\(\s*"((\\"|[^"])+)"/i;

	/**
		Parse HX files
	**/
	public static function parseSourceCode(dir:String) : Array<PoEntry> {
		if( VERBOSE ) Lib.println('');
		Lib.println('Parsing source code ($dir)...');
		var all : Array<PoEntry>= [];
		var files = listFilesRec(["hx"], dir);
		for(file in files) {
			var raw = sys.io.File.getContent(file);
			var n = 0;
			while( SRC_REG.match(raw) ) {
				var id = SRC_REG.matched(1);
				var e = new PoEntry(id);
				e.references.push(file);
				all.push(e);
				raw = SRC_REG.matchedRight();
				n++;
			}
			if( n>0 && VERBOSE )
				Lib.println('  - $file, $n entrie(s)');
		}
		return all;
	}

	/**
		Parse LDtk
	**/
	public static function parseLdtk(filePath:String, options:LdtkOptions) {
		if( VERBOSE ) Lib.println('');
		Lib.println('Parsing LDtk ($filePath)...');
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
				var globalContext = options.globalContext==null ? null : options.globalContext;
				var n = 0;

				// Load external level
				if( projectJson.externalLevels ) {
					levelPath = fp.directoryWithSlash + levelJson.externalRelPath;

					var raw = sys.io.File.getContent(levelPath);
					levelJson = try haxe.Json.parse(raw) catch(_) {
						error(levelPath, "Couldn't parse external level");
						null;
					}
				}

				// Level fields
				for(f in jsonArray(l.fieldInstances)) {
					if( levelLookup.exists(f.__identifier) ) {
						if( f.__value==null )
							continue;
						var e = new PoEntry(f.__value, globalContext);
						all.push(e);
						e.references.push(levelPath);
						e.comment = "Level_"+levelJson.identifier+"_"+f.__identifier;
						n++;
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
											n++;
										}
									}
									else {
										var e = new PoEntry(f.__value, globalContext);
										all.push(e);
										e.references.push(levelPath);
										e.comment = ctx + "_at_"+pt;
										n++;
									}
								}
							}
						case _:
					}
				}

				if( n>0 && VERBOSE )
					Lib.println('  - $levelPath, $n entrie(s)');
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



	#if castle
	public static function parseCastleDB(filePath:String, ?globalContext:String) {//, data:POData, cdbSpecialId: Array<{ereg: EReg, field: String}> ){
		if( VERBOSE ) Lib.println('');
		Lib.println('Parsing CastleDB ($filePath)...');
		globalContext = globalContext==null ? null : globalContext;
		var all : Array<PoEntry> = [];
		var cbdData = cdb.Parser.parse( sys.io.File.getContent(filePath), false );
		var columns = new Map<String,Array<Array<String>>>();
		for( sheet in cbdData.sheets ){
			var p = sheet.name.split("@");
			var sheetName = p.shift();
			if( !columns.exists(sheetName) )
				columns.set(sheetName,[]);
			var sheetColumns = columns.get(sheetName);

			var cid = p;

			for ( column in sheet.columns ) {
				if( Std.string(column.kind) == "localizable" && column.type == TString ){
					var p = p.copy();
					p.push( column.name );
					sheetColumns.push( p );
				}
			}
		}

		function exploreSheet( idx:String, id:Null<String>, lines:Array<Dynamic>, columns:Array<Array<String>> ){
			var n = 0;
			var i = 0;
			for( line in lines ){
				if( line.enabled == false || line.active == false )
					continue;

				for( col in columns ){
					var col = col.copy();
					var cname = col.shift();
					var id = id;
					if( line.id != null )
						id += " "+line.id;
					id += " ("+cname+")";
					if( col.length == 0 ) {
						var e = new PoEntry(Reflect.field(line,cname), "CastleDB");
						all.push(e);
						e.references.push(idx+"/#"+i+"."+cname);
						n++;
						// add( idx+"/#"+i+"."+cname, id, Reflect.field(line,cname) );
					}
					else
						exploreSheet( idx+"/#"+i+"."+cname, id, Reflect.field(line,cname), [col] );
				}
				i++;
			}

			if( n>0 && VERBOSE )
				Lib.println('  - $idx, $n entrie(s)');
		}

		for( sheet in cbdData.sheets ){
			var sColumns = columns.get(sheet.name);
			if( sColumns==null || sColumns.length == 0 )
				continue;

			exploreSheet( filePath+":"+sheet.name, "", sheet.lines, sColumns );
		}

		return all;
	}
	#end // end of castle


	/**
		Error found during parsing
	**/
	static inline function error(file:String, msg:String) {
		Lib.println("ERROR: "+(file!=null?file+": ":"") + msg);
		Sys.exit(-1);
	}


	/**
		Merge duplicate entries
	**/
	static function removeDuplicates(entries:Array<PoEntry>) {
		if( VERBOSE )
			Lib.println("Merging duplicates...");

		var dones : Map<String,PoEntry> = new Map();
		var i = 0;
		while( i<entries.length ) {
			var e = entries[i];
			if( dones.exists(e.uniqKey) ) {
				var orig = dones.get(e.uniqKey);
				orig.references = orig.references.concat(e.references);
				entries.splice(i,1);
				if( VERBOSE )
					Lib.println("  - Merged duplicate: "+e.uniqKey);
			}
			else {
				dones.set(e.uniqKey,e);
				i++;
			}
		}
	}


	static function formatPoString(str:String) {
		str = StringTools.replace(str, '"', '\"');
		str = StringTools.replace(str, "\n", "\\n");
		// var lines = str.split("\n");
		// str = lines.join('"\n"');
		return str;
	}


	/**
		Write a POT file from given PoEntries
	**/
	public static function writePOT(potPath:String, entries:Array<PoEntry>) {
		var potPath = FilePath.fromFile(potPath);
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
				lines.push('#: "$r"'); // TODO fix relative paths when POT is saved in a sub dir

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
		var fo = sys.io.File.write(potPath.full, false);
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

	#end // end of "if macro"
}



class PoEntry {
	public var msgid: String;
	public var msgstr = "";

	public var references : Array<String> = []; // #:
	public var comment : Null<String>; // #
	public var translatorNote : Null<String>; // #.
	public var contextDisamb : Null<String>; // msgctxt

	public var uniqKey(get,never) : String;

	public inline function new(rawId:String, ?ctx:String) {
		msgid = rawId;
		contextDisamb = ctx;

		// Extract translator note
		if( msgid.indexOf("||?")>0 ) {
			var parts = rawId.split("||?");
			msgid = parts[0];
			translatorNote = parts[1];
		}

		// Extract context disambiguation
		if( msgid.indexOf("||")>0 ) {
			var parts = rawId.split("||");
			msgid = parts[0];
			contextDisamb = parts[1];
		}

		if( GetText2.VERBOSE )
			Lib.println("    - New entry: "+msgid);
	}

	inline function get_uniqKey() {
		return msgid + (contextDisamb==null ? "" : "@"+contextDisamb);
	}

	@:keep public inline function toString() {
		return msgid + (contextDisamb==null?"":"@"+contextDisamb);
	}
}
