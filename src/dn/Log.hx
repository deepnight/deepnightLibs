package dn;

typedef LogEntry = {
	var time: Float;
	var tag: String;
	var str: String;
	var color: UInt;
	var flushed: Bool;
}

class Log {
	var maxEntries : Int;
	public var log : Array<LogEntry> = [];

	/**
		Will be used as default path when calling flushToFile()
	**/
	public var logFilePath : Null<String>;

	/**
		If TRUE, every add() call will also call printEntry()
	**/
	public var printOnAdd = false;

	/**
		If TRUE, the date will also be visible in printEntry()
	**/
	public var printDate = false;

	#if heaps
	/**
		Optional output Console used by printEntry()
	**/
	public var outputConsole : Null<h2d.Console>;
	#end



	public function new(maxEntries:Int) {
		log = [];
		this.maxEntries = maxEntries;
	}


	/**
		Dump all non-flushed log entries to the corresponding file
	**/
	public function flushToFile(?filePath:String) {
		if( filePath==null )
			filePath = logFilePath;

		if( filePath==null )
			return;

		try {
			#if sys

				var fo = sys.io.File.append(filePath, false);
				for(l in log)
					if( !l.flushed ) {
						fo.writeString( getPrintableEntry(l,true)+"\n" );
						l.flushed = true;
					}

			#elseif hxnodejs

				var flushedLogs = log.filter( function(l) {
					if( !l.flushed ) {
						l.flushed = true;
						return true;
					}
					return false;
				});

				js.node.Require.require("fs");
				for(l in flushedLogs)
					js.node.Fs.appendFileSync( filePath, js.node.Buffer.from( getPrintableEntry(l,true)+"\n") );

			#else

				// Unsupported on this platform

			#end
		}
		catch( e:Dynamic ) {}
	}



	function getPrintableEntry(l:LogEntry, forceDate=false) {
		if( l.str.length==0 )
			return "";

		var date = formatDate(l.time);
		return
			'[${l.tag.toUpperCase()}]'
			+ fillSpaces(l.tag.length+2, 15)
			+ ( forceDate || printDate ? date + fillSpaces(date.length, 22) : "" )
			+ l.str;
	}

	inline function fillSpaces(curLen:Int, desiredLen:Int) {
		var out = "";
		for(i in curLen...desiredLen)
			out+=" ";
		return out;
	}


	/** Add an entry, "color" is not support for all outputs. **/

	public inline function add(tag:String, text:String, ?color=0xffffff) {
		log.push({
			time: Date.now().getTime(),
			tag: tag,
			str: text,
			color: color,
			flushed: false
		});

		if( log.length>maxEntries )
			log = log.splice(-maxEntries, maxEntries);

		if( printOnAdd )
			printEntry( log[log.length-1] );
	}

	public inline function emptyEntry()			add("","");
	public inline function general(str:Dynamic)	add("general", str, Color.hexToInt("#ffcc00") );
	public inline function warning(str:Dynamic)	add("warning", str, Color.hexToInt("#ff9900") );
	public inline function error(str:Dynamic)	add("error", str, Color.hexToInt("#ff0000") );
	public inline function fileOp(str:Dynamic)	add("file", str, Color.hexToInt("#c3b2ff"));
	public inline function render(str:Dynamic)	add("render", str, Color.hexToInt("#a7db4f"));
	public inline function debug(str:Dynamic)	add("debug", str, Color.hexToInt("#ff00ff"));
	public inline function network(str:Dynamic)	add("network", str, Color.hexToInt("#00e1b9"));

	inline function formatDate(stamp:Float) {
		return DateTools.format( Date.fromTime(stamp), "%Y-%m-%d %H:%M:%S" );
	}

	/**
		Dynamic methiod than can be replaced by your custom LogEntry printer.
	**/
	public dynamic function printEntry(l:LogEntry) {
		var str = getPrintableEntry(l);

		#if heaps
			// Console output override
			if( outputConsole!=null ) {
				outputConsole.log(str, l.color);
				return;
			}
		#end

		#if js

			var bgColor = Color.autoContrast( l.color, Color.toBlack(l.color,0.7), Color.toWhite(l.color,0.7) );
			js.html.Console.log(
				"%c"+str,
				'color: ${dn.Color.intToHex(l.color)}; background: ${dn.Color.intToHex(bgColor)}; padding: 2px; border-radius: 3px');

		#elseif sys

			Sys.println(str);

		#else

			trace(str);

		#end
	}

	/**
		Output all log entries to the default output.
	**/
	public function printAll() {
		for(l in log)
			printEntry(l);
	}
}