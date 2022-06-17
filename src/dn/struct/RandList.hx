package dn.struct;

class RandList<T> {
	public var totalProba(default, null)	: Int;

	var drawList : Array<{proba:Int, value:T}>;
	var defaultRandom : Int->Int;
	public var length(get,never) : Int; inline function get_length() return drawList.length;

	public function new(?rndFunc:Int->Int, ?arr:Array<T>) {
		if( rndFunc!=null )
			defaultRandom = rndFunc;
		else
			defaultRandom = Std.random;

		totalProba = 0;
		drawList = new Array();

		if( arr != null )
			addArray(arr);
	}

	public function clear() {
		totalProba = 0;
		drawList = [];
	}

	public function setProba(v:T, p:Int) {
		for(e in drawList)
			if( e.value==v ) {
				totalProba-=e.proba;
				e.proba = p;
				totalProba+=e.proba;
			}
	}

	// Crée une nouvelle RandList en ne conservant que certains éléments
	public function filter(keep:T->Bool) : RandList<T> {
		var out = new RandList(defaultRandom);
		for(e in drawList)
			if( keep(e.value) )
				out.add(e.value, e.proba);
		return out;
	}

	// Crée une RandList en utilisant les metadata d'un enum comme proba
	public static function fromEnum<T>( e : Enum<T>, ?metaFieldName = "proba" ) : RandList<T> {
		var n = Type.getEnumName(e);
		var r = new RandList<T>();
		var meta = haxe.rtti.Meta.getFields(e);

		for ( k in Type.getEnumConstructs(e) ) {
			var p = Type.createEnum(e, k);
			r.add( p, Reflect.field( Reflect.field(meta,k), metaFieldName )[0] );
		}

		return r;
	}


	#if flash
	public static function fromMap<T>(m:Map<T,Int>) : RandList<T> {
		var r = new RandList();
		for(k in m.keys())
			r.add(k, m.get(k));
		return r;
	}
	#end

	public function add(elem:T, ?proba=1) {
		if( proba<=0 )
			return this;

		// Add to existing if this elem is already there
		for(e in drawList)
			if( e.value==elem ) {
				e.proba+=proba;
				totalProba+=proba;
				return this;
			}

		drawList.push( { proba:proba, value:elem } );
		totalProba += proba;

		return this;
	}

	public function addArray(arr:Array<T>, ?proba=1) {
		for(i in 0...arr.length) {
			var e = arr[i];
			if( contains(e) )
				continue;

			var n = 1;
			for(j in i+1...arr.length)
				if( arr[j]==e )
					n++;

			add(e, n*proba);
		}
	}

	public function contains(search:T) {
		for(e in drawList)
			if( e.value==search )
				return true;

		return false;
	}

	public function remove(search:T) {
		totalProba = 0;

		var i = 0;
		while( i<drawList.length )
			if( drawList[i].value == search )
				drawList.splice(i,1);
			else {
				totalProba += drawList[i].proba;
				i++;
			}

		return this;
	}

	public function draw(?rndFunc:Int->Int) : Null<T> {
		var n = rndFunc==null ? defaultRandom(totalProba) : rndFunc(totalProba);

		var accu = 0;
		for (e in drawList) {
			if ( n < accu + e.proba )
				return e.value;

			accu += e.proba;
		}

		return null;
	}

	public function filteredDraw(filter:T->Bool, ?rndFunc:Int->Int) : Null<T> {
		var fList = drawList.filter(function(e) return filter(e.value));
		var total = 0;
		for(e in fList)
			total+=e.proba;

		var n = rndFunc==null ? defaultRandom(total) : rndFunc(total);

		var accu = 0;
		for (e in fList) {
			if ( n < accu + e.proba )
				return e.value;

			accu += e.proba;
		}

		return null;
	}

	public inline function getValues() {
		return drawList.map( function(e) return e.value );
	}

	public function getProba(v:T) {
		for(e in drawList)
			if( e.value==v )
				return e.proba;
		return 0;
	}

	public inline function getProbaPct(v:T) : Float { // 0-100
		return totalProba==0 ? 0 : Math.round(1000*getProba(v)/totalProba) / 10;
	}

	public inline function isEmpty() return drawList.length==0;

	public function toString() {
		var list = new List();

		for (e in drawList)
			list.add(Std.string(e.value) + " => " + ( totalProba==0 ? 0 : Math.round(1000 * e.proba / totalProba) / 10 ) + "%");

		return list.join(" | ");
	}

	public function getDebugArray() {
		var a = new Array();

		for (e in drawList)
			a.push( {
				v : e.value,
				pct : ( totalProba==0 ? 0 : Math.round(1000 * e.proba / totalProba) / 10 )
			} );

		return a;
	}


	@:noCompletion
	public static function __test() {
		var randList = new RandList([0,1,2,3]);
		CiAssert.noException("RandList.draw() check", {
			for(i in 0...200) {
				var v = randList.draw();
				if( v==null || v<0 || v>3 )
					throw "Value "+v+" is incorrect";
			}
		});
		CiAssert.isTrue( randList.getProbaPct(2)==25 );
		CiAssert.isTrue( randList.contains(3) );
	}
}

