package dn;

typedef DecodedImage = {
	var bytes: haxe.io.Bytes;
	var width: Int;
	var height: Int;
}

class ImageDecoder {

	public static function run(fileContent:haxe.io.Bytes) : Null<DecodedImage> {
		return try switch dn.Identify.getType(fileContent) {
			case Png: decodePng(fileContent);
			case Gif: decodeGif(fileContent);
			case Jpeg: decodeJpeg(fileContent);
			case _: null;
		}
		catch( err:String ) {
			return null;
		}
	}

	#if heaps
	public static function getPixels(fileContent:haxe.io.Bytes) : Null<hxd.Pixels> {
		var img = run(fileContent);
		return img==null ? null : new hxd.Pixels(img.width, img.height, img.bytes, BGRA);
	}

	public static function getTexture(fileContent:haxe.io.Bytes) : Null<h3d.mat.Texture> {
		var pixels = getPixels(fileContent);
		return pixels==null ? null : h3d.mat.Texture.fromPixels(pixels);
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
						bytes: dst,
					};

				case _:
			}
		}
		catch(e:Dynamic) {
			throw "Failed to read PNG";
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
				bytes: format.gif.Tools.extractFullBGRA(data, 0),
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
		if( !hl.Format.decodeJPG( encoded.getData(), encoded.length, decoded.getData(), width, height, width * 4, BGRA, 0 )
			return null;
		else
			return {
				width: width,
				height: height,
				bytes: decoded,
			}

		#elseif( js && heaps )

		var d = hxd.res.NanoJpeg.decode(encoded);
		return {
			width: d.width,
			height: d.height,
			bytes: d.pixels,
		}

		#else

		return null;

		#end
	}
}