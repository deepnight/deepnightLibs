package dn.heaps.assets;

class PixelLookup extends dn.Process {
	public static function fromSlib(slib:dn.heaps.slib.SpriteLib, ?slibPixels:hxd.Pixels) : Map<Int,PixelCoord> {
		if( slibPixels==null )
			slibPixels = slib.tile.getTexture().capturePixels();

		var pixelCoords : Map<Int, PixelCoord> = new Map();
		var output = new PixelCoord(0,0);
		for(group in slib.getGroups())
		for(fd in group.frames)
			if( lookupPixelSub(slibPixels, fd.x, fd.y, fd.wid, fd.hei, "#0400ff", output) )
				pixelCoords.set(fd.uid, output.clone());

		return pixelCoords;
	}

	static function lookupPixelSub(slibPixels:hxd.Pixels, x:Int, y:Int, w:Int, h:Int, col:Col, output:PixelCoord) {
		col = col.withAlphaIfMissing();
		for(px in x...x+w)
		for(py in y...y+h)
			if( slibPixels.getPixel(px,py)==col ) {
				output.x = px;
				output.y = py;
				return true;
			}

		output.x = output.y = -1;
		return false;
	}
}


class PixelCoord {
	public var x : Int;
	public var y : Int;

	public inline function new(x:Int, y:Int) {
		this.x = x;
		this.y = y;
	}

	@:keep public function tostring() {
		return 'PixelCoord($x,$y)';
	}

	public inline function clone() {
		return new PixelCoord(x,y);
	}
}