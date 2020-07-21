package dn;

// Inspired by: https://github.com/maitag/whatformat
// Signatures: https://en.wikipedia.org/wiki/List_of_file_signatures

enum IdentifyFormat {
	Unknown;
	// Images
	Png;
	Jpeg;
	Gif;
	Bmp;
}

class Identify {
	static var formats = [
		// Note: "-1" means "any byte"
		{ id:Png,  magic:[0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A] },

		{ id:Gif,  magic:[0x47,0x49,0x46,0x38,0x37,0x61] }, // Gif 87a
		{ id:Gif,  magic:[0x47,0x49,0x46,0x38,0x39,0x61] }, // Gif 89a

		{ id:Jpeg, magic:[0xFF,0xD8,0xFF] }, // Jpeg raw
		{ id:Jpeg, magic:[0xFF,0xD8,0xFF,0xDB] }, // Jpeg raw
		{ id:Jpeg, magic:[0xFF,0xD8,0xFF,0xE0,-1,-1,0x4A,0x46,0x49,0x46,0x00,0x01] }, // Jpeg JFIF
		{ id:Jpeg, magic:[0xFF,0xD8,0xFF,0xE1,-1,-1,0x45,0x78,0x69,0x66,0x00,0x00] }, // Jpeg EXIF

		{ id:Bmp,  magic:[0x42,0x4d] },
	];

	public static function getType(b:haxe.io.Bytes) : IdentifyFormat {
		if( b==null )
			return Unknown;

		for(f in formats)
			if( matchHeader(b, f.magic) )
				return f.id;

		return Unknown;
	}

	public static function is64BitsExe(first1024bytes:haxe.io.Bytes) {
		if( first1024bytes==null )
			return false;

		var header = "PE".split("").map(function(c) return c.charCodeAt(0));
		var i = 0;
		while( i<first1024bytes.length-6 )
			if( first1024bytes.get(i)==header[0] && first1024bytes.get(i+1)==header[1] && first1024bytes.getUInt16(i+4)==0x8664 )
				return true;
			else
				i++;

		return false;
	}


	static function matchHeader(b:haxe.io.Bytes, magicNumbers:Array<Int>) {
		for( idx in 0...magicNumbers.length )
			if( idx>=b.length || magicNumbers[idx]!=b.get(idx) && magicNumbers[idx]>=0 )
				return false;

		return true;
	}
}