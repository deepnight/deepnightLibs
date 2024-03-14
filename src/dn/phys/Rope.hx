package dn.phys;

import dn.struct.FixedArray;

// Credits:
//  "Simulate Tearable Cloth and Ragdolls With Simple Verlet Integration"
//  Jared Counts (inspired by Thomas Jakobsen's Advanced Character Physics)
//  https://code.tutsplus.com/simulate-tearable-cloth-and-ragdolls-with-simple-verlet-integration--gamedev-519t

class Rope {
	public var points : FixedArray<RopePoint>;

	public var rawGravity = 0.085;
	public var gravityMul = 1.;
	public var stiffness = 1.0;
	public var verletInertiaMul = 0.2;
	public var maxSegmentLength = 3.0;

	public var physicsLoops = 3; // should always be more than 3

	var gravity(get,never) : Float; inline function get_gravity() return rawGravity*gravityMul;
	var tmodAccu = 0.;

	public function new(n:Int) {
		points = new FixedArray(n);
		for(i in 0...n) {
			var pt = new RopePoint(this,i);
			points.push(pt);
			if( i>0 )
				pt.attachTo( points.get(i-1) );
		}
	}

	/** Init all points vertically at a specific position */
	public function initAllPoints(x:Float, y:Float, ang=M.PIHALF) {
		var i = 0;
		for(pt in points) {
			pt.setPos(x, y+i*maxSegmentLength);
			i++;
		}
	}

	/** Pin the point specified by its "ratio" in the rope (0-1) to a world position. **/
	public function pinPointRatio(pointIndexRatio:Float, x:Float, y:Float) {
		getPointAtRatio(pointIndexRatio).pinTo(x,y);
	}

	/** Pin the point specified by its index to a world position. **/
	public function pinPointIndex(pointIndex:Int, x:Float, y:Float) {
		points.get(pointIndex).pinTo(x,y);
	}

	/** Attach this rope to another rope */
	public function attachPointToOtherRope(pointIndexRatio:Float, otherRope:Rope, otherRopeIndexRatio:Float) {
		var otherPt = otherRope.getPointAtRatio(otherRopeIndexRatio);
		getPointAtRatio(pointIndexRatio).attachTo(otherPt);
	}

	/** Get a point at a specific ratio along the rope */
	public inline function getPointAtRatio(pointIndexRatio:Float) : RopePoint {
		return points.get( M.round( M.fclamp(pointIndexRatio,0,1) * (points.maxSize-1) ) );
	}

	/**
		Update the rope physics.
		This update is actually using fixed updates. So the internal values are updated at a fixed rate. But to get a smoother rendering, the actual display coordinates are lerped between the last and current values.
	*/
	public function frameUpdate(tmod:Float) {
		tmodAccu += tmod;
		while( tmodAccu>=1 ) {
			fixedUpdate();
			tmodAccu -= 1;
		}
	}

	function fixedUpdate() {
		// Remember last pos for lerping
		@:privateAccess
		for(pt in points) {
			pt.lastX = pt.curX;
			pt.lastY = pt.curY;
		}

		// Physics
		for(pt in points)
			pt.updatePhysics();

		// Links and other constraints
		for(i in 0...physicsLoops)
		for(pt in points)
			pt.updateAllConstraints();
	}
}



@:access(dn.phys.Rope)
@:allow(dn.phys.Rope)
class RopePoint {
	var rope : Rope;

	/** Index of this point in the rope */
	public var index(default,null) : Int;

	/** Ratio of this point in the rope (0 to 1) */
	public var toOneRatio(get,never) : Float;

	/** Ratio of this point in the rope (1 to 0) */
	public var toZeroRatio(get,never) : Float;

	public var weight = 1.;
	public var links : Array<RopeLink> = [];

	/** Current x position, lerped between lastX and curX */
	public var x(get,never) : Float; inline function get_x() return M.lerp(lastX, curX, rope.tmodAccu);

	/** Current y position, lerped between lastY and curY */
	public var y(get,never) : Float; inline function get_y() return M.lerp(lastY, curY, rope.tmodAccu);

	/** Current rounded x position, lerped between lastX and curX */
	public var xi(get,never) : Int; inline function get_xi() return M.round(x);

	/** Current rounded y position, lerped between lastY and curY */
	public var yi(get,never) : Int; inline function get_yi() return M.round(y);

	// Current resulting coordinates
	var curX = 0.;
	var curY = 0.;
	// Previous resulting coordinates
	var lastX = 0.;
	var lastY = 0.;

	public var wind : dn.phys.Velocity;
	public var extraVelocity : dn.phys.Velocity;

	// Pinned coordinates
	var pinX = -1.;
	var pinY = -1.;

	// Pre-allocated internal vars
	var _verletX = 0.;
	var _verletY = 0.;
	var _lastPhysX = -1.;
	var _lastPhysY = -1.;
	var _nextPhysX = 0.;
	var _nextPhysY = 0.;
	var _dx = 0.;
	var _dy = 0.;


	public function new(r,i) {
		rope = r;
		index = i;
		wind = new dn.phys.Velocity();
		extraVelocity = new dn.phys.Velocity();
	}

	/** Attach this point to another point */
	public function attachTo(pt) {
		var link = new RopeLink(rope, this, pt);
		links.push(link);
		return link;
	}

	/** Pin this point to fixed coordinates in the world */
	public inline function pinTo(x,y) {
		pinX = x;
		pinY = y;
	}

	/** Unpin this point */
	public inline function unpin() {
		pinX = -1;
		pinY = -1;
	}

	public inline function isPinned() return pinX!=-1 || pinY!=-1;

	inline function get_toOneRatio() {
		return index / (rope.points.maxSize-1);
	}

	inline function get_toZeroRatio() {
		return 1-toOneRatio;
	}

	/** Manually set the position of this point */
	public inline function setPos(x,y) {
		this.curX = x;
		this.curY = y;
	}


	public function updateAllConstraints() {
		// Links constraints
		for(link in links)
			link.updateConstraint();

		// Pin
		if( isPinned() ) {
			curX = pinX;
			curY = pinY;
		}
	}

	function updatePhysics() {
		if( _lastPhysX==-1 ) {
			// Init
			_lastPhysX = curX;
			_lastPhysY = curY;
		}
		else {
			// Preserve some momentum
			_verletX = curX - _lastPhysX;
			_verletY = curY - _lastPhysY;
			_verletX *= rope.verletInertiaMul;
			_verletY *= rope.verletInertiaMul;

			_dx = wind.x + extraVelocity.x;
			_dy = weight*rope.gravity + wind.y + extraVelocity.y;

			// Prepare next pos
			_nextPhysX = curX + _verletX + 0.5*_dx;
			_nextPhysY = curY + _verletY + 0.5*_dy;

			// Apply
			_lastPhysX = curX;
			_lastPhysY = curY;
			curX = _nextPhysX;
			curY = _nextPhysY;
		}

		// Velocities
		wind.frameUpdate(1);
		extraVelocity.frameUpdate(1);
	}
}


@:access(dn.phys.Rope)
@:allow(dn.phys.Rope)
class RopeLink {
	var rope : Rope;

	/** Max distance multiplier for this link */
	public var maxDistMul = 1.;

	/** Start point of this link */
	public var ptA : RopePoint;

	/** End point of this link */
	public var ptB : RopePoint;

	// Pre-allocated internal vars
	var _distX = 0.;
	var _distY = 0.;
	var _dist = 0.;
	var _diffRatio = 0.;
	var _iw1 = 0.;
	var _iw2 = 0.;
	var _scalarP1 = 0.;
	var _scalarP2 = 0.;


	public function new(r,a,b) {
		rope = r;
		ptA = a;
		ptB = b;
	}

	function updateConstraint() {
		_distX = ptA.curX - ptB.curX;
		_distY = ptA.curY - ptB.curY;
		_dist = Math.sqrt(_distX*_distX + _distY*_distY);

		if( _dist>=rope.maxSegmentLength*maxDistMul ) {
			_diffRatio = ( (rope.maxSegmentLength*maxDistMul) - _dist ) / _dist;

			_iw1 = 1 / ptA.weight;
			_iw2 = 1 / ptB.weight;
			_scalarP1 = ( _iw1 / (_iw1+_iw2) ) * rope.stiffness;
			_scalarP2 = rope.stiffness - _scalarP1;

			ptA.curX += _distX * _diffRatio * _scalarP1;
			ptA.curY += _distY * _diffRatio * _scalarP1;

			ptB.curX -= _distX * _diffRatio * _scalarP2;
			ptB.curY -= _distY * _diffRatio * _scalarP2;
		}
	}
}