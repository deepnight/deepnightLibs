package dn.heaps;

class Palette {
	var colors : Array<Col> = [];

	public var red(default,null) : Col;
	public var green(default,null) : Col;
	public var blue(default,null) : Col;

	public function new() {
		refreshQuickAccesses();
	}

	public function addColor(c:Col) {
		colors.push(c);
		refreshQuickAccesses();
	}

	@:keep
	public inline function toString() {
		return 'Palette(${colors.length}): ${colors.map(c->c.toString()).join(",")}';
	}

	public static function fromImage(pixels:hxd.Pixels, colorSize=1) {
		var p = new Palette();
		var x = 0;
		while( x<pixels.width ) {
			var c : Col = pixels.getPixel(x,0);
			p.colors.push(c.withoutAlpha());
			x+=colorSize;
		}
		p.refreshQuickAccesses();
		trace(p);

		return p;
	}

	inline function getClosest(target:Col) {
		var closest : Col = 0x0;
		var closestDist = 99.;
		for(c in colors) {
			var dist = target.getDistance(c);
			if( dist<closestDist ) {
				closestDist = dist;
				closest = c;
			}
		}
		return closest;
	}

	function refreshQuickAccesses() {
		red = getClosest("#f00");
		green = getClosest("#0f0");
		blue = getClosest("#00f");
		trace(red);
		trace(green);
		trace(blue);
	}
}