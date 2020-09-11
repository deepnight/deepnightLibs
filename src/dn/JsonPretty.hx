package dn;

class JsonPretty {
	public static var INDENT_CHAR = "\t";

	static var buf : StringBuf;
	static var indent : Int;
	static var needHeader : Bool;
	static var header : Dynamic;

	public static function stringify(o:Dynamic, ?headerObject:Dynamic) {
		indent = 0;
		buf = new StringBuf();

		header = headerObject;
		needHeader = headerObject!=null;
		if( headerObject!=null )
			switch Type.typeof(headerObject) {
				case TObject:
				case TClass(String):
				case _: throw "Only Anonymous Objects or Strings are supported as JSON headers";
			}

		addValue(null, o);
		return buf.toString();
	}


	static var floatReg = ~/^([-0-9.]+)f$/g;
	static function addValue(name:Null<String>, v:Dynamic) : Void {
		switch Type.typeof(v) {
			case TNull, TInt, TBool:
				name==null ? buf.add(Std.string(v)) : buf.add('"$name" : $v');

			case TFloat:
				var strFloat = v==Std.int(v) ? v+".0" : Std.string(v);
				name==null ? buf.add(strFloat) : buf.add('"$name" : $strFloat');

			case TClass(String):
				if( floatReg.match(v) ) {
					// Treat numbers ending with "f" as float-hinted values, which can be useful to keep int/float
					// distinction in JSON files
					// Examples: 0f, -65f, 1f etc.
					var v : String = v;
					var f = Std.parseFloat( v.substr(0,v.length-1) );
					var strFloat = f==Std.int(f) ? f+".0" : Std.string(f);
					name==null ? buf.add(strFloat) : buf.add('"$name" : $strFloat');
				}
				else
					name==null ? buf.add('"$v"') : buf.add('"$name" : "$v"');

			case TClass(Array):
				addArray(name, v);

			case TObject:
				addObject(name, v);

			case _:
				throw 'Unknown value type $name=$v ('+Type.typeof(v)+')';
		}
	}


	static function addObject(name:Null<String>, o:Dynamic) {
		var keys = Reflect.fields(o);
		if( keys.length==0 ) {
			if( name==null )
				buf.add('{}');
			else
				buf.add('"$name" : {}');
			return;
		}

		// Evaluate length for multiline option
		var len = 0;
		for( k in keys )
			len += evaluateLength( Reflect.field(o,k) );

		if( name!=null )
			buf.add('"$name" : ');

		// Add fields to buffer
		var keys = Reflect.fields(o);
		if( len<=80 && !needHeader ) {
			// Single line
			buf.add('{ ');
			for( i in 0...keys.length ) {
				addValue( keys[i], Reflect.field(o,keys[i]) );
				if( i<keys.length-1 )
					buf.add(", ");
			}
			buf.add(' }');
		}
		else {
			// Multiline
			buf.add('{\n');
			indent++;

			if( needHeader ) {
				addHeader();
				if( keys.length>0 )
					buf.add(",\n");
			}

			for( i in 0...keys.length ) {
				addIndent();
				addValue( keys[i], Reflect.field(o,keys[i]) );
				if( i<keys.length-1 )
					buf.add(",\n");
			}
			indent--;
			buf.add("\n");
			addIndent();
			buf.add("}");
		}
	}

	static function addHeader() {
		needHeader = false;
		addIndent();

		switch Type.typeof(header) {
			case TObject, TClass(String):
				addValue("__header__", header);

			case _:
				throw "Unsupported header type";
		}

	}

	static function addArray(name:Null<String>, arr:Array<Dynamic>) {
		if( arr.length==0 ) {
			if( name==null )
				buf.add('[]');
			else
				buf.add('"$name" : []');
			return;
		}

		// Evaluate length for multiline option
		var len = evaluateLength(arr);

		if( name!=null )
			buf.add('"$name" : ');

		// Add values to buffer
		if( len<=20 ) {
			// Single line
			buf.add('[ ');
			for( i in 0...arr.length ) {
				addValue( null, arr[i] );
				if( i<arr.length-1 )
					buf.add(", ");
			}
			buf.add(' ]');
		}
		else {
			// Multiline
			buf.add('[\n');
			indent++;
			for( i in 0...arr.length ) {
				addIndent();
				addValue( null, arr[i] );
				if( i<arr.length-1 )
					buf.add(",\n");
			}
			indent--;
			buf.add("\n");
			addIndent();
			buf.add("]");
		}
	}


	static inline function addIndent() {
		for(i in 0...indent)
			buf.add(INDENT_CHAR);
	}

	static inline function evaluateLength(v:Dynamic) {
		return switch Type.typeof(v) {
			case TNull: 4;
			case TInt: 4;
			case TFloat: 5;
			case TBool: v ? 4 : 5;
			case TObject: 10;
			case TClass(String): ( cast v ).length + 2;
			case TClass(Array):
				var arr : Array<Dynamic> = cast v;
				if( arr.length>0 && arr.length<50 && ( Type.typeof(arr[0])==TInt || Type.typeof(arr[0])==TFloat ) )
					4;
				else if( arr.length>5 )
					99;
				else {
					var len = 0;
					for(e in arr)
						len += evaluateLength(e);
					len;
				}
			case _: 1;
		}
	}
}