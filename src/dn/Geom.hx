package dn;

class Geom {

	/** Return TRUE if rectangle A touches or Collides rectangle B. **/
	// public static inline function rectTouchesRect(aX:Float, aY:Float, aWid:Float, aHei:Float, bX:Float, bY:Float, bWid:Float, bHei:Float) {
	// 	/*
	// 	Source: https://www.baeldung.com/java-check-if-two-rectangles-overlap

	// 	"The two given rectangles won't overlap if either of the below conditions is true:
	// 		One of the two rectangles is above the top edge of the other rectangle
	// 		One of the two rectangles is on the left side of the left edge of the other rectangle"
	// 	*/
	// 	if( aY+aHei < bY || bY+bHei < aY )
	// 		return false;
	// 	else if( aX+aWid < bX || bX+bWid < aX )
	// 		return false;
	// 	else
	// 		return true;
	// }


	/** Return TRUE if rectangle A Collides rectangle B. **/
	public static inline function rectCollidesRect(aX:Float, aY:Float, aWid:Float, aHei:Float, bX:Float, bY:Float, bWid:Float, bHei:Float) {
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

	public static inline function rectCollidesCircle(rx:Float, ry:Float, rWid:Float, rHei:Float, circleX:Float, circleY:Float, radius:Float) {
		// Find the closest point on the rectangle to the center of the circle
		final closestX = M.fclamp(circleX, rx, rx+rWid);
		final closestY = M.fclamp(circleY, ry, ry+rHei);

		// Calculate the distance between the closest point and the center of the circle
		var dx = closestX - circleX;
		var dy = closestY - circleY;

		// Check if the closest point is inside the circle
		return Math.sqrt( dx*dx + dy*dy ) <= radius;
	}



	public static inline function circleCollidesCircle(xA:Float, yA:Float, rA:Float,  xB:Float, yB:Float, rB:Float) {
		return M.distSqr(xA,yA,xB,yB) <= (rA+rB)*(rA+rB);
	}


	@:noCompletion
	public static function __test() {
		// TODO
	}
}