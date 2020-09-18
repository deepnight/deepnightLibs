package dn;

class Log {
	var maxEntries : Int;
	public var log : Array<{ str:String, c:UInt }> = [];
	public var printOnAdd = false;

	public function new(maxEntries:Int) {
		log = [];
		this.maxEntries = maxEntries;
	}

	public inline function add(tag:String, text:String, ?c=0xffffff) {
		var str = '[${tag.toUpperCase()}] $text';
		log.push({ str:str, c:c });

		if( log.length>maxEntries )
			log = log.splice(-maxEntries, maxEntries);

		if( printOnAdd )
			printEntry(str,c);
	}

	public inline function general(str:Dynamic)	add("general", str, Color.hexToInt("#ffcc00") );
	public inline function warning(str:Dynamic)	add("warning", str, Color.hexToInt("#ff9900") );
	public inline function error(str:Dynamic)	add("error", str, Color.hexToInt("#ff0000") );
	public inline function fileOp(str:Dynamic)	add("file", str, Color.hexToInt("#c3b2ff"));
	public inline function render(str:Dynamic)	add("render", str, Color.hexToInt("#a7db4f"));
	public inline function debug(str:Dynamic)	add("debug", str, Color.hexToInt("#ff00ff"));

	public function dumpToH2dConsole(c:h2d.Console) {
		for(l in log)
			c.log(l.str, l.c);
	}

	function printEntry(str:String, c:UInt) {
		#if js
		var bgColor = Color.autoContrast( c, Color.toBlack(c,0.7), Color.toWhite(c,0.7) );
		js.html.Console.log(
			"%c"+str,
			'color: ${dn.Color.intToHex(c)}; background: ${dn.Color.intToHex(bgColor)}; padding: 2px; border-radius: 3px');
		#else
		trace(l.str, l.c);
		#end
	}

	public function dump() {
		for(l in log)
			printEntry(l.str, l.c);
	}
}