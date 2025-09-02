package dn.heaps.assets;

class PixelLookup extends dn.Process {
	public static function fromSlib(slib:dn.heaps.slib.SpriteLib, ?slibPixels:hxd.Pixels, lookupColor:dn.Col) : Map<Int,PixelPoint> {
		var pixels = slibPixels ?? slib.tile.getTexture().capturePixels();

		var col = lookupColor.withAlphaIfMissing();
		var points : Map<Int, PixelPoint> = new Map();
		for(group in slib.getGroups())
		for(frame in group.frames) {
			var pt = lookupSubPixels(pixels, frame.x, frame.y, frame.wid, frame.hei, col);
			if( pt!=null )
				points.set(frame.uid, pt);
		}

		return points;
	}


	public static function replaceColor(slib:dn.heaps.slib.SpriteLib, lookupColor:dn.Col, newColor:dn.Col) {
		var pixels = slib.tile.getTexture().capturePixels();

		for(x in 0...pixels.width)
		for(y in 0...pixels.height) {
			var c : Col = pixels.getPixel(x,y);
			if( c.withoutAlpha()==lookupColor )
				pixels.setPixel(x,y, newColor.withAlphaIfMissing(c.af));
		}
		var newTile = h2d.Tile.fromPixels(pixels);
		slib.tile.switchTexture(newTile);
	}


	/**
	 * Replace multiple colors at once.
	 *
	 * @param remap A map from source color to target color.
	 * @param ignoreSourceAlpha If true, the alpha channel of the source pixel is ignored when matching (only RGB is matched).
	 *                          Otherwise, the alpha channel is considered when matching colors.
	 */
	public static function replaceColors(slib:dn.heaps.slib.SpriteLib, remap:Map<dn.Col, dn.Col>, ignoreSourceAlpha:Bool) {
		var pixels = slib.tile.getTexture().capturePixels();

		var c : Col = 0;
		for(x in 0...pixels.width)
		for(y in 0...pixels.height) {
			c = pixels.getPixel(x,y);
			if( remap.exists( ignoreSourceAlpha ? c.withoutAlpha() : c ) ) {
				var newCol = remap.get( ignoreSourceAlpha ? c.withoutAlpha() : c );
				pixels.setPixel( x,y, newCol );
			}
		}
		var newTile = h2d.Tile.fromPixels(pixels);
		slib.tile.switchTexture(newTile);
	}


	static function lookupSubPixels(pixels:hxd.Pixels, x:Int, y:Int, w:Int, h:Int, col:Col) : Null<PixelPoint> {
		for(px in x...x+w)
		for(py in y...y+h)
			if( pixels.getPixel(px,py)==col )
				return new PixelPoint(px-x, py-y);

		return null;
	}
}


class PixelPoint {
	public var x : Int;
	public var y : Int;

	public inline function new(x:Int, y:Int) {
		this.x = x;
		this.y = y;
	}

	@:keep
	public function tostring() {
		return 'PixelPoint($x,$y)';
	}
}