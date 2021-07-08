package dn.data;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

/**
	Text entries might contain extra info:
		"bla bla||?general comment"
		"bla bla||!translator note"
		"bla bla||@context disambiguation"
	Reference: http://pology.nedohodnik.net/doc/user/en_US/ch-poformat.html
**/

private typedef LdtkOptions = {
	var entityFields : Array<LdtkEntityField>;
	var levelFieldIds : Array<String>;
	var ?globalComment:String;
}

private typedef LdtkEntityField = {
	var entityId : String;
	var fieldId : String;
}


class GetText2 {
	public static var VERBOSE = false;

	public static var CONTEXT_DISAMB_SEP = "||@";
	public static var COMMENT_REG = ~/(\|\|\?(.*?))($|\|\|)/i; //  ||?a comment
	public static var CONTEXT_DISAMB_REG = ~/(\|\|@(.*?))($|\|\|)/i; //  ||@some context
	public static var TRANSLATOR_NOTE_REG = ~/(\|\|!(.*?))($|\|\|)/i; //  ||!translator note

	/*******************************************************************************
		CLIENT-SIDE API
	 *******************************************************************************/

	/**
		Entries and their translations. Note that entry key might contain Context Disambiguation in the form of
		an added "||@some context" at the end of the string.
	**/
	var dict : Map<String,String> = new Map();

	public function new() {
	}

	public inline function getRawDict() : Map<String,String> return dict;

	public inline function getEntryCount() return Lambda.count(dict);

	public function readPo(bytes:haxe.io.Bytes) {
		var msgidReg = ~/^[ \t]*msgid[ \t]+"(.*?)"\s*$/i;
		var msgstrReg = ~/^[ \t]*msgstr[ \t]+"(.*?)"\s*$/i;
		var contextReg = ~/^[ \t]*msgctxt[ \t]+"(.*?)"\s*$/i;
		var stringReg = ~/^[ \t]*"(.*?)"[ \t]*$/i;
		var commentReg = ~/^#.*?$/i;

		// Init
		dict = new Map();
		var raw = bytes.toString();
		var lines = raw.split("\n");

		var lastId = null;
		var lastCtx = null;
		var pendingMsgId = false;
		var pendingMsgStr = false;
		for( line in lines ) {
			if( contextReg.match(line) ) {
				// Found msgctxt
				pendingMsgId = false;
				pendingMsgStr = false;
				lastCtx = unescapePoString( contextReg.matched(1) );
			}
			else if( msgidReg.match(line) ) {
				// Found msgid
				pendingMsgId = true;
				pendingMsgStr = false;
				lastId = unescapePoString( msgidReg.matched(1) );
			}
			else if( msgstrReg.match(line) ) {
				// Found msgstr
				pendingMsgId = false;
				pendingMsgStr = true;
				if( lastCtx!=null ) {
					lastId += CONTEXT_DISAMB_SEP + lastCtx;
					lastCtx = null;
				}
				dict.set(lastId, unescapePoString( msgstrReg.matched(1) ));
			}
			else if( stringReg.match(line) ) {
				// Continue on multilines
				if( pendingMsgId )
					lastId += unescapePoString( stringReg.matched(1) );
				else if( pendingMsgStr ) {
					dict.set(lastId, dict.get(lastId) + unescapePoString( stringReg.matched(1) ) );
				}
			}
			else {
				// Anything else
				pendingMsgId = pendingMsgStr = false;
			}
		}
	}


	static function escapePoString(str:String) {
		str = StringTools.replace(str, '"', '\"');
		str = StringTools.replace(str, "\n", "\\n");
		return str;
	}

	static function unescapePoString(str:String) {
		str = StringTools.replace(str, '\"', '"');
		str = StringTools.replace(str, "\\n", "\n");
		return str;
	}


	/**
		Get a localized text entry, with optional in-text variables.
		Examples:
		 - `myGetText._("New game")`
		 - `myGetText._("Hello ::user::, this text should be translated", { user:"foo" })`

	**/
	public macro function _(ethis:Expr, msgId:ExprOf<String>, ?vars:ExprOf<Dynamic>) : ExprOf<LocaleString> {
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


	/**
		Get a localized text entry, with optional in-text variables.
		Examples:
		 - `myGetText.get("New game")`
		 - `myGetText.get("Hello ::user::, this text should be translated", { user:"foo" })`

	**/
	public inline function get(msgId:String, ?vars:Dynamic) : LocaleString {
		// Strip notes from msgid (but keep Disambiguation Context)
		msgId = TRANSLATOR_NOTE_REG.replace(msgId,"$3");
		msgId = COMMENT_REG.replace(msgId,"$3");

		var str = dict.exists(msgId) && dict.get(msgId)!="" ? dict.get(msgId) : msgId;

		// In-text variables
		if( vars!=null )
			for(k in Reflect.fields(vars))
				str = StringTools.replace(str, '::$k::', Std.string( Reflect.field(vars,k) ));

		// Strip notes from output
		str = TRANSLATOR_NOTE_REG.replace(str,"$3");
		str = COMMENT_REG.replace(str,"$3");
		str = CONTEXT_DISAMB_REG.replace(str,"$3");

		return untranslated(str);
	}


	/**
		Return TRUE if given string has a translated version.
	**/
	public inline function hasTranslation(msgId:String) {
		return dict.exists(msgId);
	}


	/**
		Turn any value to a LocaleString type, which is useful to keep function type parameters clean.
		Example: if you have method that expects a LocaleString (eg. `sayMessage(msg:LocaleString)`),
		you can pass parameters that are not supposed to be translated by doing
		`sayMessage( myGetText.untranslated("Do not translate") )`. The "Do not translate" string will be
		passed as-is and will not be exported in PO during extraction.
	**/
	public inline function untranslated(str:Dynamic) : LocaleString {
		return new LocaleString( Std.string(str) );
	}


	/**
		Check current translated data and return an array of error descriptions if any anomaly is
		found. Verification includes in-text variables syntax (eg. "::varName::") and missing translations.

		If provided, `reference` will be used to check for missing entries in current dictionary.

		`checkEntry` is an optional method to be tested against all values in current translated
		data: it should return an error description if an anomaly is found, or `null` otherwise.
	**/
	public function check( ?reference:GetText2, ?checkEntry:(msgId:String, translation:String)->Null<String> ) : Array<String> {
		var errors = [];
		inline function _error(msgId:String, err:String) {
			errors.push('In "$msgId"  =>  '+err);
		}

		try {
			// Compare with reference
			var refKeys = new Map();
			if( reference!=null ) {
				// List keys from reference
				for(k in reference.getRawDict().keys())
					refKeys.set(k,k);

				// Count check
				var nref = Lambda.count(refKeys);
				var ngt = getEntryCount();
				if( nref!=ngt )
					errors.push('Entry count in this file ($ngt) differs from reference file ($nref)');
			}

			// Check all entries
			var missing = [];
			for( e in dict.keyValueIterator() ) {
				if( e.value=="" ) {
					missing.push(e.key);
					continue;
				}

				// Entry not found in reference
				if( reference!=null && !refKeys.exists(e.key) )
					_error(e.key, 'Not in reference file');

				// "::" count mismatch
				if( e.key.split("::").length != e.value.split("::").length ) {
					_error(e.key, 'Malformed variable (verify the "::")');
					continue;
				}

				// List variable names
				var map = new Map();
				var odd = true;
				for(v in e.key.split("::")) {
					if( !odd )
						map.set(v,v);
					odd = !odd;
				}

				// Check missings
				odd = true;
				for(v in e.value.split("::")) {
					if( !odd && !map.exists(v) )
						_error(e.key, 'Incorrect variable name ::$v::');

					odd = !odd;
				}

				// Custom check
				if( checkEntry!=null ) {
					var err = checkEntry(e.key,e.value);
					if( err!=null )
						_error(e.key, err);
				}
			}

			// Missing translations
			if( missing.length>0 ) {
				if( missing.length>5 )
					errors.push('${missing.length} missing translations');
				else
					for(k in missing)
						_error(k, "Missing translation");
			}
		}
		catch(e) {
			errors.push("EXCEPTION: "+e);
		}
		return errors;
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
				var globalComment = options.globalComment==null ? "Level design" : options.globalComment;
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
						var e = new PoEntry(f.__value);
						all.push(e);
						e.addComment(globalComment);
						e.references.push(levelPath);
						e.addComment("Level_"+levelJson.identifier+"_"+f.__identifier);
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
											var e = new PoEntry(v);
											all.push(e);
											e.addComment(globalComment);
											e.references.push(levelPath);
											e.addComment(ctx + ( values.length>1 ? "_"+(i++) : "" ) + "_at_"+pt);
											n++;
										}
									}
									else {
										var e = new PoEntry(f.__value);
										all.push(e);
										if( globalComment!=null )
											e.addComment(globalComment);
										e.references.push(levelPath);
										e.addComment(ctx + "_at_"+pt);
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
	public static function parseCastleDB(filePath:String, ?globalComment="CastleDB") {//, data:POData, cdbSpecialId: Array<{ereg: EReg, field: String}> ){
		if( VERBOSE ) Lib.println('');
		Lib.println('Parsing CastleDB ($filePath)...');
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
				// Found a duplicate
				var orig = dones.get(e.uniqKey);
				if( e.comment!=null )
					orig.addComment(e.comment);

				if( e.translatorNote!=null )
					orig.addTranslatorNote(e.translatorNote);

				for(r in e.references)
					orig.references.push(r);

				entries.splice(i,1);
				if( VERBOSE )
					Lib.println("  - Merged duplicate: "+e.uniqKey);
			}
			else {
				// Found a new entry
				dones.set(e.uniqKey,e);
				i++;
			}
		}
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
				lines.push('msgctxt "${escapePoString(e.contextDisamb)}"');

			// String
			lines.push('msgid "${escapePoString(e.msgid)}"');
			lines.push('msgstr "${escapePoString(e.msgstr)}"');
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

	public var references(default,null) : Array<String> = []; // #:
	public var comment(default,null) : Null<String>; // #
	public var translatorNote(default,null) : Null<String>; // #.
	public var contextDisamb(default,null) : Null<String>; // msgctxt

	public var uniqKey(get,never) : String;

	public inline function new(rawId:String, ?ctx:String) {
		msgid = rawId;
		contextDisamb = ctx;

		// Extract and strip translator note
		if( GetText2.TRANSLATOR_NOTE_REG.match(msgid) ) {
			msgid = GetText2.TRANSLATOR_NOTE_REG.replace(msgid,	"$3");
			translatorNote = GetText2.TRANSLATOR_NOTE_REG.matched(2);
		}

		// Extract and strip context disambiguation
		if( GetText2.CONTEXT_DISAMB_REG.match(msgid) ) {
			msgid = GetText2.CONTEXT_DISAMB_REG.replace(msgid,	"$3");
			contextDisamb = GetText2.CONTEXT_DISAMB_REG.matched(2);
		}

		// Extract and strip context disambiguation
		if( GetText2.COMMENT_REG.match(msgid) ) {
			msgid = GetText2.COMMENT_REG.replace(msgid,	"$3");
			comment = GetText2.COMMENT_REG.matched(2);
		}

		if( GetText2.VERBOSE )
			Lib.println("    - New entry: "+msgid);
	}

	public function addComment(str:String) {
		if( comment==null )
			comment = str;
		else
			comment+=" ; "+str;
	}

	public function addTranslatorNote(str:String) {
		if( translatorNote==null )
			translatorNote = str;
		else
			translatorNote+=" ; "+str;
	}

	public function addContextDisambiguation(str:String) {
		if( contextDisamb==null )
			contextDisamb = str;
		else
			contextDisamb+=" ; "+str;
	}

	inline function get_uniqKey() {
		return msgid + ( contextDisamb==null ? "" : GetText2.CONTEXT_DISAMB_SEP+contextDisamb );
	}

	@:keep public inline function toString() {
		return uniqKey;
	}
}



abstract LocaleString(String) to String {
	inline public function new(s:String) {
		this = s;
	}

	public inline function toUpperCase() : LocaleString return new LocaleString(this.toUpperCase());
	public inline function toLowerCase() : LocaleString return new LocaleString(this.toLowerCase());
	public inline function charAt(i) return this.charAt(i);
	public inline function charCodeAt(i) return this.charCodeAt(i);
	public inline function indexOf(i, ?s) return this.indexOf(i,s);
	public inline function lastIndexOf(i, ?s) return this.lastIndexOf(i,s);
	public inline function split(i) return this.split(i);
	public inline function substr(i, ?l) return this.substr(i, l);
	public inline function substring(i, ?e) return this.substring(i, e);

	public inline function trim(){
        return new LocaleString( StringTools.trim(this) );
    }

	@:op(A+B) function add(to:LocaleString) return new LocaleString(this + cast to);

	public var length(get,never) : Int;
	inline function get_length() return this.length;

	#if heaps
	@:to
	inline function toUString() : String {
		return (cast this:String);
	}
	#end
}