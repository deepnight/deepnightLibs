package dn;
import haxe.ds.Vector;

class RandDeck<T> {
	public var size(default, null) : Int;
	var elements : Vector<T>;
	var curIdx : Int;
	var maxLength : Int;
	var rndFunc : Int->Int;

	public function new(?rnd : Int->Int) {
		curIdx  = 0;
		maxLength  = 0;
		size = 0;
		rndFunc = rnd==null ? Std.random : rnd;
	}

	public function toString() {
		return 'RandDeck($size)=>'+getAllElements();
	}

	function grow() {
		maxLength = maxLength==0 ? 2 : maxLength * 2;

		var old = elements;
		elements = new Vector(maxLength);
		if( old!=null && size>0 )
			Vector.blit(old, 0, elements, 0, size);
	}

	public function push(v:T, n=1) {
		var newSize = size + n;
		if( newSize>maxLength )
			grow();

		for (i in size...newSize) elements[i] = v;
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
		if( ++curIdx >= size )
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
}