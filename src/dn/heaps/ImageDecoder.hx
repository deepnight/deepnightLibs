package dn.heaps;

class ImageDecoder {
	public static function getPixels(b:haxe.io.Bytes) : Null<hxd.Pixels> {
		return try switch dn.Identify.getType(b) {
			case Png: readPng(b);
			case Gif: readGif(b);
			case Jpeg: readJpeg(b);
			case _: null;
		}
		catch( err:String ) {
			return null;
		}
	}


	public static function getTexture(bytes:haxe.io.Bytes) : Null<h3d.mat.Texture> {
		var pixels = getPixels(bytes);
		return pixels==null ? null : h3d.mat.Texture.fromPixels(pixels);
	}




	static function readPng(b:haxe.io.Bytes) : Null<hxd.Pixels> {
		try {
			var i = new haxe.io.BytesInput(b);
			var reader = new format.png.Reader(i);
			var data = reader.read();

			// Read size
			var wid = 0;
			var hei = 0;
			for(e in data)
			switch e {
				case CHeader(h):
					wid = h.width;
					hei = h.height;
				case _:
			}

			// Read pixels
			for(e in data)
			switch e {
				case CData(bytes):
					var pixels = hxd.Pixels.alloc(wid, hei, BGRA);
					format.png.Tools.extract32(data, pixels.bytes, false);

					return pixels;

				case _:
			}
		}
		catch(e:Dynamic) {
			throw "Failed to read PNG";
		}

		return null;
	}

	static function readGif(b:haxe.io.Bytes) : Null<hxd.Pixels> {
		try {
			var i = new haxe.io.BytesInput(b);
			var reader = new format.gif.Reader(i);
			var data = reader.read();

			// Read size & pixels
			var wid = data.logicalScreenDescriptor.width;
			var hei = data.logicalScreenDescriptor.height;
			var pixels = new hxd.Pixels(wid, hei, format.gif.Tools.extractFullBGRA(data, 0), BGRA);
			return pixels;
		}
		catch(e:Dynamic) {
			throw "Failed to read GIF";
		}

		return null;
	}


	static function readJpeg(b:haxe.io.Bytes) : Null<hxd.Pixels> {
		var i = new haxe.io.BytesInput(b);
		i.readUInt16(); // skip header
		i.bigEndian = true;

		// Read size
		var wid = 0;
		var hei = 0;
		while( wid==0 && hei==0 )
			try {
				switch( i.readUInt16() ) {
					case 0xffc0, 0xffc1, 0xffc2 :
						var len = i.readUInt16();
						var prec = i.readByte();
						hei = i.readUInt16();
						wid = i.readUInt16();

					case _:
						var len = i.readUInt16();
						i.read(len-2); // skip Jpeg section
				}
			} catch(e:Dynamic) {} // EOF?

		// Read pixels
		var pixels = _decodeJpeg(b, wid, hei, false);
		return pixels;
	}

	static function _decodeJpeg( src : haxe.io.Bytes, width : Int, height : Int, flipY : Bool ) {
		#if hl

		var dst = haxe.io.Bytes.alloc(width * height * 4);
		if( !hl.Format.decodeJPG(src.getData(), src.length, dst.getData(), width, height, width * 4, BGRA, (flipY?1:0)) )
			return null;
		var pix = new hxd.Pixels(width, height, dst, BGRA);
		if( flipY ) pix.flags.set(FlipY);
		return pix;

		#elseif js

		var d = hxd.res.NanoJpeg.decode(src);
		return new hxd.Pixels(d.width, d.height, d.pixels, BGRA);

		#else

		return null;

		#end
	}
}