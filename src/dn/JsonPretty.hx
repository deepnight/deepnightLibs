package dn;

class JsonPretty {
	public static var INDENT_CHAR = "\t";

	static var buf : StringBuf;
	static var indent = 0;

	public static function stringify(o:Dynamic) {
		buf = new StringBuf();
		addValue(null, o);
		return buf.toString();
	}


	static inline function addValue(name:Null<String>, v:Dynamic) : Void {
		switch Type.typeof(v) {
			case TNull, TInt, TFloat, TBool:
				name==null ? buf.add(Std.string(v)) : buf.add('"$name" : $v');

			case TClass(String):
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
		if( len<=20 ) {
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


	static function addArray(name:Null<String>, arr:Array<Dynamic>) {
		if( arr.length==0 ) {
			if( name==null )
				buf.add('[]');
			else
				buf.add('"$name" : []');
			return;
		}

		// Evaluate length for multiline option
		var len = 0;
		for( v in arr )
			len += evaluateLength(v);

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
			case TObject: 99;
			case TClass(String): ( cast v ).length + 2;
			case TClass(Array):
				var arr : Array<Dynamic> = cast v;
				if( arr.length>5 )
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