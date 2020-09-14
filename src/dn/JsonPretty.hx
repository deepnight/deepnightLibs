package dn;

class JsonPretty {
	static var buf : StringBuf;
	static var indent : Int;
	static var needHeader : Bool;
	static var header : Dynamic;

	static var space : String;
	static var preSpace : String; // Spaces before ":"
	static var postSpace : String; // Spaces after ":"
	static var tab : String;
	static var lineBreak : String;

	public static function stringify(minified=false, o:Dynamic, ?headerObject:Dynamic) {
		indent = 0;
		buf = new StringBuf();
		space = minified ? "" : " ";
		preSpace = "";
		postSpace = minified ? "" : " ";
		tab = minified ? "" : "\t";
		lineBreak = minified ? "" : "\n";

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
				name==null ? buf.add(Std.string(v)) : buf.add('"$name"$preSpace:$postSpace$v');

			case TFloat:
				var strFloat = v==Std.int(v) ? v+".0" : Std.string(v);
				name==null ? buf.add(strFloat) : buf.add('"$name"$preSpace:$postSpace$strFloat');

			case TClass(String):
				if( floatReg.match(v) ) {
					// Treat numbers ending with "f" as float-hinted values, which can be useful to keep int/float
					// distinction in JSON files
					// Examples: 0f, -65f, 1f etc.
					var v : String = v;
					var f = Std.parseFloat( v.substr(0,v.length-1) );
					var strFloat = f==Std.int(f) ? f+".0" : Std.string(f);
					name==null ? buf.add(strFloat) : buf.add('"$name"$preSpace:$postSpace$strFloat');
				}
				else
					name==null ? buf.add('"$v"') : buf.add('"$name"$preSpace:$postSpace"$v"');

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
		var len = evaluateLength(o);
		if( name!=null )
			buf.add('"$name"$preSpace:$postSpace');

		// Add fields to buffer
		var keys = Reflect.fields(o);
		if( len<=70 && !needHeader ) {
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
				buf.add('"$name"$preSpace:$postSpace[]');
			return;
		}

		// Evaluate length for multiline option
		var len = evaluateLength(arr);

		if( name!=null )
			buf.add('"$name"$preSpace:$postSpace');

		// Add values to buffer
		if( len<=70 ) {
			// Single line
			buf.add('[$space');
			for( i in 0...arr.length ) {
				addValue( null, arr[i] );
				if( i<arr.length-1 )
					buf.add(',$space');
			}
			buf.add('$space]');
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
				if( arr.length>0 && arr.length<50 && ( Type.typeof(arr[0])==TInt || Type.typeof(arr[0])==TFloat ) )
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