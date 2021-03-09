package dn.js;

// #if !node
// #error "HaxeLib \"electron\" is required";
// #end

class NodeTools {
	public static function fileExists(path:String) {
		if( path==null )
			return false;
		else {
			js.node.Require.require("fs");
			return js.node.Fs.existsSync(path);
		}
	}
}
