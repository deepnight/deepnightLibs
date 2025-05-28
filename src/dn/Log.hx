package dn;

typedef LogEntry = {
	var time: Float;
	var tag: String;
	var str: String;
	var color: Col;
	var flushed: Bool;
	var critical: Bool;
}

class Log {
	var maxEntries : Int;

	/** Array of log entries, SHOULD NOT BE EDITED MANUALLY **/
	public var entries : Array<LogEntry> = [];

	/**
		Will be used as default path when calling flushToFile()
	**/
	public var logFilePath : Null<String>;

	/**
		If TRUE, every add() call will also call printEntry()
	**/
	public var printOnAdd = false;

	/**
		NOT RECOMMENDED. If TRUE, every add() call will also call flushToFile(). WARNING: this setting might increase disk usage a lot!
	**/
	public var flushOnAdd = false;

	/**
		If TRUE, the date will also be visible in printEntry()
	**/
	public var printDate = false;

	var currentIndent = 0;

	/** Character to add before indented entries, in addition of spaces **/
	public var indentBullet : Null<String> = "-";

	#if heaps
	/**
		Optional output Console used by printEntry()
	**/
	public var outputConsole : Null<h2d.Console>;
	#end

	public function new(maxEntries=500) {
		entries = [];
		this.maxEntries = maxEntries;
	}


	/**
		Clear log content
	**/
	public function clear() {
		entries = [];
	}


	/**
		Return TRUE if log is empty
	**/
	public inline function isEmpty() {
		return entries.length==0;
	}

	public function containsAnyCriticalEntry() {
		for(e in entries)
			if( e.critical )
				return true;
		return false;
	}

	public function countCriticalEntries() {
		var n = 0;
		for(e in entries)
			if( e.critical )
				n++;
		return n;
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
				for(l in entries)
					if( !l.flushed ) {
						fo.writeString( getPrintableEntry(l,true)+"\n" );
						l.flushed = true;
					}

			#elseif hxnodejs

				var flushedLogs = entries.filter( function(l) {
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


	/**
		Remove all lines above `maxLines` in existing log file.

		@param maxLines If omited, `maxEntries` will be used
		@param filePath If omited, `logFilePath` will be used
	**/
	public function trimFileLines(?maxLines:Int, ?filePath:String) {
		if( maxLines==null )
			maxLines = maxEntries;

		if( filePath==null && logFilePath==null )
			return false;

		filePath = filePath==null ? logFilePath : filePath;

		try {
			var raw : String = null;

			#if sys
				raw = sys.io.File.getContent(filePath);
			#elseif hxnodejs
				js.node.Require.require("fs");
				raw = js.node.Fs.readFileSync(filePath).toString();
			#else
				// Unsupported on this platform
			#end

			if( raw==null )
				return false;

			var lines = raw.split("\n");
			if( lines.length>maxLines ) {
				lines = lines.splice(lines.length-maxLines, maxLines);
				var output = lines.join("\n");
				#if sys
					sys.io.File.saveContent( filePath, output );
				#elseif hxnodejs
					js.node.Require.require("fs");
					js.node.Fs.writeFileSync(filePath, output);
				#else
					// You're not supposed to be here
				#end
			}
			return true;
		}
		catch( e:Dynamic ) {}

		return false;
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


	/**
		Add an entry, "color" is not support for all outputs.

		`markAsCritical` is used to check if the whole log contains any "critical"
	**/

	public inline function add(tag:String, text:String, ?color:Col, markAsCritical=false) {
		if( currentIndent>0 )
			text = Lib.repeatChar("  ",currentIndent) + (indentBullet==null ? "" : indentBullet+" ") + text;

		entries.push({
			time: Date.now().getTime(),
			tag: tag,
			str: text,
			color: color==null ? getTagColor(tag) : color,
			flushed: false,
			critical: markAsCritical
		});
		onAdd( entries[entries.length-1] );

		if( entries.length>maxEntries )
			entries = entries.splice(-maxEntries, maxEntries);

		if( printOnAdd )
			printEntry( entries[entries.length-1] );

		if( flushOnAdd )
			flushToFile();
	}

	/** Add a `LogEntry` object **/
	public inline function addLogEntry(l:LogEntry) {
		add(l.tag, l.str, l.color, l.critical);
	}


	public var tagColors : Map<String,Col> = [
		"general" => "#c8c9e3",
		"warning" => "#ff9900",
		"error" => "#ff0000",
		"file" => "#897eff",
		"render" => "#54db8a",
		"debug" => "#ff00ff",
		"network" => "#9664ff",
		"userAction" => "#ffcc00",
	];

	public dynamic function def(str:String) {
		add("general", str);
	}

	public inline function getTagColor(tag:String) : Col {
		return tagColors.exists(tag) ? tagColors.get(tag) : 0xffffff;
	}

	public inline function emptyEntry()				add("","");
	public inline function general(str:Dynamic)		add( "general", Std.string(str) );
	public inline function warning(str:Dynamic)		add( "warning", Std.string(str) );
	public inline function error(str:Dynamic)		add( "error", Std.string(str) , true);
	public inline function fileOp(str:Dynamic)		add( "file", Std.string(str) );
	public inline function render(str:Dynamic)		add( "render", Std.string(str) );
	public inline function debug(str:Dynamic)		add("debug", Std.string(str));
	public inline function network(str:Dynamic)		add( "network", Std.string(str) );
	public inline function userAction(str:Dynamic)	add( "userAction", Std.string(str) );

	/** Increase indentation for all following entries **/
	public inline function indentMore() currentIndent++;

	/** Decrease indentation for all following entries **/
	public inline function indentLess() currentIndent = M.imax( currentIndent-1, 0 );

	/** Clear indentation level for all following entries **/
	public inline function clearIndent() currentIndent = 0;

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

			var bgColor = dn.legacy.Color.autoContrast( l.color, dn.legacy.Color.toBlack(l.color,0.7), dn.legacy.Color.toWhite(l.color,0.7) );
			js.html.Console.log(
				"%c"+str,
				'color: ${dn.legacy.Color.intToHex(l.color)}; background: ${dn.legacy.Color.intToHex(bgColor)}; padding: 2px; border-radius: 3px');

		#elseif sys

			Sys.println(str);

		#else

			haxe.Log.trace(str);

		#end
	}


	public function getLasts(maxCount:Int) {
		if( maxCount>=entries.length )
			return entries.map( e->getPrintableEntry(e) );
		else
			return entries.splice(entries.length-maxCount, maxCount).map( e->getPrintableEntry(e) );

	}

	/**
		Output all log entries to the default output.
	**/
	public function printAll() {
		for(l in entries)
			printEntry(l);
	}


	/**
		Print all entries into another log
	**/
	public function printAllToLog(target:Log) {
		for(e in entries)
			target.addLogEntry(e);
	}


	public dynamic function onAdd(e:LogEntry) {}


	#if deepnightLibsTests
	public static function test() {
		var l = new Log(5);
		l.logFilePath = "tests/bin/test.log";
		l.add("someTag", "text", 0xff00ff);
		l.flushToFile();
		l.trimFileLines();
	}
	#end
}