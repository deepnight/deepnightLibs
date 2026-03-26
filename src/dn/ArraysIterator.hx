package dn;

class ArraysIterator<T> {
	var globalIdx = 0;
	var arrays : Array<Array<T>>;

	var arrayIdx = 0;
	var localIterIdx = 0;

	public function new(arrays:Array<Array<T>>) {
		this.arrays = arrays;
		moveIndexForward();
	}

	function moveIndexForward() {
		while( arrayIdx<arrays.length && localIterIdx>=arrays[arrayIdx].length ) {
			arrayIdx++;
			localIterIdx = 0;
		}
	}

	public function hasNext() : Bool {
		return arrayIdx<arrays.length;
	}

	public function next() : T {
		if( arrayIdx>=arrays.length )
			return null;

		var v = arrays[arrayIdx][localIterIdx];
		localIterIdx++;
		moveIndexForward();
		return v;
	}


	#if deepnightLibsTests
	public static function test() {
		function _countIterations(arrays:Array<Array<Int>>) : Int {
			var i = 0;
			for(v in new ArraysIterator(arrays)) {
				trace(v);
				i++;
			}
			return i;
		}

		// Empty arrays
		CiAssert.equals( _countIterations([[],[],[],[]]), 0 );
		CiAssert.equals( _countIterations([[]]), 0 );
		CiAssert.equals( _countIterations([]), 0 );

		// Partially empty arrays
		CiAssert.equals( _countIterations([[1,2],[],[],[3,4]]), 4 );
		CiAssert.equals( _countIterations([[],[1,2],[],[3]]), 3 );
		CiAssert.equals( _countIterations([[],[],[],[1,2,3]]), 3 );
		CiAssert.equals( _countIterations([[1],[],[2],[3]]), 3 );

		// Non-empty arrays
		CiAssert.equals( _countIterations([[1,2,3],[4,5,6,7,8],[9,10]]), 10 );
		CiAssert.equals( _countIterations([[1,2,3]]), 3 );
		CiAssert.equals( _countIterations([[1]]), 1 );
	}
	#end
}