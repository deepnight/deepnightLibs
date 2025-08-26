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