package dn.struct;
import haxe.ds.Vector;

class RandDeck<T> {
	public var size(default, null) : Int;
	var elements : Null< Vector<T> >;
	var curIdx : Int;
	var rndFunc : Int->Int;
	public var autoShuffle = true;

	public function new(?rnd : Int->Int) {
		curIdx  = 0;
		size = 0;
		rndFunc = rnd==null ? Std.random : rnd;
	}

	public function toString() {
		return 'RandDeck($size)=>'+getAllElements();
	}

	function grow(newSize:Int) {
		var oldSize = elements==null ? 0 : elements.length;

		var old = elements;
		elements = new Vector(newSize*2);
		if( old!=null && oldSize>0 )
			Vector.blit(old, 0, elements, 0, oldSize);
	}

	public function push(v:T, n=1) {
		var newSize = size + n;
		if( elements==null || newSize >= elements.length )
			grow(newSize);

		for( i in size...newSize )
			elements[i] = v;
		size = newSize;
	}

	public inline function shuffle() {
		curIdx = 0;
		for (i in 0...(size-1)) {
			var j = rndFunc(size - i);
			var tmp = elements[i];
			elements[i] = elements[i + j];
			elements[i + j] = tmp;
		}
	}

	public inline function countRemaining() return size-curIdx;

	public function clear() {
		curIdx  = 0;
		size = 0;
	}

	public function draw() : Null<T> {
		if( size==0 )
			return null;

		var v = elements[curIdx];
		if( ++curIdx >= size && autoShuffle )
			shuffle();

		return v;
	}

	public inline function peekNextDraw() : Null<T> {
		return elements[curIdx];
	}

	public function getRemainingElements() : Array<T> {
		var a = [];
		for(i in curIdx...size)
			a.push( elements[i] );
		return a;
	}

	public function getAllElements() : Array<T> {
		var a = [];
		for(i in 0...size)
			a.push( elements[i] );
		return a;
	}


	@:noCompletion
	public static function __test() {
		var randDeck = new RandDeck();
		randDeck.push(0, 2);
		randDeck.push(1, 5);
		randDeck.push(2, 10);
		randDeck.shuffle();
		CiAssert.isTrue( randDeck.countRemaining()==17 );
		CiAssert.noException("RandDeck.draw() check", {
			for(i in 0...200) {
				var v = randDeck.draw();
				if( v==null || v<0 || v>2 )
					throw "Value "+v+" is incorrect";
			}
		});

	}
}