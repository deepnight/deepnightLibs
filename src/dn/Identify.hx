package dn;

// Inspired by: https://github.com/maitag/whatformat
class Identify {
	static var formats = [
		// Note: "-1" means "any byte"
		{ id:"png",  magic:[0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A] },

		{ id:"gif",  magic:[0x47,0x49,0x46,0x38,0x37,0x61] }, // Gif 87a
		{ id:"gif",  magic:[0x47,0x49,0x46,0x38,0x39,0x61] }, // Gif 89a

		{ id:"jpeg", magic:[0xFF,0xD8,0xFF] }, // Jpeg raw
		{ id:"jpeg", magic:[0xFF,0xD8,0xFF,0xDB] }, // Jpeg raw
		{ id:"jpeg", magic:[0xFF,0xD8,0xFF,0xE0,-1,-1,0x4A,0x46,0x49,0x46,0x00,0x01] }, // Jpeg JFIF
		{ id:"jpeg", magic:[0xFF,0xD8,0xFF,0xE1,-1,-1,0x45,0x78,0x69,0x66,0x00,0x00] }, // Jpeg EXIF
	];

	public static function getType(b:haxe.io.Bytes) : Null<String> {
		for(f in formats)
			if( matchHeader(b, f.magic) )
				return f.id;

		return null;
	}

	static function matchHeader(b:haxe.io.Bytes, magicNumbers:Array<Int>) {
		for( idx in 0...magicNumbers.length )
			if( idx>=b.length || magicNumbers[idx]!=b.get(idx) && magicNumbers[idx]>=0 )
				return false;

		return true;
	}
}