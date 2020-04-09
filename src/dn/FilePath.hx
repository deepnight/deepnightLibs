package dn;

class FilePath {
	public var prefix(default,null) : String;
	public var path(default,null) : String;
	public var file(default,set) : String;
	public var ext(default,set) : String;

	public function new(?raw:String) {
		if( raw==null )
			init();
		else
			fromString(raw);
	}

	function sanitize(v:String) {
		var r = ~/[~#%*{}\/:<>?|]/g;
		return r.replace(v, "_");
	}

	function set_ext(v:String) {
		v = StringTools.replace(v, " ", "_");
		return ext = sanitize(v);
	}

	function set_file(v:String) {
		return file = sanitize(v);
	}

	function init() {
		path = file = ext = prefix = "";
	}

	public inline function clone() {
		return new FilePath(getFull());
	}

	public function fromString(raw:String) {
		init();
		raw = StringTools.trim( StringTools.replace(raw, "\\", "/") );

		if( raw.indexOf("/")<0 ) {
			if( raw.indexOf(".")<0 )
				file = raw;
			else {
				file = raw.split(".")[0];
				ext = raw.split(".")[1];
			}
		}
		else {
			// Prefix & path
			var prefixLen = raw.indexOf(":");
			if( prefixLen<0 ) {
				prefix = "";
				path = raw.substr( 0, raw.lastIndexOf("/")+1 );
			}
			else {
				prefix = raw.substr( 0, prefixLen );
				path = raw.substr( prefixLen+1, raw.lastIndexOf("/")+1 - prefixLen - 1 );
			}

			// Ensure trailing "/"
			while( path.length>0 && path.charAt(path.length-1)=="/" )
				path = path.substr(0, path.length-1);
			path = path.length==0 ? "" : path+"/";

			// File name & extension
			var rawFile = raw.substr( raw.lastIndexOf("/")+1 );
			if( rawFile.indexOf(".")<0 )
				file = rawFile;
			else {
				file = rawFile.substr(0, rawFile.lastIndexOf("."));
				ext = rawFile.substr( rawFile.lastIndexOf(".")+1 );
			}
		}
	}

	public function getFileAndExt() {
		return file + (ext=="" ? "" : "."+ext);
	}

	public function getFull() {
		return
			( prefix=="" ? "" : prefix+":" )
			+ path
			+ file
			+ (ext=="" ? "" : "."+ext);
	}



	public static inline function fileAndExt(raw:String) {
		return new FilePath(raw).getFileAndExt();
	}

	public static inline function fullPath(raw:String) {
		return new FilePath(raw).getFull();
	}

	public static inline function extension(raw:String) {
		return new FilePath(raw).ext;
	}

}