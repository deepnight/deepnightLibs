package dn.pathfinder;

// **** Path-finder ************************************************************
// Source: https://briangrinstead.com/blog/astar-search-algorithm-in-javascript/

@:allow(dn.pathfinder.PathNode)
class AStar<T> {
	var nodes : Array<PathNode> = [];
	var collisions : Map<Int,Bool> = new Map();
	public var wid(default,null) = -1;
	public var hei(default,null) = -1;

	var nodeToPoint : (Int,Int)->T;

	public function new(nodeToPoint:(Int,Int)->T) {
		this.nodeToPoint = nodeToPoint;
	}

	public function init(w:Int, h:Int, hasCollision:(Int,Int)->Bool) {
		wid = w;
		hei = h;
		this.hasCollision = hasCollision;
		nodes = [];
		for(cy in 0...hei)
		for(cx in 0...wid) {
			if( hasCollision(cx-1,cy-1) && !hasCollision(cx,cy-1) && !hasCollision(cx-1,cy)
				|| hasCollision(cx+1,cy-1) && !hasCollision(cx,cy-1) && !hasCollision(cx+1,cy)
				|| hasCollision(cx+1,cy+1) && !hasCollision(cx,cy+1) && !hasCollision(cx+1,cy)
				|| hasCollision(cx-1,cy+1) && !hasCollision(cx,cy+1) && !hasCollision(cx-1,cy) )
				nodes.push( new PathNode(this, cx,cy) );
		}

		for(n in nodes)
		for(n2 in nodes)
			if( n!=n2 && sightCheck(n.cx, n.cy, n2.cx, n2.cy) )
				n.link(n2);
	}

	public function dispose() {
		nodes = null;
		collisions = null;
		nodeToPoint = null;
	}


	dynamic function hasCollision(cx,cy) return false;
	public dynamic function canSeeThrough(cx,cy) return !hasCollision(cx,cy);

	inline function sightCheck(fx,fy, tx,ty) {
		return dn.geom.Bresenham.checkThinLine(fx,fy, tx,ty, canSeeThrough);
	}

	function getNodeAt(cx,cy) {
		for(n in nodes)
			if( n.cx==cx && n.cy==cy )
				return n;
		return null;
	}

	public function getPath(fx:Int, fy:Int, tx:Int, ty:Int) {
		if( wid<0 )
			throw "AStar.init() should be called first.";

		// Simple case
		if( sightCheck(fx,fy,tx,ty) )
			return [ nodeToPoint(tx,ty) ];

		// Init network
		for(n in nodes)
			n.initBeforeAStar();

		// Add start & end as PathNodes to existing node network
		var addeds = 0;
		var start = getNodeAt(fx,fy);
		if( start==null ) {
			addeds++;
			start = new PathNode(this, fx,fy);
			for(n in nodes)
				if( sightCheck(start.cx, start.cy, n.cx, n.cy) ) start.link(n, true);
			nodes.push(start);
		}
		var end = getNodeAt(tx,ty);
		if( end==null ) {
			addeds++;
			end = new PathNode(this, tx,ty);
			for(n in nodes)
				if( sightCheck(end.cx, end.cy, n.cx, n.cy) ) end.link(n, true);
			nodes.push(end);
		}

		// Get path
		var path = astar(start,end).map( function(n) return nodeToPoint(n.cx,n.cy) );
		for(i in 0...addeds)
			nodes.pop();
		return path;
	}


	function astar(start:PathNode, end:PathNode) {
		var opens = [start];
		var openMarks = new Map();
		openMarks.set(start.id,true);
		var closedMarks = new Map();

		while( opens.length>0 ) {
			// Gets next best
			var best = -1;
			for(i in 0...opens.length)
				if( best<0 || opens[i].distTotalSqr(end.cx,end.cy) < opens[best].distTotalSqr(end.cx,end.cy) )
					best = i;

			var cur = opens[best];

			// Found path
			if( cur==end ) {
				// Build path output & clean useless nodes
				var path = [cur];
				var n = getDeepestParentOnSight(cur);
				while( n!=null ) {
					path.push(n);
					n = getDeepestParentOnSight(n);
				}
				path.reverse();
				return path;
			}

			// Update lists
			closedMarks.set(cur.id, true);
			opens.splice(best,1);
			openMarks.remove(cur.id);

			var i = 0;
			for(n in cur.nexts) {
				if( closedMarks.exists(n.id) )
					continue;

				var homeDist = cur.homeDist + cur.distSqr(n.cx,n.cy);
				var isBetter = false;

				if( !openMarks.exists(n.id) ) {
					// Found new node
					isBetter = true;
					opens.push(n);
					openMarks.set(n.id, true);
				}
				else if( homeDist<n.homeDist ) {
					// Found a better way to get here
					isBetter = true;
				}

				if( isBetter ) {
					// Update visited node
					n.parent = cur;
					n.homeDist = homeDist;
					i++;
				}
			}
		}
		return [];
	}

	function getDeepestParentOnSight(cur:PathNode) : Null<PathNode> {
		var n = cur.parent;
		var lastSight = n;
		while( n!=null ) {
			if( sightCheck(cur.cx, cur.cy, n.cx, n.cy) )
				lastSight = n;
			else
				return lastSight;
			n = n.parent;
		}
		return null;
	}


	// UNIT TESTS
	#if deepnightLibsTests
	public static function test() {
		// Build a basic map for pathfinder
		var matrix = [
			"...#.",
			".###.",
			"...#.",
			".#.#.",
			".#.#.",
			".#...",
		];
		var wid = matrix[0].length;
		var hei = matrix.length;
		var targetX = wid-1;
		var targetY = 0;
		CiAssert.printIfVerbose("\t"+matrix.join("\n\t"));

		// Pathfinder
		var pf = new dn.pathfinder.AStar( function(x,y) return {x:x, y:y} );
		pf.init(
			wid, hei,
			function(x,y) return x>=0 && y>=0 && x<wid && y<hei ? matrix[y].charAt(x)=="#" : true
		);
		var path = pf.getPath(0, 0, targetX, targetY);
		CiAssert.printIfVerbose("	Path="+path.map( function(pt) return pt.x+","+pt.y ).join(" -> ") );
		CiAssert.isTrue( path.length>0 );
		CiAssert.isTrue( path[path.length-1].x==targetX && path[path.length-1].y==targetY );
	}
	#end
}


// **** Node ************************************************************

private class PathNode {
	public var id : Int;
	public var cx : Int;
	public var cy : Int;
	public var nexts : Array<PathNode> = [];
	var originalNexts: Array<PathNode> = [];

	// For astar
	public var homeDist = 0.;
	public var parent : Null<PathNode>;

	public function new(as:AStar<Dynamic>, x,y) {
		cx = x;
		cy = y;
		id = cx + cy*as.wid;
	}

	public function toString() return 'Node@$cx,$cy';

	public function initBeforeAStar() {
		homeDist = 0;
		parent = null;
		nexts = originalNexts.copy();
	}

	public inline function distSqr(tx,ty) return M.distSqr(cx,cy,tx,ty);
	public inline function distTotalSqr(tx,ty) return homeDist + M.distSqr(cx,cy,tx,ty);

	public function link(n:PathNode, ?tmpLink=false) {
		if( tmpLink ) {
			nexts.push(n);
			n.nexts.push(this);
		}
		else {
			originalNexts.push(n);
			n.originalNexts.push(this);
		}
	}
}
