package dn.data;

enum MarkdownNode {
	Title(level:Int, text:String);
	Paragraph(text:String);
	Bullet(text:String);
}

/** A minimal (and basic) markdown parser **/
class MarkdownParser {
	var ltrimReg = ~/^[ \t\r]+/gi;
	var rtrimReg = ~/[ \t\r]+$/gi;

	var titleReg = ~/^(#+)\s+(.*)$/gi;
	var bulletReg = ~/^ -\s*(.+)$/gi;

	public function new() {}

	public function parse(raw:String) : Array<MarkdownNode> {
		var lines = raw.split("\n");
		var nodes = new Array<MarkdownNode>();

		for( line in lines ) {
			if( titleReg.match(line) ) {
				var level = titleReg.matched(1).length-1;
				var text = titleReg.matched(2);
				nodes.push( Title(level,trim(text)) );
			}
			else if( bulletReg.match(line) ) {
				var text = bulletReg.matched(1);
				nodes.push( Bullet(trim(text)) );
			}
			else if( trim(line).length>0 )
				nodes.push( Paragraph(trim(line)) );
		}

		return nodes;
	}

	function trim(str:String) {
		return rtrim( ltrim(str) );
	}

	inline function ltrim(str:String) {
		return ltrimReg.replace(str, "");
	}

	inline function rtrim(str:String) {
		return rtrimReg.replace(str, "");
	}
}