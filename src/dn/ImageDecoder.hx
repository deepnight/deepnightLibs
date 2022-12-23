package dn;

typedef DecodedImage = {
	var decodedBytes: haxe.io.Bytes; // pixels in BGRA format
	var width: Int;
	var height: Int;
}

class ImageDecoder {
	public static var lastError : Null<String>;

	public static function decode(fileContent:haxe.io.Bytes) : Null<DecodedImage> {
		lastError = null;
		return try switch dn.Identify.getType(fileContent) {
			case Png: decodePng(fileContent);
			case Gif: decodeGif(fileContent);
			case Jpeg: decodeJpeg(fileContent);

			case Aseprite:
				#if heaps_aseprite
					decodeAsepriteMainTexture(fileContent);
				#else
					throw('[ImageDecoder] Aseprite decoding requires both "heaps-aseprite" and "ase" libs (run "haxelib install ase" and "haxelib install heaps-aseprite").');
					null;
				#end

			case _: null;
		}
		catch( err:String ) {
			lastError = err;
			return null;
		}
	}

	#if heaps
	public static function decodePixels(fileContent:haxe.io.Bytes) : Null<hxd.Pixels> {
		var img = decode(fileContent);
		return img==null ? null : new hxd.Pixels(img.width, img.height, img.decodedBytes, BGRA);
	}

	public static function decodeTexture(fileContent:haxe.io.Bytes) : Null<h3d.mat.Texture> {
		var pixels = decodePixels(fileContent);
		return pixels==null ? null : h3d.mat.Texture.fromPixels(pixels);
	}

	public static function decodeTile(fileContent:haxe.io.Bytes) : Null<h2d.Tile> {
		var pixels = decodePixels(fileContent);
		return pixels==null ? null : h2d.Tile.fromPixels(pixels);
	}
	#end




	static function decodePng(b:haxe.io.Bytes) : Null<DecodedImage> {
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
					var dst = haxe.io.Bytes.alloc(wid*hei*4);
					format.png.Tools.extract32(data, dst, false);

					return {
						width: wid,
						height: hei,
						decodedBytes: dst,
					};

				case _:
			}
		}
		catch(e:Dynamic) {
			throw "Failed to read PNG, err="+e;
		}

		return null;
	}

	static function decodeGif(b:haxe.io.Bytes) : Null<DecodedImage> {
		try {
			var i = new haxe.io.BytesInput(b);
			var reader = new format.gif.Reader(i);
			var data = reader.read();

			return {
				width: data.logicalScreenDescriptor.width,
				height: data.logicalScreenDescriptor.height,
				decodedBytes: format.gif.Tools.extractFullBGRA(data, 0),
			}
		}
		catch(e:Dynamic) {
			throw "Failed to read GIF";
		}

		return null;
	}


	static function decodeJpeg(encoded:haxe.io.Bytes) : Null<DecodedImage> {

		#if hl

		// Read image size
		var width = 0;
		var height = 0;
		var i = new haxe.io.BytesInput(encoded);
		i.readUInt16(); // skip header
		i.bigEndian = true;
		while( width==0 && height==0 )
			try {
				switch( i.readUInt16() ) {
					case 0xffc0, 0xffc1, 0xffc2 :
						var len = i.readUInt16();
						var prec = i.readByte();
						height = i.readUInt16();
						width = i.readUInt16();

					case _:
						var len = i.readUInt16();
						i.read(len-2); // skip Jpeg section
				}
			} catch(e:Dynamic) {} // EOF?

		// Decode
		var decoded = haxe.io.Bytes.alloc(width * height * 4);
		if( !hl.Format.decodeJPG( encoded.getData(), encoded.length, decoded.getData(), width, height, width * 4, BGRA, 0 ) )
			return null;
		else
			return {
				width: width,
				height: height,
				decodedBytes: decoded,
			}

		#elseif( js && heaps )

		var d = hxd.res.NanoJpeg.decode(encoded);
		return {
			width: d.width,
			height: d.height,
			decodedBytes: d.pixels,
		}

		#else

		return null;

		#end
	}


	/** Thanks to Austin East lib "heaps-aseprite" **/
	#if heaps_aseprite
	static function decodeAsepriteMainTexture(encoded:haxe.io.Bytes) : Null<DecodedImage> {

		try {
			// Read Aseprite file
			var ase = aseprite.Aseprite.fromBytes(encoded);

			// Extract pixels as BGRA
			var pixels = ase.getTexture().capturePixels();
			pixels.convert(BGRA);

			return {
				decodedBytes: pixels.bytes,
				width: pixels.width,
				height: pixels.height,
			}
		}
		catch(e:Dynamic) {
			lastError = Std.string(e);
			return null;
		}

	}
	#end

}