package dn.geom;

class Geom {

	/** Check if rectangle A overlaps rectangle B. **/
	public static inline function rectOverlapsRect(aX:Float, aY:Float, aWid:Float, aHei:Float, bX:Float, bY:Float, bWid:Float, bHei:Float) {
		/*
		Source: https://www.baeldung.com/java-check-if-two-rectangles-overlap

		"The two given rectangles won't overlap if either of the below conditions is true:
			One of the two rectangles is above the top edge of the other rectangle
			One of the two rectangles is on the left side of the left edge of the other rectangle"
		*/
		if( aY+aHei <= bY || bY+bHei <= aY )
			return false;
		else if( aX+aWid <= bX || bX+bWid <= aX )
			return false;
		else
			return true;
	}

	/** Check if rectangle A overlaps or TOUCHES THE EDGES of rectangle B. **/
	public static inline function rectTouchesRect(aX:Float, aY:Float, aWid:Float, aHei:Float, bX:Float, bY:Float, bWid:Float, bHei:Float) {
		/*
		Source: https://www.baeldung.com/java-check-if-two-rectangles-overlap

		"The two given rectangles won't overlap if either of the below conditions is true:
			One of the two rectangles is above the top edge of the other rectangle
			One of the two rectangles is on the left side of the left edge of the other rectangle"
		*/
		if( aY+aHei < bY || bY+bHei < aY )
			return false;
		else if( aX+aWid < bX || bX+bWid < aX )
			return false;
		else
			return true;
	}

	/** Check if a rectangle overlaps (ie. overlaps) with a circle **/
	public static inline function rectOverlapsCircle(rx:Float, ry:Float, rWid:Float, rHei:Float, circleX:Float, circleY:Float, radius:Float) {
		// Find the closest point on the rectangle to the center of the circle
		final closestX = M.fclamp(circleX, rx, rx+rWid);
		final closestY = M.fclamp(circleY, ry, ry+rHei);

		// Calculate the distance between the closest point and the center of the circle
		var dx = closestX - circleX;
		var dy = closestY - circleY;

		// Check if the closest point is inside the circle
		return Math.sqrt( dx*dx + dy*dy ) < radius;
	}


	/** Check if a rectangle overlaps or TOUCHES THE EDGES of a circle **/
	public static inline function rectTouchesCircle(rx:Float, ry:Float, rWid:Float, rHei:Float, circleX:Float, circleY:Float, radius:Float) {
		// Find the closest point on the rectangle to the center of the circle
		final closestX = M.fclamp(circleX, rx, rx+rWid);
		final closestY = M.fclamp(circleY, ry, ry+rHei);

		// Calculate the distance between the closest point and the center of the circle
		var dx = closestX - circleX;
		var dy = closestY - circleY;

		// Check if the closest point is inside the circle
		return Math.sqrt( dx*dx + dy*dy ) <= radius;
	}


	/** Check if circle A overlaps circle B **/
	public static inline function circleOverlapsCircle(xA:Float, yA:Float, rA:Float,  xB:Float, yB:Float, rB:Float) {
		return M.distSqr(xA,yA,xB,yB) < (rA+rB)*(rA+rB);
	}


	/** Check if circle A overlaps or TOUCHES THE EDGES of circle B. **/
	public static inline function circleTouchesCircle(xA:Float, yA:Float, rA:Float,  xB:Float, yB:Float, rB:Float) {
		return M.distSqr(xA,yA,xB,yB) <= (rA+rB)*(rA+rB);
	}


	/** Check if a coordinate is inside a rectangle **/
	public static inline function pointInsideRect(ptX:Float, ptY:Float, rx:Float, ry:Float, rWid:Float, rHei:Float) {
		return ptX>=rx && ptX<rx+rWid && ptY>=ry && ptY<ry+rHei;
	}


	/** Check if a coordinate is inside a circle **/
	public static inline function pointInsideCircle(ptX:Float, ptY:Float, circleX:Float, circleY:Float, radius:Float) {
		return M.distSqr(ptX,ptY, circleX,circleY) <= radius*radius;
	}


	/** Check if segment A intersects segment B **/
	public static function lineIntersectsLine(ax1:Float,ay1:Float,ax2:Float,ay2:Float, bx1:Float,by1:Float,bx2:Float,by2:Float) {
		var denom = ( (by2-by1) * (ax2-ax1)) - ((bx2-bx1) * (ay2-ay1) );
        if( denom==0 )
			return false;  // Lines are parallel
		else {
			var u = ( ( (bx2-bx1) * (ay1-by1) ) - ( (by2-by1) * (ax1-bx1) ) ) / denom;
			if( u<0 || u>1 )
				return false;

			u = ( ( (ax2-ax1) * (ay1-by1) ) - ( (ay2-ay1) * (ax1-bx1) ) ) / denom;
			return u>=0 && u<=1;
		}
	}


	/** Check if segment A intersects segment B **/
	public static function lineIntersectsRect(x1:Float,y1:Float,x2:Float,y2:Float, rx:Float,ry:Float,w:Float,h:Float) {
		if( pointInsideRect(x1,y1, rx,ry,w,h) )
			return true;
		else if( pointInsideRect(x2,y2, rx,ry,w,h) )
			return true;
		else {
			// Check rectangle edges
			if( lineIntersectsLine(x1,y1,x2,y2,  rx, ry, rx, ry+h-1) ) return true; // left edge
			if( lineIntersectsLine(x1,y1,x2,y2,  rx+w-1, ry, rx+w-1, ry+h-1) ) return true; // right edge
			if( lineIntersectsLine(x1,y1,x2,y2,  rx, ry, rx+w-1, ry) ) return true; // top edge
			if( lineIntersectsLine(x1,y1,x2,y2,  rx, ry+h-1, rx+w-1, ry+h-1) ) return true; // bottom edge
		}
		return false;
	}


	/** Iterate a filled centered rectangle. **/
	public static function iterateCenteredRect(centerX:Int, centerY:Int, radiusX:Int, radiusY, cb:Int->Int->Void) {
		for(dy in 0...(radiusY*2+1))
		for(dx in 0...(radiusX*2+1))
			cb( centerX-radiusX+dx, centerY-radiusY+dy );
	}

	/** Iterate a filled centered square. **/
	public static inline function iterateCenteredSquare(centerX:Int, centerY:Int, radius:Int, cb:Int->Int->Void) {
		iterateCenteredRect(centerX, centerY, radius, radius, cb);
	}



	#if deepnightLibsTests
	public static function test() {
		// Point vs Circle
		CiAssert.equals( pointInsideCircle(0,0,  5,0,5), true );
		CiAssert.equals( pointInsideCircle(0,0,  -3,0,5), true );

		CiAssert.equals( pointInsideCircle(0,0,  6,0,5), false );

		// Point vs Rect
		CiAssert.equals( pointInsideRect(0,0,  0,0,10,5), true );
		CiAssert.equals( pointInsideRect(9,0,  0,0,10,5), true );
		CiAssert.equals( pointInsideRect(0,4,  0,0,10,5), true );
		CiAssert.equals( pointInsideRect(9,4,  0,0,10,5), true );

		CiAssert.equals( pointInsideRect(10,0,  0,0,10,5), false );
		CiAssert.equals( pointInsideRect(0,5,  0,0,10,5), false );
		CiAssert.equals( pointInsideRect(-1,0,  0,0,10,5), false );
		CiAssert.equals( pointInsideRect(0,-1,  0,0,10,5), false );

		// Rect vs Rect
		CiAssert.equals( rectOverlapsRect(0,0,10,5,  0,0,10,5), true );
		CiAssert.equals( rectOverlapsRect(0,0,10,5,  1,1,3,3), true );
		CiAssert.equals( rectOverlapsRect(0,0,10,5,  -1,-1,3,3), true );
		CiAssert.equals( rectOverlapsRect(0,0,10,5,  9,0,10,5), true );
		CiAssert.equals( rectOverlapsRect(0,0,10,5,  -10,-10,100,100), true);
		CiAssert.equals( rectTouchesRect(0,0,10,5,  -10,-10,100,100), true);

		CiAssert.equals( rectOverlapsRect(0,0,10,5,  10,0,10,5), false);
		CiAssert.equals( rectTouchesRect(0,0,10,5,  10,0,10,5), true);

		CiAssert.equals( rectOverlapsRect(0,0,10,5,  0,5,10,5), false);
		CiAssert.equals( rectTouchesRect(0,0,10,5,  0,5,10,5), true);

		// Rect vs Circle
		// TODO


		// Centered rect
		for(rx in [0,1,2,3,4])
		for(ry in [0,1,2,3,4]) {
			var n = 0;
			var left = 9999;
			var top = 9999;
			var right = -9999;
			var bottom = -9999;

			CiAssert.noException(
				"Centered rect iteration",
				iterateCenteredRect(0,0,rx,ry, function(x,y) {
					left = M.imin(left, x);
					right = M.imax(right, x);
					top = M.imin(top, y);
					bottom = M.imax(bottom, y);
					n++;
				})
			);

			CiAssert.equals( n, (rx*2+1) * (ry*2+1) );
			CiAssert.equals( left, -rx );
			CiAssert.equals( right, rx );
			CiAssert.equals( top, -ry );
			CiAssert.equals( bottom, ry );
		}

		// Centered square
		for(r in [0,1,2,3,4]) {
			var n = 0;
			var left = 9999;
			var top = 9999;
			var right = -9999;
			var bottom = -9999;

			CiAssert.noException(
				"Centered rect iteration",
				iterateCenteredSquare(0,0, r, function(x,y) {
					left = M.imin(left, x);
					right = M.imax(right, x);
					top = M.imin(top, y);
					bottom = M.imax(bottom, y);
					n++;
				})
			);

			CiAssert.equals( n, Math.pow(r*2+1, 2) );
			CiAssert.equals( left, -r );
			CiAssert.equals( right, r );
			CiAssert.equals( top, -r );
			CiAssert.equals( bottom, r );
		}
	}
	#end
}