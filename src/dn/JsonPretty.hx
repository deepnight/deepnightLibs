package dn;

enum JsonPrettyLevel {
	/** No pretty at all, no space or indentation **/
	Minified;
	/** Default pretty level, which tries to keep things a little bit more compact (ie. small arrays are kept on 1 line, etc.) **/
	Compact;
	/** Full pretty mode: line breaks and indentation everywhere! **/
	Full;
}

enum JsonEnumSupport {
	/** Throw an exception when encountering enum values **/
	UnsupportedEnums;
	/** Store enum value name as Object **/
	UseEnumObject;
	/** Store enum value name as String **/
	UseEnumName;
	/** Store enum value index as Int **/
	UseEnumIndex;
}

class JsonPretty {
	public static var HEADER_VALUE_NAME = "__header__";

	/** Used for "Compact" pretty level, when deciding between single or multi lines output. **/
	static inline var APPROXIMATE_MAX_LINE_LENGTH = 85;
	static var customFormaters : Map<String, (value:Dynamic, buf:StringBuf)->Void> = new Map();

	/** Define how to behave when finding Enum values. Default is "Unsupported". "**/
	static var enumSupport : JsonEnumSupport;

	static var level : JsonPrettyLevel;

	static var buf : StringBuf;
	static var indent : Int;
	static var needHeader : Bool;
	static var header : Dynamic;
	static var inlineHeader : Bool;

	static var space : String;
	static var preSpace : String; // Spaces before ":"
	static var postSpace : String; // Spaces after ":"
	static var tab : String;
	static var lineBreak : String;


	/**
		Transform an Object into a Json String, with an optional "header" Object that will be added at the beginning of the output Json. The `prettyLevel` can be either Compact (default; adds line breaks & indentation when required), Full (ie. line breaks & indentation everywhere) or Minified (no space nor indentation).

		If `inlineHeader` is FALSE (default), the header object will be add in a `__header__` object at the beginning of the Json. If TRUE, the header fields will be directly added at the beginning of the Json.

		enumSupport defines how to behave when encountering Enum values (UnsupportedEnums, UseEnumName, UseEnumIndex). Parametered enums are not supported.
	**/
	public static function stringify(o:Dynamic, prettyLevel=Compact, ?headerObject:Dynamic, inlineHeader=false, enumSupport=UnsupportedEnums) {
		level = prettyLevel;
		indent = 0;
		buf = new StringBuf();
		space = level==Minified ? "" : " ";
		preSpace = "";
		postSpace = level==Minified ? "" : " ";
		tab = level==Minified ? "" : "\t";
		lineBreak = level==Minified ? "" : "\n";
		JsonPretty.enumSupport = enumSupport;
		JsonPretty.inlineHeader = inlineHeader;

		header = headerObject;
		if( headerObject!=null )
			switch Type.typeof(headerObject) {
				case TObject: needHeader = Reflect.fields(header).length>0;
				case TClass(String): needHeader = header.length>0;
				case TClass(haxe.ds.StringMap): needHeader = Lambda.count(header)>0;
				case _: throw "Only Anonymous Objects or Strings are supported as JSON headers";
			}

		addValue(null, o);
		return buf.toString();
	}


	public static function removeAllCustomFormaters() {
		customFormaters = new Map();
	}
	public static function addCustomPrettyFormater(valueName:String, formater:(value:Dynamic, buf:StringBuf)->Void) {
		if( valueName!=null )
			customFormaters.set(valueName, formater);
	}


	static var floatReg = ~/^([-0-9.]+)f$/g;
	static function addValue(name:Null<String>, v:Dynamic, forceMultilines=false) : Void {
		if( name==HEADER_VALUE_NAME )
			forceMultilines = true;

		if( level!=Minified && name!=null && customFormaters.exists(name) ) {
			buf.add('"$name"$preSpace:$postSpace');
			customFormaters.get(name)(v, buf);
			return;
		}

		switch Type.typeof(v) {
			case TNull, TInt, TBool:
				name==null ? buf.add(Std.string(v)) : buf.add('"$name"$preSpace:$postSpace$v');

			case TFloat:
				var strFloat = v==Std.int(v) ? v+".0" : Std.string(v);
				name==null ? buf.add(strFloat) : buf.add('"$name"$preSpace:$postSpace$strFloat');

			case TClass(String):
				if( floatReg.match(v) ) {
					/**
						Treat numbers ending with "f" as float-hinted values, which can be useful to keep int/float distinction in JSON files
						Examples: 0f -> 0.0, -65f -> -65.0, 1f -> 1.0 etc.
					**/
					var v : String = v;
					var f = Std.parseFloat( v.substr(0,v.length-1) );
					var strFloat = f==Std.int(f) ? f+".0" : Std.string(f);
					name==null ? buf.add(strFloat) : buf.add('"$name"$preSpace:$postSpace$strFloat');
				}
				else {
					// Normal string
					v = StringTools.replace(v, "\n", " ");
					v = StringTools.replace(v, "\r", "");
					v = StringTools.replace(v, "\t", " ");
					v = StringTools.replace(v, '"', '\\"');
					name==null ? buf.add('"$v"') : buf.add('"$name"$preSpace:$postSpace"$v"');
				}

			case TClass(Array):
				addArray(name, v, forceMultilines);

			case TClass(haxe.ds.StringMap):
				var map : haxe.ds.StringMap<Dynamic> = v;
				var obj = {};
				for( mv in map.keyValueIterator() )
					Reflect.setField(obj, mv.key, mv.value);
				addObject(name, obj);

			case TObject:
				addObject(name, v, forceMultilines);

			case TEnum(e):
				switch enumSupport {
					case UnsupportedEnums:
						throw 'Unsupported enum value $name : ${e.getName()}';

					case UseEnumObject:
						var ev : EnumValue = cast v;
						addValue( name, { __jsonEnum:e.getName(), v:ev.getName(), p:ev.getParameters() } );

					case UseEnumName:
						var ev : EnumValue = cast v;
						if( ev.getParameters().length>0 )
							throw 'Unsupported parametered enum $name : ${e.getName()}';
						addValue( name, ev.getName() );

					case UseEnumIndex:
						var ev : EnumValue = cast v;
						if( ev.getParameters().length>0 )
							throw 'Unsupported parametered enum $name : ${e.getName()}';
						addValue( name, ev.getIndex() );
				}

			case _:
				throw 'Unknown value type $name=$v ('+Type.typeof(v)+')';
		}
	}


	static function addObject(name:Null<String>, o:Dynamic, forceMultilines=false) {
		var keys = Reflect.fields(o);
		if( keys.length==0 ) {
			if( name==null )
				buf.add('{}');
			else
				buf.add('"$name" : {}');
			return;
		}

		// Evaluate length for multiline option
		var len = level==Compact ? evaluateLength(o) : 0;

		// Prepend name
		if( name!=null )
			buf.add('"$name"$preSpace:$postSpace');

		// Add fields to buffer
		var keys = Reflect.fields(o);
		if( level!=Full && len<=APPROXIMATE_MAX_LINE_LENGTH && !needHeader && !forceMultilines ) {
			// Single line
			buf.add('{$space');
			for( i in 0...keys.length ) {
				addValue( keys[i], Reflect.field(o,keys[i]) );
				if( i<keys.length-1 )
					buf.add(',$space');
			}
			buf.add('$space}');
		}
		else {
			// Multiline
			buf.add('{$lineBreak');
			indent++;

			if( needHeader ) {
				addHeader();
				if( keys.length>0 )
					buf.add(',$lineBreak');
			}

			for( i in 0...keys.length ) {
				addIndent();
				addValue( keys[i], Reflect.field(o,keys[i]) );
				if( i<keys.length-1 )
					buf.add(',$lineBreak');
			}
			indent--;
			buf.add(lineBreak);
			addIndent();
			buf.add("}");
		}
	}

	static function addHeader() {
		needHeader = false;
		addIndent();

		switch Type.typeof(header) {
			case TObject, TClass(String):
				if( inlineHeader ) {
					var i = 0;
					var all = Reflect.fields(header);
					for( k in all ) {
						addValue(k, Reflect.field(header, k), true);
						if( i++<all.length-1 ) {
							buf.add(',$lineBreak');
							addIndent();
						}
					}
				}
				else
					addValue(HEADER_VALUE_NAME, header, true);

			case TClass(haxe.ds.StringMap):
				if( inlineHeader ) {
					var i = 0;
					var map : Map<String,Dynamic> = header;
					var n = Lambda.count(map);
					for(f in map.keyValueIterator()) {
						addValue(f.key, f.value, true);
						if( i++<n-1 ) {
							buf.add(',$lineBreak');
							addIndent();
						}
					}
				}
				else
					addValue(HEADER_VALUE_NAME, header, true);

			case _:
				throw "Unsupported header type";
		}

	}

	static function addArray(name:Null<String>, arr:Array<Dynamic>, forceMultilines=false) {
		if( arr.length==0 ) {
			if( name==null )
				buf.add('[]');
			else
				buf.add('"$name"$preSpace:$postSpace[]');
			return;
		}

		// Evaluate length for multiline option
		var len = level==Compact ? evaluateLength(arr) : 0;

		if( name!=null )
			buf.add('"$name"$preSpace:$postSpace');

		var arrValueType = Type.typeof( arr[0] );

		if( level!=Minified && ( arrValueType==TInt || arrValueType==TFloat ) && !forceMultilines && arr.length>APPROXIMATE_MAX_LINE_LENGTH ) {
			// Number grid (nicer for CSV data)
			buf.add('[$lineBreak');
			indent++;
			addIndent();
			var lineLimit = 0;
			for( i in 0...arr.length ) {
				addValue( null, arr[i] );
				if( i<arr.length-1 )
					buf.add(',');
				lineLimit++;
				if( lineLimit>=35 ) {
					buf.add(lineBreak);
					addIndent();
					lineLimit = 0;
				}
			}
			indent--;
			buf.add(lineBreak);
			addIndent();
			buf.add("]");
		}
		else if( level!=Full && len<=APPROXIMATE_MAX_LINE_LENGTH && !forceMultilines ) {
			// Single line
			var arraySpace =
				switch arrValueType {
					case TInt, TFloat: "";
					case TBool: arr.length>5 ? "" : space;
					case _: arr.length==1 ? "" : space;
				}

			buf.add('[$arraySpace');
			for( i in 0...arr.length ) {
				addValue( null, arr[i] );
				if( i<arr.length-1 )
					buf.add(',$arraySpace');
			}
			buf.add('$arraySpace]');
		}
		else {
			// Multiline
			buf.add('[$lineBreak');
			indent++;
			for( i in 0...arr.length ) {
				addIndent();
				addValue( null, arr[i] );
				if( i<arr.length-1 )
					buf.add(',$lineBreak');
			}
			indent--;
			buf.add(lineBreak);
			addIndent();
			buf.add("]");
		}
	}


	static inline function addIndent() {
		if( tab.length>0 )
			for(i in 0...indent)
				buf.add(tab);
	}

	static inline function evaluateLength(v:Dynamic, curEvalDepth=0) {
		return switch Type.typeof(v) {
			case TNull: 4;
			case TInt: 4;
			case TFloat: 5;
			case TBool: v ? 4 : 5;
			case TClass(String): ( cast v ).length + 2;

			case TObject:
				if( curEvalDepth<=0 && Reflect.fields(v).length<=5 ) {
					var len = 0;
					for( k in Reflect.fields(v) )
						len += evaluateLength( Reflect.field(v,k), curEvalDepth+1 );
					len;
				}
				else
					Reflect.fields(v).length*10;

			case TClass(Array):
				var arr : Array<Dynamic> = cast v;
				if( arr.length==0 )
					2;
				else if( arr.length>0 && arr.length<50 && ( Type.typeof(arr[0])==TInt || Type.typeof(arr[0])==TFloat ) )
					arr.length;
				else if( arr.length>5 || curEvalDepth>0 )
					99;
				else {
					var len = 0;
					for(e in arr)
						len += evaluateLength(e, curEvalDepth+1);
					len;
				}

			case _: 1;
		}
	}
}