package dn.data;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

#if potools

typedef POData = Array<POEntry>;

typedef POEntry = {
	id: Null<String>,
	str: Null<String>,

	?msgid: Null<String>,
	?msgstr: Null<String>,

	?cTranslator: String,
	?cExtracted: String,
	?cRef: String,
	?cFlags: String,
	?cPrevious : String,
	?cComment: String,
}

#end

#if( !flash && !hl )
typedef LocaleString = String;
#else
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
#end

class GetText {
	public static var CONTEXT = "||";

	var texts : Map<String,LocaleString>;


	public function toString() {
		return "GetText";
	}

	public function untranslated(str:Dynamic) : LocaleString {
		return new LocaleString(Std.string(str));
	}

	public macro function _(ethis:Expr, estr:ExprOf<String>, ?params:ExprOf<Dynamic>) {
		var str = switch(estr.expr) {
			case EConst(CString(s)) : s;
			default :
				Context.error("Constant string expected here!", estr.pos);
		}

		var odd = false;
		var hasVars = false;
		var strVars = [];
		for(s in str.split("::")) {
			odd = !odd;
			if( !odd ) {
				hasVars = true;
				strVars.push(s);
			}
		}

		switch( params.expr ) {
			case EObjectDecl(fields) :

				var vmap = new Map();
				for(f in fields) {
					if( str.indexOf("::"+f.field+"::")<0 )
						Context.error("Variable "+f.field+" not found in the string!", f.expr.pos);
					vmap.set(f.field, true);
					f.field = "_"+f.field;
				}

				for(k in strVars)
					if( !vmap.exists(k) )
						Context.error("String requires field "+k, params.pos);

				params = { expr:EObjectDecl(fields), pos:params.pos };

			case EConst(CIdent("null")) :
				if( hasVars )
					Context.error("Missing params: "+strVars.join(", "), params.pos);

			default :
				Context.error("Anonymous object expected here!", params.pos);
		}


		return macro $ethis.get($estr,$params);
	}

	inline static function stripContext( str : String ) : String {
		return StringTools.rtrim( str.split(CONTEXT)[0] );
	}

	@:noCompletion public function get(str:Null<String>, ?params:Dynamic) : Null<LocaleString> {
		if(texts == null) throw "no data in dictionnary";
		if( str==null ) return null;

		if(texts.exists(str))
			str = texts.get(str);
		else{
			var str2 = stripContext(str);
			if( texts.exists(str2) )
				str = texts.get(str2);
		}

		str = stripContext(str);

		var list = str.split("::");
		var n = 0;
		if(params!=null){
			for( k in Reflect.fields(params) ) {
				str = StringTools.replace(
					str,
					"::"+(k.charAt(0)=="_"?k.substr(1):k)+"::",
					Std.string( Reflect.field(params, k) )
				);
			}
		}

		return new LocaleString(str);
	}

	public function readMo(data:haxe.io.Bytes) {
		var r = new MoReader(data);
		texts = r.parse();
	}

	public function readNextMo(data:haxe.io.Bytes){
		var r = new MoReader(data).parse();
		for( k in texts.keys() ){
			var v = texts.get(k);
			if( r.exists(v) )
				texts.set(k, r.get(v));
			else {
				var v2 = stripContext(v);
				if( r.exists(v2) )
					texts.set(k, r.get(v2));
			}
		}
	}

	public function checkMoSyntax(fileName:String, data:haxe.io.Bytes) {
		var r =  new MoReader(data);
		var warnings = checkSyntax( r.parse() );
		for( w in warnings )
			trace('[GetText:$fileName] Warning: $w');
	}

	public static function checkSyntax( texts:Map<String,LocaleString> ) {
		var warnings = [];
		for(k in texts.keys()) {
			var t = texts.get(k);
			if( t.indexOf("::")>=0 && t.split("::").length%2==0 )
				warnings.push("Invalid \"::\" sequence in \""+t+"\"");

			var odd = false;
			var strVars = [];
			for(s in k.split("::")) {
				if( !(odd = !odd) ) strVars.push(s);
			}

			odd = false;
			for(s in t.split("::")) {
				if( !(odd = !odd) ){
					if( !strVars.remove(s) )
						warnings.push('Invalid variable $s in: "$t"');
				}
			}
			for( v in strVars )
				warnings.push('Missing variable $v in: "$t"');
		}
		return warnings;
	}

	public function emptyDictionary(){
		texts = new Map();
	}


	public function new() {
	}

	#if potools

	#if castle
	public static function doParseGlobal( conf: {?codePath:String, ?codeIgnore:EReg, potFile:String, ?deprecatedFile: String, ?cdbFiles:Array<String>, ?refPoFile:String, ?refDeprecatedPoFile: String, ?cdbSpecialId: Array<{ereg: EReg, field: String}>} ){

		var data : POData = [];
		data.push( POTools.mkHeaders([
			"MIME-Version" => "1.0",
			"Content-Type" => "text/plain; charset=UTF-8",
			"Content-Transfer-Encoding" => "8bit"
		]) );
		var strMap : Map<String,Bool> = new Map();

		if( conf.codePath != null ){
			Sys.println("[GetText] Parsing source code...");
			explore(conf.codePath, data, strMap, conf.codeIgnore);
		}

		if( conf.cdbFiles != null ){
			Sys.println("[GetText] Parsing CDBs...");
			exploreCDB(conf.cdbFiles, data, strMap, conf.cdbSpecialId);
		}

		if( conf.deprecatedFile != null ){
			Sys.println("[GetText] Keep deprecated strings");
			includeDeprecated(conf.deprecatedFile, data, strMap);
		}

		Sys.println("[GetText] Saving POT file ("+conf.potFile+")...");
		POTools.exportFile( conf.potFile, data );

		var ret = data.map(entry -> POTools.cloneEntry(entry));

		if( conf.refPoFile != null ){
			if( !sys.FileSystem.exists(conf.refPoFile) ){
				Sys.println("[GetText] Warning: File not found: "+conf.refPoFile );
			}else{
				Sys.println("[GetText] Saving Translated-POT file...");
				POTools.exportTranslatedFile(data, conf.potFile, conf.refPoFile, conf.refDeprecatedPoFile);
			}
		}

		Sys.println("[GetText] done.");

		return ret;
	}
	#end

	static var errors = [];
	public static inline function error(path:String, idx:Dynamic, err:String) {
		errors.push('[$path:$idx] ERROR: $err');
	}
	public static function haltIfErrors() {
		if( errors.length==0 )
			return;

		for(e in errors)
			Sys.println(e);
		throw "Found "+errors.length+" error(s).";
	}
	public static inline function fatal(path:String, idx:Dynamic, err:String) {
		throw '[$path:$idx] FATAL: $err';
	}

	static function explore(folder:String, data:POData, strMap:Map<String,Bool>, ?codeIgnore: EReg) {
		// Test it: http://regexr.com/
		var strReg = ~/\._\([ ]*"((\\"|[^"])+)"/i;
		var stack = [folder];

		while( stack.length > 0 ){
			var folder = stack.shift();
			for( f in sys.FileSystem.readDirectory(folder) ) {
				var path = folder+"/"+f;
				if( codeIgnore != null && codeIgnore.match(path) ){
					trace("Ignore: "+path);
					continue;
				}

				// Parse sub folders
				if( sys.FileSystem.isDirectory(path) ) {
					stack.push(path);
					continue;
				}

				// Ignore non-sourcecode
				if( f.substr(f.length - 3) != ".hx" )
					continue;

				// Read lines
				var c = sys.io.File.getContent(path);
				var n = 0;
				for( line in c.split("\n") ) {
					n++;
					if( line == "" )
						continue;

					var pos = 0;
					while( strReg.match(line.substr(pos)) ) {
						var str = strReg.matched(1);
						try {
						pos += strReg.matchedPos().pos + strReg.matchedPos().len;
						} catch(e:Dynamic) {
							fatal(f,n,e);
						}

						// Ignore commented strings
						var i = line.indexOf("//");
						if( i>=0 && i<strReg.matchedPos().pos )
							break;

						var cleanedStr = str;

						// Translator comment
						var comment : String = null;
						if( cleanedStr.indexOf(CONTEXT)>=0 ) {
							var parts = cleanedStr.split(CONTEXT);
							if( parts.length!=2 ) {
								error(f,n,"Malformed translator comment");
								continue;
							}
							if( parts[0].length != StringTools.rtrim(parts[0]).length ||
								parts[1].length != StringTools.trim(parts[1]).length ) {
									error(f,n,"Any SPACE character around \""+CONTEXT+"\" will lead to translation overlaps");
									continue;
								}
							comment = StringTools.trim(parts[1]);
							cleanedStr = cleanedStr.substr(0,cleanedStr.indexOf(CONTEXT));
						}
						cleanedStr = StringTools.rtrim(cleanedStr);

						// New entry found
						if( !strMap.exists(cleanedStr) ) {
							strMap.set(cleanedStr, true);
							data.push({
								id			: cleanedStr,
								str			: "",
								cRef		: path+":"+n,
								cExtracted	: comment,
							});
						}else{
							var previous = Lambda.find(data,function(e) return e.id==cleanedStr && e.cExtracted==comment);
							if( previous != null && previous.cExtracted == comment ){
								previous.cRef += " "+path+":"+n;
							}else{
								// if( previous != null && previous.cExtracted != null && previous.cExtracted.length > 0 ){
								// 	previous.id += " "+CONTEXT+" "+previous.cExtracted;
								// }
								// if( comment != null && comment.length > 0 ){
								// 	cleanedStr += " || " + comment;
								// }
								data.push({
									id			: cleanedStr,
									str			: "",
									cRef		: path+":"+n,
									cExtracted	: comment,
								});
							}
						}
					}
				}
			}
		}
		haltIfErrors();
	}

	#if castle
	static function exploreCDB( filesList:Array<String>, data:POData, strMap:Map<String,Bool>, ?cdbSpecialId: Array<{ereg: EReg, field: String}> ){
		for( file in filesList ){
			Sys.println("  -> "+file);
			var cbdData = cdb.Parser.parse( sys.io.File.getContent(file), false );
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

			function add( idx:String, id:String, str : String ){
				if( str==null || str.length == 0 )
					return;

				var cleanedStr = str;
				var comment : String = "";
				if( cleanedStr.indexOf(CONTEXT)>=0 ) {
					var parts = cleanedStr.split(CONTEXT);
					if( parts.length!=2 ) {
						error(file,idx,"Malformed translator comment");
					}
					comment = StringTools.trim(parts[1]);
					cleanedStr = cleanedStr.substr(0,cleanedStr.indexOf(CONTEXT));
				}
				cleanedStr = POTools.escape(StringTools.rtrim(cleanedStr));

				if( !strMap.exists(cleanedStr) ) {
					strMap.set(cleanedStr, true);
					if (comment.length > 0)
						data.push({
							id			: cleanedStr,
							str			: "",
							cRef		: idx,
							cExtracted	: comment,
						});
					else
						data.push({
							id			: cleanedStr,
							str			: "",
							cRef		: idx,
						});
				}else{
					var previous = Lambda.find(data,function(e) return e.id==cleanedStr);
					if( previous != null )
						previous.cRef += " "+idx;
				}
			}

			function exploreSheet( idx:String, id:Null<String>, lines:Array<Dynamic>, columns:Array<Array<String>> ){
				var i = 0;
				for( line in lines ){
					if( line.enabled == false || line.active == false )
						continue;
					for( col in columns ){
						var col = col.copy();
						var cname = col.shift();
						var id = id;
						var specialFound = false;
						if( cdbSpecialId != null ){
							for( special in cdbSpecialId ){
								if( special.ereg.match(idx) ){
									id += " " + Reflect.field(line, special.field);
									specialFound = true;
									break;
								}
							}
						}
						if( !specialFound && line.id != null )
							id += " "+line.id;
						id += " ("+cname+")";
						if( col.length == 0 ){
							add( idx+"/#"+i+"."+cname, id, Reflect.field(line,cname) );
						}else{
							exploreSheet( idx+"/#"+i+"."+cname, id, Reflect.field(line,cname), [col] );
						}
					}
					i++;
				}
			}

			for( sheet in cbdData.sheets ){
				var sColumns = columns.get(sheet.name);
				if( sColumns==null || sColumns.length == 0 )
					continue;

				exploreSheet( file+":"+sheet.name, "", sheet.lines, sColumns );
			}
		}
	}
	#end // end of castle

	static function includeDeprecated( file : String, data : POData, strMap:Map<String,Bool> ){
		var depreData = POTools.parseFile( file );

		for( entry in depreData ){
			if( entry.id == null || entry.id == "" ) continue;
			if( strMap.exists(entry.id) ) continue;

			strMap.set(entry.id, true);
			entry.cRef = null;
			entry.cExtracted = entry.cExtracted==null ? "Deprecated" : "Deprecated\n"+entry.cExtracted;
			data.push(entry);
		}
	}

	#end // end of potools


	@:noCompletion
	public static function __test() {
		#if( !macro && deepnightLibsTests )
		Lib.println("Testing GetText");

		var res = haxe.Resource.getString("data");
		CiAssert.isNotNull(res);
		CiAssert.noException( "PO loading", { Data.load(res); } );

		var gt = new GetText();
		var res = haxe.Resource.getBytes("frmo");
		CiAssert.isNotNull( res );
		CiAssert.noException( "MO reading", { gt.readMo(res); });

		Lib.println("------ Normal text in code ------");
		Lib.println(gt._("Normal text"));
		CiAssert.isTrue(gt._("Normal text") == "Texte normal");
		Lib.println(gt._("Text with commentary||I'm the commentary"));
		CiAssert.isTrue(gt._("Text with commentary||I'm the commentary") == "Texte avec commentaire");
		Lib.println(gt._("Text with parameters: ::param::", {param:"Test"}));
		CiAssert.isTrue(gt._("Text with parameters: ::param::", {param:"Test"}) == "Texte avec paramètres: Test");
		Lib.println(gt._("Text with parameters: ::param:: and commentary||Commentary", {param:"Test"}));
		CiAssert.isTrue(gt._("Text with parameters: ::param:: and commentary||Commentary", {param:"Test"}) == "Texte avec paramètres: Test et commentaire");

		Lib.println("------ CDB Text ------");
		Lib.println(gt.get(Data.texts.get(Data.TextsKind.test_1).text));
		CiAssert.isTrue(gt.get(Data.texts.get(Data.TextsKind.test_1).text) == "Je suis un texte CDB");
		Lib.println(gt.get(Data.texts.get(Data.TextsKind.test_2).text));
		CiAssert.isTrue(gt.get(Data.texts.get(Data.TextsKind.test_2).text) == "Je suis un texte CDB avec commentaire");
		Lib.println(gt.get(Data.texts.get(Data.TextsKind.test_3).text, {param:"Test"}));
		CiAssert.isTrue(gt.get(Data.texts.get(Data.TextsKind.test_3).text, {param:"Test"}) == "Je suis un texte CDB avec paramètre: Test");
		Lib.println(gt.get(Data.texts.get(Data.TextsKind.test_4).text, {param:"Test"}));
		CiAssert.isTrue(gt.get(Data.texts.get(Data.TextsKind.test_4).text, {param:"Test"}) == "Je suis un texte CDB avec paramètre: Test et commentaire");
		#end
	}
}

/**
 * GNU GetText MO file reader
 * @doc https://www.gnu.org/software/gettext/manual/html_node/MO-Files.html
 */
class MoReader
{
	private var original_table_offset:UInt;
	private var translated_table_offset:UInt;
	private var hash_num_entries:UInt;
	private var hash_offset:UInt;
	private var data:haxe.io.BytesInput;

	static var MAGIC:UInt = 0x950412DE;
	static var MAGIC2:UInt = 0xDE120495;

	public function new(data:haxe.io.Bytes):Void
	{
		this.data = new haxe.io.BytesInput(data);
	}

	public function parse():Map<String,LocaleString>
	{
		var d = data;
		var header : UInt = d.readInt32();

		if(header != MAGIC && header != MAGIC2) {
			throw "Bad MO file header : " + header;
		}

		var revision:UInt = d.readInt32();
		if (revision > 1){
			throw "Bad MO file format revision : "+revision;
		}

		var num_strings:UInt = d.readInt32();
		original_table_offset= d.readInt32();
		translated_table_offset = d.readInt32();
		hash_num_entries= d.readInt32();
		hash_offset= d.readInt32();

		var texts : Map<String,LocaleString> = new Map();
		var eot = String.fromCharCode(4);
		for (i in 0...num_strings){
			var ori = getOriginalString(i);
			if( ori.indexOf(eot)>=0 ) {
				// Swap context
				var split = ori.split(eot);
				ori = split[1]+GetText.CONTEXT+split[0];
			}
			if( ori == null || ori == "" ) continue;
			var trs = getTranslatedString(i);
			if( trs == null || trs == "" ) continue;
			texts.set( ori, trs );
		}

		return texts;

	}

	function getTranslatedString(index:Int):LocaleString {
		return getString(translated_table_offset + 8 * index );
	}

	function getOriginalString(index:Int):String {
		return getString(original_table_offset + 8 * index );
	}

	function getString(offset:UInt):LocaleString {
		data.position = offset;
		var length :UInt = data.readInt32();
		var pos :UInt = data.readInt32();
		data.position = pos;
		return new LocaleString( data.readString(length) );
	}
}

#if potools

class MOWriter {

	public static function generate( arr : Array<{id: String, str: String}> ){
		var arr = arr.filter(function(o) return o.id != null && o.str != null && o.str != "" && o.id != "");

		var N = arr.length;
		var O = 28;
		var T = 28 + arr.length * 8;
		var S = 0;
		var H = T + arr.length * 8;


		var b = haxe.io.Bytes.alloc(H);
		b.setInt32( 0, 0x950412DE);
		b.setInt32( 4, 0x0);
		b.setInt32( 8, N);
		b.setInt32(12, O); // original_offset
		b.setInt32(16, T); // translation_ofsset
		b.setInt32(20, S); // hash_size
		b.setInt32(24, H); // hash_offset

		var origin = new haxe.io.BytesBuffer();
		var transl = new haxe.io.BytesBuffer();

		var offset = H;
		var p = O;
		for( e in arr ){
			var v = haxe.io.Bytes.ofString(POTools.unescape(e.id));
			origin.add(v);
			origin.addByte(0);
			b.setInt32(p,v.length);
			b.setInt32(p+4,offset);

			offset += v.length+1;
			p += 8;
		}

		var p = T;
		for( e in arr ){
			var v = haxe.io.Bytes.ofString(POTools.unescape(e.str));
			transl.add(v);
			transl.addByte(0);
			b.setInt32(p,v.length);
			b.setInt32(p+4,offset);

			offset += v.length+1;
			p += 8;
		}

		var o = origin.getBytes();
		var t = transl.getBytes();

		var out = haxe.io.Bytes.alloc(b.length+o.length+t.length);
		var p = 0;
		out.blit(p,b,0,b.length); p += b.length;
		out.blit(p,o,0,o.length); p += o.length;
		out.blit(p,t,0,t.length); p += t.length;

		return out;
	}


}


class POTools {

	public static function parseFile( path : String ) : POData {
		return parse( sys.io.File.getContent(path) );
	}

	public static function parse( data : String ) : POData {
		var arr : POData = [];
		var e : POEntry = { str: null, id: null };
		var lnum = -1;
		for ( line in data.split("\n") ) {
			lnum++;
			// Remove CR before LF
			if ( line.length > 0 && line.substr( -1, 1) == "\r" )
				line = line.substr(0, line.length - 1);

			if( line.length == 0 ){
				arr.push(e);
				e = { str: null, id: null };
				continue;
			}

			var f = line.charCodeAt(0);
			if( f == '"'.code ){
				if( e.msgstr != null ){
					e.msgstr += "\n"+line;
					e.str += getString(line,lnum);
				}else if( e.msgid != null ){
					e.msgid += "\n"+line;
					e.id += getString(line,lnum);
				}else{
					throw "Parse error line "+lnum;
				}
			}else if( f == '#'.code ){
				var p = line.charCodeAt(1);
				switch( p ){
					case ':'.code:
						var s = line.substr(3);
						if( e.cRef == null )
							e.cRef = s;
						else
							e.cRef += "\n"+s;
					case '.'.code:
						var s = line.substr(3);
						if( e.cExtracted == null )
							e.cExtracted = s;
						else
							e.cExtracted += "\n"+s;
					case ','.code:
						var s = line.substr(3);
						if( e.cFlags == null )
							e.cFlags = s;
						else
							e.cFlags += "\n"+s;
					case '|'.code:
						var s = line.substr(3);
						if( e.cPrevious == null )
							e.cPrevious = s;
						else
							e.cPrevious += "\n"+s;
					case '~'.code:
						var s = line.substr(3);
						if( e.cComment == null )
							e.cComment = s;
						else
							e.cComment += "\n"+s;
					case ' '.code:
						var s = line.substr(2);
						if( e.cTranslator == null )
							e.cTranslator = s;
						else
							e.cTranslator += "\n"+s;
					default:
						throw "Parse error line "+lnum;
				}
			}else if( StringTools.startsWith(line, "msgid ") ){
				e.id = getString(line,lnum);
				e.msgid = line;
			}else if( StringTools.startsWith(line, "msgstr ") ){
				e.str = getString(line,lnum);
				e.msgstr = line;
			}else{
				throw "Parse error line "+lnum;
			}
		}
		return arr;
	}

	public static function mkHeaders( headers : Map<String,String> ) : POEntry {
		var str = 'msgstr ""';
		for( k in headers.keys() )
			str += '\n"'+k+': '+headers.get(k)+'\\n"';

		return {
			id: "",
			str: null,
			msgstr: str,
		};
	}

	public static function convertToMo( poPath : String, moPath : String, ?refData : POData ){
		var dat = parseFile(poPath);
		if( refData != null ){
			dat = dat.filter(function(e){
				if( e.id == null || e.id == "" ) return false;

				for( re in refData )
					if( re.id == e.id ) return true;
				return false;
			});
		}
		sys.io.File.saveBytes(moPath, MOWriter.generate(dat));
	}

	public static function exportFile( filePath : String, data : POData ){
		var fp = sys.io.File.write(filePath, true);
		export(fp,data);
		fp.close();
	}

	public static function exportTranslatedFile( data:POData, potFilePath:String, refPoFilePath:String, ?refDeprecatedPoFile:String ){
		var refData = parseFile( refPoFilePath );
		var oldRefData = refDeprecatedPoFile == null ? [] : parseFile( refDeprecatedPoFile );
		var expData : POData = [];
		var mref = new Map<String,{change: Bool, ref: POEntry, refid: Array<String>}>();
		for( entry in data ){
			if( entry.id == "" ){
				expData.push( entry );
				continue;
			}

			var refEntry = Lambda.find(refData,function(e) return e.str != "" && e.id == entry.id);
			var oldRefEntry = Lambda.find(oldRefData, function(e) return e.str != "" && e.id == entry.id);
			if( refEntry == null && oldRefEntry != null ){
				refEntry = oldRefEntry;
				oldRefEntry = null;
			}

			// 2 translations of the same origin ID
			if( oldRefEntry != null && oldRefEntry.str != refEntry.str ){
				var refid = ( entry.cExtracted != null )
					? entry.cExtracted+"\n\n--------\n"+oldRefEntry.msgid
					: "--------\n"+oldRefEntry.msgid;
				var change = oldRefEntry.str != oldRefEntry.id;

				if( mref.exists(oldRefEntry.str) ){
					var mEntry = mref.get(oldRefEntry.str);
					mEntry.refid.push(refid);
					if( change )
						mEntry.change = true;
				}else{
					var nentry = cloneEntry(entry);
					nentry.msgid = null;
					nentry.id = oldRefEntry.str;
					mref.set(nentry.id, {change: change, ref: nentry, refid: [refid]});
					expData.push(nentry);
				}
			}

			var change = false;
			var refid = null;
			if( refEntry != null ){
				change = refEntry.str != refEntry.id;
				if( entry.cExtracted != null )
					refid = entry.cExtracted+"\n\n--------\n"+refEntry.msgid;
				else
					refid = "--------\n"+refEntry.msgid;
				entry.msgid = null;
				entry.id = refEntry.str;
			}

			if( mref.exists(entry.id) ){
				var mEntry = mref.get( entry.id );
				if( refid != null ){
					mEntry.refid.push(refid);
					if( change )
						mEntry.change = true;
				}
			}else{
				var r = refid==null ? [] : [refid];
				mref.set( entry.id, {change: change, ref: entry, refid: r} );
				expData.push( entry );
			}
		}
		for( o in mref ){
			if( !o.change )
				continue;
			o.ref.cExtracted = o.refid.join("\n");
		}
		exportFile(potFilePath.split(".pot").join("-translated.pot"), expData);
	}

	public static function export( out: haxe.io.Output, data : POData ){
		var ids = new Map<String,Bool>();

		for( e in data ){
			if( e.cTranslator != null )
				out.writeString("# "+e.cTranslator.split("\n").join("\n# ")+"\n");
			if( e.cRef != null )
				out.writeString("#: "+e.cRef.split("\n").join("\n#: ")+"\n");
			if( e.cFlags != null )
				out.writeString("#, "+e.cFlags.split("\n").join("\n#, ")+"\n");
			if( e.cPrevious != null )
				out.writeString("#| "+e.cPrevious.split("\n").join("\n#| ")+"\n");
			if( e.cComment != null )
				out.writeString("#~ "+e.cComment.split("\n").join("\n#~ ")+"\n");
			if( e.cExtracted != null )
				out.writeString("msgctxt "+wrapQuote(e.cExtracted)+"\n");
				// out.writeString("msgctxt "+wrapQuote(e.cExtracted.split("\n").join("\n#. "))+"\n");

			var id = null;
			if( e.msgid != null ){
				out.writeString(e.msgid+"\n");
				id = getMultiString(e.msgid,0);
			}else if( e.id != null ){
				e.msgid = "msgid "+wrapQuote(e.id);
				out.writeString(e.msgid+"\n");
				id = e.id;
			}

			if( id != null ){
				#if gettext_warning
				if( ids.exists(id) )
					Sys.println("Warning: duplicate id in pot: "+id);
				#end
				ids.set(id,true);
			}

			if( e.msgstr != null ){
				out.writeString(e.msgstr+"\n");
			}else if( e.str != null ){
				e.msgstr = "msgstr "+wrapQuote(e.str);
				out.writeString(e.msgstr+"\n");
			}

			out.writeString("\n");
		}
		out.writeString("\n");
	}

	static var REG_STRING = ~/"((\\"|[^"]+)*)"$/;
	public static function getString( line : String, lnum:Int=0 ){
		if( !REG_STRING.match(line) )
			throw "Parse error line "+lnum+ "("+line+")";
		return REG_STRING.matched(1);
	}

	public static function getMultiString( lines : String, lnum ) {
		return lines.split("\n").map(function(s) return getString(s,lnum++)).join("");
	}

	public static function wrapQuote( str : String ){
		var arr = [str];
		var i = 0;
		while( arr[i].length > 80 ){
			var s = arr[i];
			var cut = s.lastIndexOf(" ",80);
			if( cut < 0 || cut >= s.length -1 )
				break;
			arr[i] = s.substr(0,cut+1);
			arr[i+1] = s.substr(cut+1);
			i++;
		}
		if( arr.length > 1 )
			arr.unshift("");

		return arr.map(quote).join("\n");
	}

	public static function quote( str : String ){
		return '"'+str+'"';
	}

	public static function unescape( str : String ){
		return str.split('\\"').join('"').split("\\n").join("\n").split("\\\\").join("\\");
	}

	public static function escape( str : String ){
		return str.split("\\n").join("\n").split("\\").join("\\\\").split("\n").join("\\n").split('"').join('\\"');
	}

	public static function cloneEntry( e : POEntry ) : POEntry {
		var ne : POEntry = {
			id: e.id,
			str: e.str,
		};

		if( e.msgid != null ) ne.msgid = e.msgid;
		if( e.msgstr != null ) ne.msgstr = e.msgstr;
		if( e.cTranslator != null ) ne.cTranslator = e.cTranslator;
		if( e.cExtracted != null ) ne.cExtracted = e.cExtracted;
		if( e.cRef != null ) ne.cRef = e.cRef;
		if( e.cFlags != null ) ne.cFlags = e.cFlags;
		if( e.cPrevious != null ) ne.cPrevious = e.cPrevious;
		if( e.cComment != null ) ne.cComment = e.cComment;

		return ne;
	}

}

#end
