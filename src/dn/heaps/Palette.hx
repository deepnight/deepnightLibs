package dn.heaps;

class Palette {
	var colors : Array<Col> = [];

	public var black: Col;
	public var white: Col;
	public var yellow: Col;

	public var lightRed: Col;
	public var lightGreen: Col;
	public var lightBlue: Col;
	public var lightOrange: Col;
	public var lightCyan: Col;
	public var lightPink: Col;
	public var lightGray: Col;

	public var darkRed: Col;
	public var darkGreen: Col;
	public var darkBlue: Col;
	public var darkOrange: Col;
	public var darkCyan: Col;
	public var darkPink: Col;
	public var darkGray: Col;

	public function new() {
		refreshQuickAccesses();
	}

	function refreshQuickAccesses() {
		black = getClosest("#000");
		white = getClosest("#fff");
		yellow = getClosest("#ff0");

		lightRed = getClosest("#f00");
		lightGreen = getClosest("#0f0");
		lightBlue = getClosest("#00f");
		lightOrange = getClosest("#fa0");
		lightCyan = getClosest("#0ff");
		lightPink = getClosest("f0f");
		lightGray = getClosest("bbb");

		darkRed = getClosest("#800");
		darkGreen = getClosest("#080");
		darkBlue = getClosest("#008");
		darkOrange = getClosest("#840");
		darkCyan = getClosest("#088");
		darkPink = getClosest("#808");
		darkGray = getClosest("#888");
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

		return p;
	}

	public inline function getClosest(target:Col) {
		var closest : Col = 0x0;
		var closestDist = 99.;
		var dist = 0.;
		for(c in colors) {
			dist = target.getDistance(c);
			if( dist<closestDist ) {
				closestDist = dist;
				closest = c;
				if( dist==0 )
					break;
			}
		}
		return closest;
	}
}