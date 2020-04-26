package dn;

class FilePath {
	/**
		Directory

		Can be null, no slash in the end.
	**/
	public var directory(default,null) : Null<String>;

	/**
		File name without extension. If it is manually set to a value containing dot(s), the extension value will be updated using the last part of
	**/
	public var fileName(default,set) : Null<String>;

	/**
		Extension without the preceding "dot". It can be set to another value, any leading dot will be discarded.
	**/
	public var extension(default,set) : Null<String>;

	/**
		Value is TRUE if the current path uses backslashes in directory.
	**/
	public var backslashes(default,null) : Bool;

	/**
		[READ-ONLY] returns the directory with a trailing slash/backslash (depends on the "backslash" value)
	**/
	public var directoryWithSlash(get,null) : Null<String>;

	/**
		Returns the file name with the extension. Can be set to update both values at the same time.
	**/
	public var fileWithExt(get,set) : Null<String>;

	/**
		[READ-ONLY] Returns current extension with a leading dot (or null if extension is null)
	**/
	public var extWithDot(get,never) : Null<String>;

	/**
		[READ-ONLY] Returns the full representation of the current path
	**/
	public var full(get,never) : String;


	public function new() {
		init();
	}

	function init() {
		backslashes = false;
		directory = null;
		fileName = null;
		extension = null;
	}

	public inline function clone() : FilePath {
		var p = new FilePath();
		p.backslashes = backslashes;
		p.directory = directory;
		p.fileName = fileName;
		p.extension = extension;
		return p;
	}

	function removeTrailingSlashes(path:String) {
		while( path.charAt(path.length-1)==slash() )
			path = path.substr(0,path.length-1);
		return path;
	}

	public inline function parseFilePath(filePath:String) {
		parse(filePath);
	}

	public inline function parseDirPath(dirPath:String) {
		parse(dirPath);
		if( fileWithExt!=null ) {
			directory += slash() + fileWithExt;
			fileName = null;
			extension = null;
		}
	}

	/**
		Initialize using a String representation of a path
	**/
	function parse(raw:String) {
		init();
		if( raw.indexOf("\\")>=0 ) {
			backslashes = true;
			raw = StringTools.replace(raw,"/","\\"); // avoid mixing slashes
		}

		if( raw.indexOf(slash())<0 ) {
			// No directory
			if( raw.indexOf(".")<0 )
				fileName = raw;
			else {
				fileName = raw.split(".")[0];
				extension = raw.split(".")[1];
			}
		}
		else {
			// Clean up double-slashes
			while( raw.indexOf( slash()+slash() ) >= 0 )
				raw = StringTools.replace(raw, slash()+slash(), slash() );

			// Directory
			directory = raw.substr( 0, raw.lastIndexOf(slash()) );

			if( raw.lastIndexOf(slash())<raw.length-1 ) {
				// File name & extension
				var rawFile = raw.substr( raw.lastIndexOf(slash())+1 );
				if( rawFile.indexOf(".")<0 )
					fileName = rawFile;
				else {
					fileName = rawFile.substr(0, rawFile.lastIndexOf("."));
					extension = rawFile.substr( rawFile.lastIndexOf(".")+1 );
				}
			}
		}
	}

	inline function slash() {
		return backslashes ? "\\" : "/";
	}

	function sanitize(v:String) {
		var r = ~/[~#%*{}\/:<>?|]/g;
		return r.replace(v, "_");
	}

	function set_extension(v:Null<String>) {
		if( v==null )
			return extension = null;
		else {
			while( v.charAt(0)=="." )
				v = v.substr(1);
			v = StringTools.replace(v, " ", "_");
			if( v.length==0 )
				return extension = null;
			return extension = sanitize(v);
		}
	}

	function set_fileName(v:Null<String>) {
		if( v==null )
			return fileName = null;
		v = sanitize(v);
		return fileName = v;
	}

	inline function get_fileWithExt() {
		return fileName==null && extension==null
			? null
			: (fileName==null ? "" : fileName) + (extension==null ? "" : "."+extension);
	}

	function set_fileWithExt(v:Null<String>) {
		if( v==null ) {
			fileName = null;
			extension = null;
		}
		v = sanitize(v);
		if( v.indexOf(".")<=0 ) {
			fileName = v;
			extension = null;
		}
		else {
			fileName = v.substr(0, v.lastIndexOf("."));
			extension = v.substr(v.lastIndexOf(".")+1);
		}
		return fileWithExt;
	}

	inline function get_extWithDot() {
		return ( extension==null ? null : "."+extension );
	}

	inline function get_full() {
		return
			( directory==null ? "" : ( fileName==null && extension==null ? directory : directoryWithSlash ) )
			+ (fileName==null ? "" : fileName)
			+ (extension==null ? "" : "."+extension);
	}

	inline function get_directoryWithSlash() {
		return directory==null ? null : directory + slash();
	}


	public function debug() {
		return 'dir=$directory, fileName=$fileName, ext=$extension';
	}



	/**
		Initialize using a String representation of a PATH (optional directory with a file name)
	**/
	public static inline function fromFile(raw:String) {
		var p = new FilePath();
		p.parseFilePath(raw);
		return p;
	}

	/**
		Initialize using a String representation of a DIRECTORY (no filename). The whole string
		will be considered as being a directory, even if it contains dots, like "/project/myApp.stable"
	**/
	public static inline function fromDir(raw:String) {
		var p = new FilePath();
		p.parseDirPath(raw);
		return p;
	}

	/**
		Extract the file name & extension from a path. Returns null if they don't exist.
	**/
	public static inline function extractFileWithExt(raw:String) : Null<String> {
		return FilePath.fromFile(raw).fileWithExt;
	}

	/**
		Extract the file name without extension from a path. Returns null if it doesn't exist.
	**/
	public static inline function extractFileName(raw:String) : Null<String> {
		return FilePath.fromFile(raw).fileName;
	}

	/**
		Extract the file extension from a path. Returns null if it doesn't exist.
	**/
	public static inline function extractExtension(raw:String) : Null<String> {
		return FilePath.fromFile(raw).extension;
	}

	/**
		Extract the directory without trailing slash.

		The "containsNoFileName" flag is to avoid ambiguities in cases like "/project/myFolder", where "myFolder"
		would be interpreted as a file name and not a directory.

		If containsNoFileName is TRUE, the whole path provided will be considered as being a directory.
	**/
	public static inline function extractDirNoSlash(filePath:String, containsNoFileName=false) : Null<String> {
		return containsNoFileName
			? FilePath.fromDir(filePath).directory
			: FilePath.fromFile(filePath).directory;
	}

	/**
		Extract the directory with a trailing slash (or backslash)

		The "containsNoFileName" flag is provided to avoid ambiguities in cases like "/project/myFolder",
		where "myFolder" would be interpreted as a file name and not a directory. Note that you can also
		avoid that by adding a trailing slash to the provided parameter (ie. "/project/myFolder/").

		If "containsNoFileName" is TRUE, the whole path provided will be considered as being a directory.
	**/
	public static inline function extractDirWithSlash(filePath:String, containsNoFileName=false) : Null<String> {
		return containsNoFileName
			? FilePath.fromDir(filePath).directoryWithSlash
			: FilePath.fromFile(filePath).directoryWithSlash;
	}


	// Deprecated static API
	@:noCompletion @:deprecated("Use FilePath.fromFile or FilePath.fromDir")
	public static inline function fullPath(v:String) return fromFile(v).full;

	@:noCompletion @:deprecated("Use FilePath.getFileWithExt")
	public static inline function fileAndExt(v:String) return extractFileWithExt(v);

	// Deprecated instance API
	@:noCompletion @:deprecated("Use <myVar>.fromFile or <myVar>.fromDir")
	public inline function fromString(v:String) return fromFile(v);

	@:noCompletion @:deprecated("Use <myVar>.full")
	public inline function getFull() return full;

	@:noCompletion @:deprecated("Use <myVar>.fileWithExt")
	public inline function getFileAndExt() return fileWithExt;

	// Deprecated fields
	@:noCompletion @:deprecated("Use <myVar>.directory")
	public var path(get,never) : String; inline function get_path() return directory;

	@:noCompletion @:deprecated("Use <myVar>.fileName")
	public var file(get,never) : String; inline function get_file() return fileName;

	@:noCompletion @:deprecated("Use <myVar>.extension")
	public var ext(get,set) : String;
	inline function get_ext() return extension;
	inline function set_ext(v) return extension = v;
}