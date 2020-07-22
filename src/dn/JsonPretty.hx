package dn;

class JsonPretty {
	public static var INDENT_CHAR = "\t";
	static var INDENT_LENGTH_LIMIT = 40;

	public static function stringify(o:Dynamic) {
		return encodeValue(null, o, 0);
	}

	static function encodeObject(name:Null<String>, o:Dynamic, indentDepth:Int) {
		if( Reflect.fields(o).length==0 )
			if( name==null )
				return "{}";
			else
				return '"$name" : {}';

		// Parse fields
		var frags = [];
		for(k in Reflect.fields(o)) {
			var v = Reflect.field(o, k);
			frags.push( encodeValue(k, v, indentDepth+1) );
		}
		var len = 0;
		for(str in frags)
			len+=str.length;


		// Build output
		var buffer = new StringBuf();

		if( name!=null )
			buffer.add('"$name" : ');

		if( len<=INDENT_LENGTH_LIMIT ) {
			// Inlined
			buffer.add("{ ");
			buffer.add( frags.join(",") );
			buffer.add(" }");
		}
		else {
			// Indent
			var curIndent = "";
			for(i in 0...indentDepth)
				curIndent+=INDENT_CHAR;
			buffer.add("{\n");
			buffer.add(curIndent + INDENT_CHAR + frags.join(",\n"+curIndent+INDENT_CHAR) + "\n");
			buffer.add(curIndent + "}");
		}

		return buffer.toString();
	}


	static function encodeArray(name:String, arr:Array<Dynamic>, indentDepth:Int) {
		if( arr.length==0 )
			return '"$name" : []';

		var frags = [];
		for(v in arr)
			frags.push( encodeValue(null,v, indentDepth+1) );

		var len = 0;
		for(str in frags)
			len+=str.length;
		if( len<=INDENT_LENGTH_LIMIT ) {
			// Inlined
			return '"$name" : [ ' + frags.join(", ") + " ]";
		}
		else {
			// Indent
			var curIndent = "";
			for(i in 0...indentDepth)
				curIndent+=INDENT_CHAR;
			return '"$name" : ['
				+ curIndent + INDENT_CHAR + frags.join(",\n"+curIndent+INDENT_CHAR) + "\n"
				+ curIndent + "]";
		}
	}



	static function encodeValue(name:Null<String>, v:Dynamic, indentDepth:Int) {
		switch Type.typeof(v) {
			case TNull, TInt, TFloat, TBool:
				return name==null ? v : '"$name" : $v';

			case TClass(String):
				return name==null ? v : '"$name" : "$v"';

			case TClass(Array):
				return encodeArray(name, v, indentDepth+1);

			case TObject:
				return encodeObject(name, v, indentDepth+1);

			case _:
				throw 'Unknown value type $name=$v ('+Type.typeof(v)+')';
		}
	}
}