package dn;

/**
 * Various helper methods for 2D grid traversal.
 *
 * There's two kinds of line helpers:
 *   - `Thin`, meaning that the line does diagonal jumps
 *   - `Thick`, meaning that the line does *not* do diagonal jumps
 *
 * There's also two kinds of circular helpers:
 *   - `Circle`, meaning only the edge is taken into account
 *   - `Disc`, meaning the entirety of a disc is taken into account
 */
class Bresenham {

	/**
	 * Get a list of coordinates from `(x0, y0)` to `(x1, y1)`, where diagonal jumps are allowed.
	 *
	 * If you do not want diagonal jumps use `getThickLine` instead.
	 * @param x0 Starting x coordinate
	 * @param y0 Starting y coordinate
	 * @param x1 End x coordinate
	 * @param y1 End y coordinate
	 * @param respectOrder=false Whether the list of points should be ordered start -> end. (This might not be the case when the end is geometrically closer to the origin than the start)
	 * @return Array<{x:Int, y:Int}> An array of points along the line
	 */
	public static function getThinLine(x0:Int, y0:Int, x1:Int, y1:Int, ?respectOrder=false) : Array<{x:Int, y:Int}> {
		var pts = [];
		var swapXY = M.iabs( y1 - y0 ) > M.iabs( x1 - x0 );
		var swapped = false;
        var tmp : Int;
        if ( swapXY ) {
            // swap x and y
            tmp = x0; x0 = y0; y0 = tmp; // swap x0 and y0
            tmp = x1; x1 = y1; y1 = tmp; // swap x1 and y1
        }
        if ( x0 > x1 ) {
            // make sure x0 < x1
            tmp = x0; x0 = x1; x1 = tmp; // swap x0 and x1
            tmp = y0; y0 = y1; y1 = tmp; // swap y0 and y1
			swapped = true;
        }
        var deltax = x1 - x0;
        var deltay = M.floor( M.iabs( y1 - y0 ) );
        var error = M.floor( deltax / 2 );
        var y = y0;
        var ystep = if ( y0 < y1 ) 1 else -1;
		if( swapXY )
			// Y / X
			for ( x in x0 ... x1+1 ) {
				pts.push({x:y, y:x});
				error -= deltay;
				if ( error < 0 ) {
					y+=ystep;
					error = error + deltax;
				}
			}
		else
			// X / Y
			for ( x in x0 ... x1+1 ) {
				pts.push({x:x, y:y});
				error -= deltay;
				if ( error < 0 ) {
					y+=ystep;
					error = error + deltax;
				}
			}

		if( swapped && respectOrder )
			pts.reverse();

		return pts;
	}

	@:noCompletion
	@:deprecated("Use getThickLine() instead")
	public static inline function getFatLine(x0:Int, y0:Int, x1:Int, y1:Int, ?respectOrder=false) {
		return getThickLine(x0,y0,x1,y1,respectOrder);
	}

	/**
	 * Get a list of coordinates from `(x0, y0)` to `(x1, y1)`, without diagonal jumps.
	 *
	 * If you do want diagonal jumps use `getThickLine` instead.
	 * @param x0 Starting x coordinate
	 * @param y0 Starting y coordinate
	 * @param x1 End x coordinate
	 * @param y1 End y coordinate
	 * @param respectOrder=false Whether the list of points should be ordered start -> end. (This might not be the case when the end is geometrically closer to the origin than the start)
	 * @return Array<{x:Int, y:Int}> An array of points along the line
	 */
	public static function getThickLine(x0:Int, y0:Int, x1:Int, y1:Int, ?respectOrder=false): Array<{x:Int, y:Int}> {
		var pts = [];
		var swapXY = M.iabs( y1 - y0 ) > M.iabs( x1 - x0 );
		var swapped = false;
        var tmp : Int;
        if ( swapXY ) {
            // swap x and y
            tmp = x0; x0 = y0; y0 = tmp; // swap x0 and y0
            tmp = x1; x1 = y1; y1 = tmp; // swap x1 and y1
        }
        if ( x0 > x1 ) {
			swapped = true;
            // make sure x0 < x1
            tmp = x0; x0 = x1; x1 = tmp; // swap x0 and x1
            tmp = y0; y0 = y1; y1 = tmp; // swap y0 and y1
        }
        var deltax = x1 - x0;
        var deltay = M.floor( M.iabs( y1 - y0 ) );
        var error = M.floor( deltax / 2 );
        var y = y0;
        var ystep = if ( y0 < y1 ) 1 else -1;

		if( swapXY )
			// Y / X
			for ( x in x0 ... x1+1 ) {
				pts.push({x:y, y:x});

				error -= deltay;
				if ( error < 0 ) {
					if( x<x1 ) {
						pts.push({x:y+ystep, y:x});
						pts.push({x:y, y:x+1});
					}
					y+=ystep;
					error = error + deltax;
				}
			}
		else
			// X / Y
			for ( x in x0 ... x1+1 ) {
				pts.push({x:x, y:y});

				error -= deltay;
				if ( error < 0 ) {
					if( x<x1 ) {
						pts.push({x:x, y:y+ystep});
						pts.push({x:x+1, y:y});
					}
					y+=ystep;
					error = error + deltax;
				}
			}

		if( swapped && respectOrder )
			pts.reverse();

		return pts;
	}


	// Source : http://en.wikipedia.org/wiki/Midpoint_circle_algorithm
	// Duplicates fix: https://stackoverflow.com/questions/44117168/midpoint-circle-without-duplicates
	/**
	 * Get the points along the edge of a circle at `(x0, y0)` with `radius`.
	 *
	 * If you want the points inside the circle as well, check out `getDisc`.
	 * @param x0 Center x coordinate
	 * @param y0 Center y coordinate
	 * @param radius Radius
	 * @return Array<{x:Int, y:Int}> An array of points along the circle
	 */
	public inline static function getCircle(x0,y0,radius):Array<{x:Int, y:Int}> {
		var pts = [];
		iterateCircle(x0, y0, radius, function(x,y) pts.push( { x:x, y:y } ));
		return pts;
	}

	// Source : http://stackoverflow.com/questions/1201200/fast-algorithm-for-drawing-filled-circles
	/**
	 * Get the points inside a disc at `(x0, y0)` with `radius`.
	 *
	 * If you only want the border, check out `getDisc`.
	 * @param x0 Center x coordinate
	 * @param y0 Center y coordinate
	 * @param radius Radius
	 * @return Array<{x:Int, y:Int}> An array of points filling the disc
	 */
	public static function getDisc(x0,y0,radius):Array<{x:Int, y:Int}> {
		var pts = [];
		iterateDisc(x0, y0, radius, function(x,y) pts.push( { x:x, y:y } ));
		return pts;
	}


	static inline function _checkHorizontal(fx,fy, tx, checkCb:(x:Int,y:Int)->Bool) {
		var valid = true;
		for(x in fx...tx+1)
			if( !checkCb(x,fy) ) {
				valid = false;
				break;
			}
		return valid;
	}




	/**
	 * Check whether for a given disc, a condition holds. Returns `false` if at any time the condition fails. Otherwise, returns `true`.
	 * Not *really* "Bresenham" related, but it's convinient to have this here as well.
	 *
	 * @param fx Top-left corner x coordinate
	 * @param fy Top-left corner y coordinate
	 * @param w Rectangle width
	 * @param h Rectangle width
	 * @param checkCb A condition checked for each tile. If this returns `false`, the whole function returns `false`.
	 * @return Bool Only `true` if for the **all** `checkCb` calls returned `true` as well, otherwise `false`.
	 */
	public static inline function checkRect(fx,fy,w,h, checkCb:(x:Int,y:Int)->Bool) {
		var valid = true;
		for(y in fy...fy+h) {
			for(x in fx...fx+w)
				if( !checkCb(x,y) ) {
					valid = false;
					break;
				}

			if( !valid )
				break;
		}

		return valid;
	}


	/**
	 * Check whether for a given disc, a condition holds. Returns `false` if at any time the condition fails. Otherwise, returns `true`.
	 *
	 * @param x0 Start x coordinate
	 * @param y0 Start y coordinate
	 * @param x1 End x coordinate
	 * @param y1 End y coordinate
	 * @param checkCb A condition checked for each tile. If this returns `false`, the whole function returns `false`.
	 * @return Bool Only `true` if for the **all** `checkCb` calls returned `true` as well, otherwise `false`.
	 */
	public static inline function checkDisc(x0,y0,radius, checkCb:(x:Int,y:Int)->Bool) : Bool {
		var x = radius;
		var y = 0;
		var radiusError = 1-x;
		var valid = true;
		while( x>=y ) {
			if( !_checkHorizontal(-x+x0, y+y0, x+x0, checkCb) ) {// WWS
				valid = false;
				break;
			}

			if( ( radius<=1 || x!=y && y!=0 ) && radiusError>=0 )
				if( !_checkHorizontal(-y+x0, x+y0, y+x0, checkCb) ) {// WSS
					valid = false;
					break;
				}

			if( y!=0 )
				if( !_checkHorizontal(-x+x0, -y+y0, x+x0, checkCb) ) {// WWN
					valid = false;
					break;
				}

			if( ( radius<=1 || x!=y && y!=0 ) && radiusError>=0 )
				if( !_checkHorizontal(-y+x0, -x+y0, y+x0, checkCb) ) {// WNN
					valid = false;
					break;
				}

			y++;
			if( radiusError<0 )
				radiusError += 2*y+1;
			else {
				x--;
				radiusError += 2*(y-x+1);
			}
		}

		return valid;
	}

	/**
	 * A helper function to iterate over all integer tiles of a disc and call a callback
	 * for each one of them.
	 *
	 * If you only want to iterate the border, check out `iterateCircle`.
	 * @param x0 Center x coordinate
	 * @param y0 Center y coordinate
	 * @param radius Radius
	 * @param cb a callback, called for each tile of the disc
	 */
	public static function iterateDisc(x0,y0,radius, cb:(x:Int,y:Int)->Void) {
		var x = radius;
		var y = 0;
		var radiusError = 1-x;
		while( x>=y ) {
			_iterateHorizontal(-x+x0, y+y0, x+x0, cb); // WWS

			if( ( radius<=1 || x!=y && y!=0 ) && radiusError>=0 )
				_iterateHorizontal(-y+x0, x+y0, y+x0, cb); // WSS

			if( y!=0 )
				_iterateHorizontal(-x+x0, -y+y0, x+x0, cb); // WWN

			if( ( radius<=1 || x!=y && y!=0 ) && radiusError>=0 )
				_iterateHorizontal(-y+x0, -x+y0, y+x0, cb); // WNN

			y++;
			if( radiusError<0 )
				radiusError += 2*y+1;
			else {
				x--;
				radiusError += 2*(y-x+1);
			}
		}
	}

	/**
	 * A helper function to iterate over all integer tiles of the border of a circle and call a callback
	 * for each one of them.
	 *
	 * If you want to iterate the whole disc, check out `iterateDisc`.
	 * @param x0 Center x coordinate
	 * @param y0 Center y coordinate
	 * @param radius Radius
	 * @param cb callback, executed for each tile visited
	 */
	public static function iterateCircle(x0,y0,radius, cb:Int->Int->Void) {
		var x = radius;
		var y = 0;
		var radiusError = 1-x;
		while( x>=y ) {
			cb(x+x0, y+y0); // EES
			cb(-x+x0, y+y0); // WWS

			if( x!=y ) {
				cb(y+x0, x+y0); // ESS
				if( y!=0 )
					cb(-y+x0, x+y0); // WSS
			}

			if( y!=0 ) {
				cb(x+x0, -y+y0); // EEN
				cb(-x+x0, -y+y0); // WWN
			}

			if( x!=y ) {
				cb(y+x0, -x+y0); // ENN
				if( y!=0 )
					cb(-y+x0, -x+y0); // WNN
			}

			y++;
			if( radiusError<0 )
				radiusError += 2*y+1;
			else {
				x--;
				radiusError += 2*(y-x+1);
			}
		}
	}


	/**
	 * A helper function to iterate over each tile in a line from `(x0, y0)` to `(x1, y1)` while
	 * allowing diagonal traversal.
	 *
	 * If you do not want to allow diagonals, check out `iterateThickLine`.
	 * If you want to have the list of points instead, check out `getThinLine`.
	 * @param x0 Start x coordinate
	 * @param y0 Start y coordinate
	 * @param x1 End x coordinate
	 * @param y1 End y coordinate
	 * @param cb Callback, executed for each tile visited
	 */
	public inline static function iterateThinLine(x0:Int,y0:Int, x1:Int,y1:Int, cb:Int->Int->Void) {
		var swapXY = M.iabs( y1 - y0 ) > M.iabs( x1 - x0 );
		var tmp : Int;
		if ( swapXY ) {
			// swap x and y
			tmp = x0; x0 = y0; y0 = tmp; // swap x0 and y0
			tmp = x1; x1 = y1; y1 = tmp; // swap x1 and y1
		}
		if ( x0 > x1 ) {
			// make sure x0 < x1
			tmp = x0; x0 = x1; x1 = tmp; // swap x0 and x1
			tmp = y0; y0 = y1; y1 = tmp; // swap y0 and y1
		}
		var deltax = x1 - x0;
		var deltay = Math.floor( M.iabs( y1 - y0 ) );
		var error = Math.floor( deltax / 2 );
		var y = y0;
		var ystep = if ( y0 < y1 ) 1 else -1;

		for ( x in x0 ... x1+1 ) {
			if( swapXY )
				cb(y,x);
			else
				cb(x,y);
			error -= deltay;
			if ( error < 0 ) {
				y+=ystep;
				error = error + deltax;
			}
		}
	}

	/**
	 * A helper function to iterate over each tile in a line from `(x0, y0)` to `(x1, y1)`
	 * without diagonal traversal.
	 *
	 * If you do want allow diagonals, check out `iterateThinLine`.
	 * If you want to have the list of points instead, check out `getThickLine`.
	 * @param x0 Start x coordinate
	 * @param y0 Start y coordinate
	 * @param x1 End x coordinate
	 * @param y1 End y coordinate
	 * @param cb Callback, executed for each tile visited
	 */
	public inline static function iterateThickLine(x0:Int,y0:Int, x1:Int,y1:Int, cb:Int->Int->Void) {
		var swapXY = M.iabs( y1 - y0 ) > M.iabs( x1 - x0 );
		var tmp : Int;
		if ( swapXY ) {
			// swap x and y
			tmp = x0; x0 = y0; y0 = tmp; // swap x0 and y0
			tmp = x1; x1 = y1; y1 = tmp; // swap x1 and y1
		}
		if ( x0 > x1 ) {
			// make sure x0 < x1
			tmp = x0; x0 = x1; x1 = tmp; // swap x0 and x1
			tmp = y0; y0 = y1; y1 = tmp; // swap y0 and y1
		}
		var deltax = x1 - x0;
		var deltay = Math.floor( M.iabs( y1 - y0 ) );
		var error = Math.floor( deltax / 2 );
		var y = y0;
		var ystep = if ( y0 < y1 ) 1 else -1;

		for ( x in x0 ... x1+1 ) {
			if( swapXY )
				cb(y,x);
			else
				cb(x,y);

			error -= deltay;
			if ( error < 0 ) {
				if( x<x1 )
					if( swapXY )
						cb(y,x+1);
					else
						cb(x+1,y);
				y+=ystep;
				error = error + deltax;
			}
		}
	}



	/**
	 * Check whether for a given line, a condition holds. Returns `false` if at any time the condition fails. Otherwise, returns `true`.
	 *
	 * This can be used to check for line of sight for example, or wether the line intersects a specific tile.
	 *
	 * This function does diagonal jumps, if you do not want those, see `checkThickLine`.
	 *
	 * @param x0 Start x coordinate
	 * @param y0 Start y coordinate
	 * @param x1 End x coordinate
	 * @param y1 End y coordinate
	 * @param rayCanPass A condition checked for each tile. If this returns `false`, the whole function returns `false`.
	 * @return Bool Only `true` if for the whole line `rayCanPass` returned `true` as well, otherwise `false`.
	 */
	public inline static function checkThinLine(x0:Int,y0:Int, x1:Int,y1:Int, rayCanPass:Int->Int->Bool):Bool {
		if( !rayCanPass(x0,y0) || !rayCanPass(x1,y1) ){
			return false;
		}else{
			var swapXY = M.iabs( y1 - y0 ) > M.iabs( x1 - x0 );
			var tmp : Int;
			if ( swapXY ) {
				// swap x and y
				tmp = x0; x0 = y0; y0 = tmp; // swap x0 and y0
				tmp = x1; x1 = y1; y1 = tmp; // swap x1 and y1
			}
			if ( x0 > x1 ) {
				// make sure x0 < x1
				tmp = x0; x0 = x1; x1 = tmp; // swap x0 and x1
				tmp = y0; y0 = y1; y1 = tmp; // swap y0 and y1
			}
			var deltax = x1 - x0;
			var deltay = Math.floor( M.iabs( y1 - y0 ) );
			var error = Math.floor( deltax / 2 );
			var y = y0;
			var ystep = if ( y0 < y1 ) 1 else -1;
			var valid = true;

			for ( x in x0 ... x1+1 ) {
				if( swapXY && !rayCanPass(y,x) || !swapXY && !rayCanPass(x,y) ){
					valid = false;
					break;
				}
				error -= deltay;
				if ( error < 0 ) {
					y+=ystep;
					error = error + deltax;
				}
			}
			return valid;
		}
	}


	@:noCompletion
	@:deprecated("Use checkThickLine() instead")
	public static inline function checkFatLine(x0:Int,y0:Int, x1:Int,y1:Int, rayCanPass:Int->Int->Bool) {
		return checkThickLine(x0,y0,x1,y1,rayCanPass);
	}

	/**
	 * Check whether for a given line, a condition holds. Returns `false` if at any time the condition fails. Otherwise, returns `true`.
	 *
	 * This can be used to check for line of sight for example, or wether the line intersects a specific tile.
	 *
	 * This function does not do diagonal jumps, if you do want those, see `checkThinLine`.
	 *
	 * @param x0 Start x coordinate
	 * @param y0 Start y coordinate
	 * @param x1 End x coordinate
	 * @param y1 End y coordinate
	 * @param rayCanPass A condition checked for each tile. If this returns `false`, the whole function returns `false`.
	 * @return Bool Only `true` if for the whole line `rayCanPass` returned `true` as well, otherwise `false`.
	 */
	public inline static function checkThickLine(x0:Int,y0:Int, x1:Int,y1:Int, rayCanPass:Int->Int->Bool):Bool {
		if( !rayCanPass(x0,y0) || !rayCanPass(x1,y1) ){
			return false;
		}else{
			var swapXY = M.iabs( y1 - y0 ) > M.iabs( x1 - x0 );
			var tmp : Int;
			if ( swapXY ) {
				// swap x and y
				tmp = x0; x0 = y0; y0 = tmp; // swap x0 and y0
				tmp = x1; x1 = y1; y1 = tmp; // swap x1 and y1
			}
			if ( x0 > x1 ) {
				// make sure x0 < x1
				tmp = x0; x0 = x1; x1 = tmp; // swap x0 and x1
				tmp = y0; y0 = y1; y1 = tmp; // swap y0 and y1
			}
			var deltax = x1 - x0;
			var deltay = M.floor( M.iabs( y1 - y0 ) );
			var error = M.floor( deltax / 2 );
			var y = y0;
			var ystep = if ( y0 < y1 ) 1 else -1;
			var valid = true;

			if( swapXY )
				// Y / X
				for ( x in x0 ... x1+1 ) {
					if( !rayCanPass(y,x) ){
						valid = false;
						break;
					}

					error -= deltay;
					if ( error < 0 ) {
						if( x<x1 && ( !rayCanPass(y+ystep, x) || !rayCanPass(y, x+1) ) ){
							valid = false;
							break;
						}
						y += ystep;
						error += deltax;
					}
				}
			else
				// X / Y
				for ( x in x0 ... x1+1 ) {
					if( !rayCanPass(x,y) ){
						valid = false;
						break;
					}

					error -= deltay;
					if ( error < 0 ) {
						if( x<x1 && ( !rayCanPass(x, y+ystep) || !rayCanPass(x+1, y) ) ){
							valid = false;
							break;
						}
						y += ystep;
						error += deltax;
					}
				}
			return valid;
		}
	}

	static inline function _iterateHorizontal(fx,fy, tx, cb:Int->Int->Void) {
		for(x in fx...tx+1)
			cb(x,fy);
	}

	@:noCompletion
	public static function __test() {
		CiAssert.noException(
			"Bresenham disc radius",
			iterateDisc(0,0, 2, function(x,y) {
				if( M.floor( Math.sqrt( x*x + y*y ) ) > 2 )
					throw 'Failed at $x,$y';
			})
		);
		CiAssert.noException(
			"Bresenham circle radius",
			iterateCircle(0,0, 2, function(x,y) {
				if( M.round( Math.sqrt( x*x + y*y ) ) != 2 )
					throw 'Failed at $x,$y';
			})
		);

	}
}

