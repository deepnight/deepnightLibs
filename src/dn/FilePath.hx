package dn;

enum PathSlashMode {
	/**
		Preserve existing slashes/backslashes.
	**/
	Preserve;

	/**
		Convert all paths to backslashes
	**/
	OnlyBackslashes;

	/**
		Convert all paths to slashes
	**/
	OnlySlashes;
}

class FilePath {
	/**
		Change the way FilePath parser deals with slashes/backslashes.

		[Preserve] (default) - Don't change the existing slashes and maintain them

		[OnlySlashes] or [OnlyBackslashes] - Convert to the corresponding type
	**/
	public static var SLASH_MODE = Preserve;

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
		parse(filePath, true);
		return this;
	}

	public inline function parseDirPath(dirPath:String) {
		parse(dirPath, false);
		return this;
	}

	public function useSlashes() {
		if( directory!=null )
			directory = StringTools.replace(directory, "\\", "/");
		backslashes = false;
		return this;
	}

	public function useBackslashes() {
		if( directory!=null )
			directory = StringTools.replace(directory, "/", "\\");
		backslashes = true;
		return this;
	}

	public static inline function convertToSlashes(path:String) {
		return StringTools.replace(path, "\\", "/");
	}

	public static inline function convertToBackslashes(path:String) {
		return StringTools.replace(path, "/", "\\");
	}


	public function makeRelativeTo(dirPath:String) {
		var cur = getDirectoryArray();
		var ref = fromDir(dirPath).getDirectoryArray();

		if( cur[0]!=ref[0] )
			return;

		// Drop common elements
		while( cur.length>0 && ref.length>0 && cur[0]==ref[0] ) {
			cur.shift();
			ref.shift();
		}

		var i = 0;
		while( i<ref.length ) {
			cur.insert(0, "..");
			i++;
		}

		directory = cur.length==0 ? null : cur.join( slash() );
	}


	function parseFileName(raw:String) {
		// if( raw==".." ) { // TODO why?
		// 	fileName = extension = null;
		// 	if( directory==null )
		// 		directory = raw;
		// 	else
		// 		directory = directoryWithSlash + raw;
		// }
		if( raw.indexOf(".")<0 ) {
			// No extension
			fileName = raw;
			extension = null;
		}
		else if( raw.indexOf(".")==0 && raw.lastIndexOf(".")==raw.indexOf(".") ) {
			// No file name
			fileName = null;
			extension = raw.substr(1);
		}
		else {
			// Normal filename
			fileName = raw.substr(0, raw.lastIndexOf("."));
			extension = raw.substr(raw.lastIndexOf(".")+1);
		}
	}

	/**
		Initialize using a String representation of a path

		If "containsFileName" is FALSE, the provided path is considered to be a pure directory path (eg. "/user/files")
	**/
	function parse(rawPath:String, containsFileName:Bool) {
		init();

		switch SLASH_MODE {
			case Preserve:
			case OnlyBackslashes: rawPath = StringTools.replace(rawPath, "/", "\\");
			case OnlySlashes: rawPath = StringTools.replace(rawPath, "\\", "/");
		}

		// Detect slashes
		if( rawPath.indexOf("\\")>=0 )
			if( rawPath.indexOf("/")>=0 )
				backslashes = rawPath.indexOf("\\") < rawPath.indexOf("/"); // if mixed, the first one sets the mode
			else
				backslashes = true;

		// Avoid mixing slashes
		rawPath = StringTools.replace(rawPath, backslashes ? "/" : "\\", slash());

		if( containsFileName && rawPath.indexOf(slash()) < 0 ) {
			// No directory
			parseFileName(rawPath);
		}
		else {
			// Clean up double-slashes
			while( rawPath.indexOf( slash()+slash() ) >= 0 )
				rawPath = StringTools.replace(rawPath, slash()+slash(), slash() );

			// Remove trailing slash
			if( !containsFileName && rawPath.length>1 && rawPath.charAt(rawPath.length-1)==slash() )
				rawPath = rawPath.substr(0,rawPath.length-1);

			// Directory
			directory = containsFileName ? rawPath.substr( 0, rawPath.lastIndexOf(slash()) ) : rawPath;
			if( directory.length==0 )
				directory = null;

			// File name & extension
			if( containsFileName && rawPath.lastIndexOf(slash()) < rawPath.length-1 ) {
				var rawFile = rawPath.substr( rawPath.lastIndexOf(slash())+1 );
				parseFileName(rawFile);
			}

			// Simplify ".."
			var dirs = getDirectoryArray();
			if( dirs.length>0 ) {
				var i = 0;
				while( i<dirs.length ) {
					if( dirs[i]==".." && i>0 && dirs[i-1]!=".." ) {
						dirs.splice(i-1, 2);
						i--;
					}
					else
						i++;
				}
				if( dirs.length==0 )
					directory = null;
				else if( dirs.length==1 && dirs[0]=="" )
					directory = slash();
				else
					directory = dirs.join( slash() );
			}

			// Sanitize dirs
			if( directory!=slash() && directory!=null ) {
				var dirs = getDirectoryArray();
				for(i in 0...dirs.length)
					dirs[i] = i==0 ? sanitize(dirs[i],true) : sanitize(dirs[i]);
				directory = dirs.join( slash() );
			}
		}
	}

	/** Return default "slash" character as used in this path **/
	public inline function slash() {
		return backslashes ? "\\" : "/";
	}

	function sanitize(v:String, ignoreDoubleDots=false) {
		return ignoreDoubleDots
			? ~/[~#%*{}\/<>?|]/g.replace( v, "_" )
			: ~/[~#%*{}\/:<>?|]/g.replace( v, "_" );
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
		else {
			v = sanitize(v);
			parseFileName(v);
		}
		return fileWithExt;
	}

	inline function get_extWithDot() {
		return ( extension==null ? null : "."+extension );
	}

	inline function get_full() {
		return
			// Directory
			( directory==null
				? ""
				: directory
			)
			+
			// File name
			( fileWithExt==null ? "" : fileWithExt );
	}

	inline function get_directoryWithSlash() {
		return
			directory==null
			? null
			: directory==slash()
				? directory
				: directory + slash();
	}


	public function getDirectoryArray() {
		if( directory==null )
			return [];
		else if( directory==slash() )
			return [ slash() ];
		else
			return directory.split(slash());
	}

	public function getDirectoryAndFileArray() {
		var out = getDirectoryArray();
		if( fileWithExt!=null )
			out.push(fileWithExt);
		return out;
	}

	public function getLastDirectory() : Null<String> {
		if( directory==null )
			return null;
		var arr = getDirectoryArray();
		return arr[arr.length-1];
	}


	@:keep public function toString() {
		return full;
	}

	public function debug() {
		return 'dir=$directory, fileName=$fileName, ext=$extension';
	}



	/**
		Initialize using a FILE PATH string (ie. "optional directory ending with a file name")
	**/
	public static inline function fromFile(path:String) {
		var p = new FilePath();
		p.parseFilePath(path);
		return p;
	}

	/**
		Initialize using a DIRECTORY string (no filename). The whole string
		will be considered as being a directory, even if it contains dots, like "/project/myApp.stable"
	**/
	public static inline function fromDir(path:String) {
		var p = new FilePath();
		p.parseDirPath(path);
		return p;
	}

	/**
		Extract the file name & extension from a path. Returns null if they don't exist.
	**/
	public static inline function extractFileWithExt(path:String) : Null<String> {
		return FilePath.fromFile(path).fileWithExt;
	}

	/**
		Extract the file name without extension from a path. Returns null if it doesn't exist.
	**/
	public static inline function extractFileName(path:String) : Null<String> {
		return FilePath.fromFile(path).fileName;
	}

	/**
		Extract the file extension from a path. Returns null if it doesn't exist.
	**/
	public static inline function extractExtension(path:String) : Null<String> {
		return FilePath.fromFile(path).extension;
	}


	/**
		Extract the directory without trailing slash.

		The "containsFileName" flag is to avoid ambiguities in cases like "/project/myFolder", where "myFolder"
		would be interpreted as a file name and not a directory.

		If "containsFileName" is FALSE, the whole path provided will be considered as being a directory.
	**/
	public static inline function extractDirectoryWithoutSlash(path:String, containsFileName:Bool) : Null<String> {
		return containsFileName
			? FilePath.fromFile(path).directory
			: FilePath.fromDir(path).directory;
	}


	/**
		Extract the directory with a trailing slash (or backslash)

		The "containsFileName" flag is to avoid ambiguities in cases like "/project/myFolder", where "myFolder"
		would be interpreted as a file name and not a directory.

		If "containsFileName" is FALSE, the whole path provided will be considered as being a directory.
	**/
	public static inline function extractDirectoryWithSlash(path:String, containsFileName:Bool) : Null<String> {
		return containsFileName
			? FilePath.fromFile(path).directoryWithSlash
			: FilePath.fromDir(path).directoryWithSlash;
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


	@:noCompletion
	public static function __test() {
		// General
		CiAssert.isNotNull( new FilePath() );
		CiAssert.isTrue( FilePath.fromFile("/user/.htaccess").clone().full == FilePath.fromFile("/user/.htaccess").clone().full );

		// Dirs
		CiAssert.isTrue( FilePath.fromDir("/user/foo").directory=="/user/foo" );
		CiAssert.isTrue( FilePath.fromDir("/user/foo.png").directory=="/user/foo.png" );
		CiAssert.isTrue( FilePath.fromDir("/").directory=="/" );
		CiAssert.isTrue( FilePath.fromDir("c:").getDirectoryArray().length==1 );
		CiAssert.isTrue( FilePath.fromDir("/user").getDirectoryArray().length==2 );
		CiAssert.isTrue( FilePath.fromDir("/user").directoryWithSlash == "/user/" );
		CiAssert.isTrue( FilePath.fromDir("/").directoryWithSlash == "/" );
		CiAssert.isTrue( FilePath.fromDir("").directory == null );
		CiAssert.isTrue( FilePath.fromDir("").directoryWithSlash == null );
		CiAssert.isTrue( FilePath.fromDir("").fileName == null );
		CiAssert.isTrue( FilePath.fromDir("").extension == null );
		CiAssert.isTrue( FilePath.fromDir("user/?/test").directory == "user/_/test");

		CiAssert.isTrue( FilePath.extractDirectoryWithoutSlash("", false) == null );
		CiAssert.isTrue( FilePath.extractDirectoryWithoutSlash("/", false) == "/" );
		CiAssert.isTrue( FilePath.extractDirectoryWithoutSlash("user/test.png", true) == "user" );
		CiAssert.isTrue( FilePath.extractDirectoryWithoutSlash("test.png", true) == null );
		CiAssert.isTrue( FilePath.extractDirectoryWithSlash("", false) == null );
		CiAssert.isTrue( FilePath.extractDirectoryWithSlash("..", false) == "../" );
		CiAssert.isTrue( FilePath.extractDirectoryWithSlash("user", false) == "user/" );

		// Files
		CiAssert.isTrue( FilePath.fromFile("/user/foo").directory=="/user" );
		CiAssert.isTrue( FilePath.fromFile("/user/foo.png").directory=="/user" );
		CiAssert.isTrue( FilePath.fromFile("/user/foo.png").fileName=="foo" );
		CiAssert.isTrue( FilePath.fromFile("/user/foo.png").extension=="png" );
		CiAssert.isTrue( FilePath.fromFile("/user/foo.png").fileWithExt=="foo.png" );
		CiAssert.isTrue( FilePath.fromFile("/user/foo.png").extWithDot==".png" );
		CiAssert.isTrue( FilePath.fromFile("/user/foo").extWithDot==null );
		CiAssert.isTrue( FilePath.fromFile(".htaccess").fileName==null );
		CiAssert.isTrue( FilePath.fromFile(".htaccess").extension=="htaccess" );
		CiAssert.isTrue( FilePath.fromFile("/user/test.foo.png").extension=="png" );
		CiAssert.isTrue( FilePath.fromFile("/user/.foo.png").fileName==".foo" );
		CiAssert.isTrue( FilePath.fromFile("/user/.foo.png").extension=="png" );
		CiAssert.isTrue( FilePath.fromFile("/user/.foo.png").fileWithExt==".foo.png" );
		CiAssert.isTrue( FilePath.fromFile("/user/.foo.").extension==null );
		CiAssert.isTrue( FilePath.fromFile("/user/.foo.").fileName==".foo" );
		CiAssert.isTrue( FilePath.fromFile("").directory == null );
		CiAssert.isTrue( FilePath.fromFile("").fileName == "" );
		CiAssert.isTrue( FilePath.fromFile("").extension == null );

		CiAssert.isTrue( FilePath.extractFileName("/user/test.png") == "test" );
		CiAssert.isTrue( FilePath.extractExtension("/user/test.png") == "png" );
		CiAssert.isTrue( FilePath.extractExtension("/user/test") == null );

		// Simplification
		CiAssert.isTrue( FilePath.fromDir("foo/bar/../../test").directory=="test" );
		CiAssert.isTrue( FilePath.fromDir("../test").directory=="../test" );
		CiAssert.isTrue( FilePath.fromDir("test/..").directory==null );
		CiAssert.isTrue( FilePath.fromDir("foo/test/../..").directory==null );
		CiAssert.isTrue( FilePath.fromDir("foo/test/../../").directory==null );
		CiAssert.isTrue( FilePath.fromDir("/foo/test/../../").directory=="/" );
		CiAssert.isTrue( FilePath.fromDir("/foo/test/../../").full=="/" );
		CiAssert.isTrue( FilePath.fromFile("/foo/test/../../test.png").directory=="/" );
		CiAssert.isTrue( FilePath.fromFile("/foo/test/../../test.png").full=="/test.png" );
		CiAssert.isTrue( FilePath.fromFile("/foo/test/../../test.png").getDirectoryArray()[0] == "/" );
		CiAssert.isTrue( FilePath.fromFile("foo/test/../../test.png").getDirectoryArray()[0] == null );
		CiAssert.isTrue( FilePath.fromDir("/").getDirectoryArray()[0] == "/" );

		// Slash/backslash
		FilePath.SLASH_MODE = OnlySlashes;
		CiAssert.isTrue( FilePath.fromDir("\\").directory == "/" );
		CiAssert.isTrue( FilePath.fromDir("c:\\windows\\system\\").directory == "c:/windows/system" );
		CiAssert.isTrue( FilePath.fromDir("c:\\windows/system\\/").directory == "c:/windows/system" );
		CiAssert.isTrue( FilePath.fromDir("c:\\windows/system\\/").getDirectoryArray().length==3 );
		FilePath.SLASH_MODE = OnlyBackslashes;
		CiAssert.isTrue( FilePath.fromDir("c:\\windows/system\\/").full == "c:\\windows\\system" );
		CiAssert.isTrue( FilePath.fromDir("c:/windows/system").full == "c:\\windows\\system" );
		FilePath.SLASH_MODE = Preserve;
		CiAssert.isTrue( FilePath.fromDir("c:\\windows/system\\/").full == "c:\\windows\\system" );
		CiAssert.isTrue( FilePath.fromDir("c:/windows/system").full == "c:/windows/system" );
	}
}