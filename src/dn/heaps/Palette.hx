package dn.heaps;

class Palette {
	public var colors : Array<Col> = [];

	var _cachedClosests : Map<Int,Col> = new Map();

	public var black(get,never): Col;		inline function get_black() return getClosest("#0");
	public var darkGray(get,never): Col;	inline function get_darkGray() return getClosest("#5");
	public var midGray(get,never): Col;		inline function get_midGray() return getClosest("#8");
	public var lightGray(get,never): Col;	inline function get_lightGray() return getClosest("#c");
	public var white(get,never): Col;		inline function get_white() return getClosest("#f");

	public var yellow(get,never): Col;		inline function get_yellow() return getClosest("#ff0");
	public var lightRed(get,never): Col;	inline function get_lightRed() return getClosest("#f00");
	public var lightGreen(get,never): Col;	inline function get_lightGreen() return getClosest("#0f0");
	public var lightBlue(get,never): Col;	inline function get_lightBlue() return getClosest("#00f");
	public var lightOrange(get,never): Col;	inline function get_lightOrange() return getClosest("#fb0");
	public var lightCyan(get,never): Col;	inline function get_lightCyan() return getClosest("#0ff");
	public var lightPink(get,never): Col;	inline function get_lightPink() return getClosest("#f0f");

	public var darkRed(get,never): Col;		inline function get_darkRed() return getClosest("#800");
	public var darkGreen(get,never): Col;	inline function get_darkGreen() return getClosest("#080");
	public var darkBlue(get,never): Col;	inline function get_darkBlue() return getClosest("#008");
	public var darkOrange(get,never): Col;	inline function get_darkOrange() return getClosest("#a80");
	public var darkCyan(get,never): Col;	inline function get_darkCyan() return getClosest("#088");
	public var darkPink(get,never): Col;	inline function get_darkPink() return getClosest("#808");


	public inline function new() {}

	public static function fromPaletteImage(pixels:hxd.Pixels, colorSize=1) : Palette {
		var pal = new Palette();
		var x = 0;
		while( x<pixels.width ) {
			var c : Col = pixels.getPixel(x,0);
			pal.colors.push(c.withoutAlpha());
			x+=colorSize;
		}
		return pal;
	}

	inline function clearCache() {
		_cachedClosests = new Map();
	}

	public inline function addColor(c:Col) {
		colors.push(c);
		clearCache();
	}

	@:keep
	public inline function toString() {
		return 'Palette(${colors.length}): ${colors.map(c->c.toString()).join(",")}';
	}

	public function render(colSizePx=8, ?parent:h2d.Object) : h2d.Flow {
		var f = new h2d.Flow(parent);
		f.layout = Horizontal;
		f.verticalAlign = Top;

		inline function _renderColor(c:Col, f:h2d.Flow) {
			var bmp = new h2d.Bitmap( h2d.Tile.fromColor(c), f );
			bmp.setScale(colSizePx);
		}

		// Palette colors
		for( c in colors )
			_renderColor(c, f);


		// Presets
		inline function _renderColorPair(c1:Col, c2:Col, f:h2d.Flow) {
			var pair = new h2d.Flow(f);
			pair.layout = Vertical;
			_renderColor(c1, pair);
			_renderColor(c2, pair);
		}
		_renderColorPair("#f", white, f);
		_renderColorPair("#c", lightGray, f);
		_renderColorPair("#9", midGray, f);
		_renderColorPair("#5", darkGray, f);
		_renderColorPair("#0", black, f);

		_renderColorPair("#f00", lightRed, f);
		_renderColorPair("#0f0", lightGreen, f);
		_renderColorPair("#00f", lightBlue, f);
		_renderColorPair("#0ff", lightCyan, f);
		_renderColorPair("#f0f", lightPink, f);
		_renderColorPair("#fa0", lightOrange, f);
		_renderColorPair("#ff0", yellow, f);

		_renderColorPair("#800", darkRed, f);
		_renderColorPair("#080", darkGreen, f);
		_renderColorPair("#008", darkBlue, f);
		_renderColorPair("#088", darkCyan, f);
		_renderColorPair("#808", darkPink, f);
		_renderColorPair("#a80", darkOrange, f);

		return f;
	}


	public inline function getClosest(target:Col, useLab=false) : Col {
		if( _cachedClosests.exists(target) )
			return _cachedClosests.get(target);
		else {
			// Search closest palette entry
			var best : Col = 0x0;
			var bestDist = 99.;
			var dist = 0.;
			for(c in colors) {
				dist = useLab ? target.getDistanceLab(c) : target.getDistanceRgb(c);
				if( dist<bestDist ) {
					bestDist = dist;
					best = c;
					if( dist==0 )
						break;
				}
			}
			_cachedClosests.set(target, best);
			return best;
		}
	}

}