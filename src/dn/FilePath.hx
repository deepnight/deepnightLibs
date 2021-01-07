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
		URI scheme part not including ":" nor slashes (eg. "file" in "file://localhost/c:/windows/foo.txt")

		Can be null, always lowercase
	**/
	public var uriScheme(default,null) : Null<String>;

	/**
		URI authority part if it exists (eg. "localhost" in "file://localhost/c:/windows/foo.txt")

		Can be null, always lowercase
	**/
	public var uriAuthority(default,null) : Null<String>;

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

	public inline function isEmpty() {
		return full.length==0;
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

	public function appendDirectory(extraDirs:String) {
		var fp = fromDir(extraDirs);
		if( fp.directory!=null )
			directory += slash() + fp.directory;
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

	/**
		Extract URI prefix from a directory (eg. file URI "file:///test.txt")
	**/
	// public function getUriPrefix(forceLowerCase=true) : Null<String> {
	// 	var prefixReg = ~/^([a-z]+):\/\//gi;
	// 	if( directory!=null && prefixReg.match(directory) )
	// 		return forceLowerCase ? prefixReg.matched(1).toLowerCase() : prefixReg.matched(1);
	// 	else
	// 		return null;
	// }

	/**
		Return TRUE if contains a Windows drive letter
	**/
	public inline function hasDriveLetter() {
		return getDriveLetter()!=null;
	}

	/**
		Extract the Windows OS drive letter from a path
	**/
	public function getDriveLetter(forceLowerCase=true) : Null<String> {
		var letterReg = uriScheme!=null
			? ~/([^a-z]|^)([a-z])[:$][\/\\]?/gi // support file:///c$/foo/bar.txt
			: ~/([^a-z]|^)([a-z]):[\/\\]?/gi;

		if( directory!=null && letterReg.match(directory) )
			return forceLowerCase ? letterReg.matched(2).toLowerCase() : letterReg.matched(2);
		else
			return null;
	}

	/**
		Return TRUE if the directory contains URI prefix (eg. "file" in "file:///foo/bar.txt")
	**/
	public inline function isUri() {
		return uriScheme!=null;
	}

	/**
		Return TRUE if the 2 provided paths share the same drive letter.

		The result is also TRUE if both don't have a letter.

		The result is FALSE if one of them has a letter while the other hasn't.
	**/
	public static function sameDriveLetter(pathA:String, pathB:String) {
		if( pathA==null || pathB==null )
			return true;
		else
			return FilePath.fromDir(pathA).getDriveLetter() == FilePath.fromDir(pathB).getDriveLetter();
	}


	public function makeRelativeTo(dirPath:String) {
		var cur = getDirectoryArray();
		var other = fromDir(dirPath);
		if( uriScheme != other.uriScheme || getDriveLetter() != other.getDriveLetter() )
			return this;

		var ref = other.getDirectoryArray();

		if( cur[0]!=ref[0] )
			return this;

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
		return this;
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

		if( rawPath==null || rawPath.length==0 )
			return;

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
			// URI prefixes
			var uriSchemeReg = ~/^([a-z]{2,}):[\/]{2}(.*?)\/|^([a-z]{2,}):[\/]{1}/gi;
			if( uriSchemeReg.match(rawPath) ) {
				if( uriSchemeReg.matched(3)!=null ) {
					// No Authority provided, eg. "file:/path/foo/bar.txt"
					uriScheme = uriSchemeReg.matched(3);
					uriAuthority = null;
				}
				else {
					// Authority is provided, eg. "file://localhost@domain.com/path/foo/bar.txt"
					uriScheme = uriSchemeReg.matched(1);
					uriAuthority = uriSchemeReg.matched(2);
					if( uriAuthority=="" )
						uriAuthority = null;
				}
				rawPath = uriSchemeReg.matchedRight();
			}

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
					if( dirs[i]==".." && i>0 && dirs[i-1]!=".." && dirs[i-1]!="" ) {
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
				var ignore = 0;
				// if( hasUriScheme() )
					// ignore++;
				if( hasDriveLetter() )
					ignore++;

				var dirs = getDirectoryArray();
				for(i in 0...dirs.length)
					dirs[i] = i<ignore ? sanitize(dirs[i],true) : sanitize(dirs[i]);
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
			? ~/[*{}\/\\<>?|]/g.replace( v, "_" )
			: ~/[*{}\/\\<>?|:]/g.replace( v, "_" );
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
			// URI
			( uriScheme!=null
				? uriAuthority==null ? '$uriScheme:/' : '$uriScheme://$uriAuthority/'
				: ""
			)
			+
			// Directory
			( directory==null
				? ""
				: fileName==null && extension==null || directory==slash() ? directory : directoryWithSlash
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

	public function removeLastDirectory() {
		if( directory==null )
			return;
		var arr = getDirectoryArray();
		arr.pop();
		directory = arr.join( slash() );
	}


	@:keep public function toString() {
		return full;
	}

	public function debug() {
		return 'dir=$directory, fileName=$fileName, ext=$extension, uri=$uriScheme+$uriAuthority, drive=${getDriveLetter()}';
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
		CiAssert.isTrue( FilePath.fromDir("").isEmpty() );
		CiAssert.isTrue( FilePath.fromDir(null).isEmpty() );
		CiAssert.isTrue( FilePath.fromFile(null).isEmpty() );
		CiAssert.isTrue( FilePath.fromDir("user/?/test").directory == "user/_/test");
		CiAssert.equals( FilePath.fromDir("/user/foo").full, "/user/foo" );
		CiAssert.equals( FilePath.fromDir("/user/foo/").full, "/user/foo" );
		CiAssert.equals( FilePath.fromDir("user//foo").full, "user/foo" );
		CiAssert.equals( FilePath.fromDir("..").full, ".." );
		CiAssert.equals( FilePath.fromDir("/..").full, "/.." ); // non sense but well..
		CiAssert.equals( FilePath.fromDir("a/../..").full, ".." );

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
		CiAssert.isTrue( FilePath.fromFile("/user/").fileName==null );
		CiAssert.isTrue( FilePath.fromFile("/user/").extension==null );
		CiAssert.isTrue( FilePath.fromFile("").directory == null );
		CiAssert.isTrue( FilePath.fromFile("").fileName == null );
		CiAssert.isTrue( FilePath.fromFile("").extension == null );
		CiAssert.isTrue( FilePath.fromFile("/user/foo.png").full=="/user/foo.png" );
		CiAssert.isTrue( FilePath.fromFile("/user/").full=="/user" );


		CiAssert.isTrue( FilePath.extractFileName("/user/test.png") == "test" );
		CiAssert.isTrue( FilePath.extractExtension("/user/test.png") == "png" );
		CiAssert.isTrue( FilePath.extractExtension("/user/test") == null );

		// Special characters
		CiAssert.equals( FilePath.fromFile("/some/Dir~#%/foo.txt").full, "/some/Dir~#%/foo.txt" );
		CiAssert.equals( FilePath.fromFile("/some/Dir:/foo.txt").full, "/some/Dir_/foo.txt" );
		CiAssert.equals( FilePath.fromFile("/some/Dir*?:/foo.txt").full, "/some/Dir___/foo.txt" );

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

		// Relative transformations
		CiAssert.equals( FilePath.fromDir("/dir/foo/bar").makeRelativeTo("/dir").full, "foo/bar" );
		CiAssert.equals( FilePath.fromDir("/dir/a").makeRelativeTo("/dir/b").full, "../a" );
		CiAssert.equals( FilePath.fromDir("/dir/a1/a2").makeRelativeTo("/dir/b").full, "../a1/a2" );
		CiAssert.equals( FilePath.fromDir("/dir/a1/a2").makeRelativeTo("/dir/b1/b2").full, "../../a1/a2" );
		CiAssert.equals( FilePath.fromDir("c:/dir").makeRelativeTo("d:/dir").full, "c:/dir" );
		CiAssert.equals( FilePath.fromDir("c:/").makeRelativeTo("d:/").full, "c:" );

		// Drive letters
		CiAssert.equals( FilePath.fromDir("c:/dir").getDriveLetter(), "c" );
		CiAssert.equals( FilePath.fromDir("c:/dir").directory, "c:/dir" );
		CiAssert.equals( FilePath.fromDir("c:/dir").directory, "c:/dir" );
		CiAssert.isFalse( FilePath.fromDir("/dir").hasDriveLetter() );
		CiAssert.equals( FilePath.fromFile("c:/file.png").getDriveLetter(), "c" );
		CiAssert.equals( FilePath.fromFile("file:///C:/foo/bar/pouet.txt").getDriveLetter(), "c" );
		CiAssert.equals( FilePath.fromFile("file://someone@domain.com:21/C:/foo/bar/pouet.txt").getDriveLetter(), "c" );
		CiAssert.equals( FilePath.fromFile("file://localhost/c$/foo/bar.txt").getDriveLetter(), "c" );
		CiAssert.equals( FilePath.fromFile("file:/c$/foo/bar.txt").getDriveLetter(), "c" );

		var filePath = "file://someone@domain.com:21/C:/foo/bar/pouet.txt";
		CiAssert.equals( FilePath.fromFile(filePath).full, filePath );

		// File URI test
		CiAssert.isTrue( FilePath.fromFile("file:///C:/foo/bar/pouet.txt").isUri() );
		CiAssert.isTrue( FilePath.fromFile("file:/C:/foo/bar/pouet.txt").isUri() );
		CiAssert.isFalse( FilePath.fromFile("C:/foo/bar/pouet.txt").isUri() );
		CiAssert.isFalse( FilePath.fromFile("C://foo///bar/pouet.txt").isUri() );
		CiAssert.equals( FilePath.fromFile("file:/C:/foo/bar/pouet.txt").uriScheme, "file" );
		CiAssert.equals( FilePath.fromFile("file:///C:/foo/bar/pouet.txt").fileName, "pouet" );
		CiAssert.equals( FilePath.fromFile("file:///C:/foo/bar/pouet.txt").extension, "txt" );
		CiAssert.equals( FilePath.fromFile("file:///C:/foo/bar/pouet.txt").getDriveLetter(), "c" );
		CiAssert.equals( FilePath.fromFile("file:///foo/bar/pouet.txt").getDriveLetter(), null );
		CiAssert.equals( FilePath.fromFile("file:///C:/foo/bar/pouet.txt").uriScheme, "file" );

		CiAssert.equals( FilePath.fromFile("file:///C:/foo/bar/pouet.txt").uriAuthority, null );
		CiAssert.equals( FilePath.fromFile("file://localhost/C:/foo/bar/pouet.txt").uriAuthority, "localhost" );
		CiAssert.equals( FilePath.fromFile("file://a@b.com:21/C:/foo/bar/pouet.txt").uriAuthority, "a@b.com:21" );
		CiAssert.equals( FilePath.fromFile("ftp://a@b.com:21/foo/bar//pouet.txt").uriScheme, "ftp" );
		CiAssert.equals( FilePath.fromFile("ftp://a@b.com:21/foo/bar//pouet.txt").uriAuthority, "a@b.com:21" );
		CiAssert.equals( FilePath.fromFile("https://domain.com/foo/bar//pouet.txt").uriScheme, "https" );
		CiAssert.equals( FilePath.fromFile("https://domain.com/foo/bar//pouet.txt").uriAuthority, "domain.com" );

		CiAssert.equals( FilePath.fromFile("file://localhost/foo//pouet.txt").full, "file://localhost/foo/pouet.txt" );
		CiAssert.equals( FilePath.fromFile("file:/foo//pouet.txt").full, "file:/foo/pouet.txt" );
	}
}