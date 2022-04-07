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
	static var WIN_NETWORK_DRIVE_REG = ~/^\\\\([a-z0-9-]+)\\(.*)/i;

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
		Directory with drive letter

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

	/** TRUE if current path is a Windows Network Drive (eg. "\\host\dir\file.txt") **/
	public var isWindowsNetworkDrive(default,null) = false;

	/** TRUE means Windows Network path was previously converted to URI format **/
	var _useWinNetDriveUriFormat = false;


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
			if( directory==null )
				directory = fp.directory;
			else
				directory += slash() + fp.directory;
		return this;
	}

	public function setDirectory(dir:Null<String>) {
		directory = dir;
		return this;
	}

	public inline function parseDirPath(dirPath:String) {
		parse(dirPath, false);
		return this;
	}

	/**
		Convert path to use slashes (/) instead of backslashes. NOTE: this won't work if the path is a Windows Network Drive (eg. "\\host\dir\file.txt").
	**/
	public function useSlashes() {
		if( isWindowsNetworkDrive && !_useWinNetDriveUriFormat )
			return this;
		else {
			if( directory!=null )
				directory = StringTools.replace(directory, "\\", "/");
			backslashes = false;
			return this;
		}
	}


	/**
		Convert path to use backslashes instead of slashes.
	**/
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
		Convert the current network drive path to a valid file URI format (eg. "\\host\dir\file.txt" => "file://host/dir/file.txt"). This only works if current path is a Windows Network Drive path.
	**/
	public function convertWindowsNetworkDriveToUri() {
		if( !_useWinNetDriveUriFormat && isWindowsNetworkDrive ) {
			_useWinNetDriveUriFormat = true;
			removeFirstDirectory();
			removeFirstDirectory();
			useSlashes();
		}
		return this;
	}


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


	public function isAbsolute() {
		return uriScheme!=null || directory!=null && getDirectoryArray()[0]=="" || hasDriveLetter();
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
		else if( raw.indexOf(".")==0 && raw.lastIndexOf(".")==0 ) {
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

			// Windows network adress (eg. "\\host\dir\file.txt" is turned into "file://")
			isWindowsNetworkDrive = false;
			if( WIN_NETWORK_DRIVE_REG.match(rawPath) ) {
				isWindowsNetworkDrive = true;
				uriScheme = "file";
				uriAuthority = WIN_NETWORK_DRIVE_REG.matched(1);
			}

			// Clean up double-slashes
			while( rawPath.indexOf( slash()+slash() ) >= 0 )
				rawPath = StringTools.replace(rawPath, slash()+slash(), slash() );

			// Remove trailing slash
			if( !containsFileName && rawPath.length>1 && rawPath.charAt(rawPath.length-1)==slash() )
				rawPath = rawPath.substr(0,rawPath.length-1);

			// Directory
			if( rawPath.indexOf(slash())<0 ) {
				directory = containsFileName ? null : rawPath;
			}
			else {
				directory = containsFileName ? rawPath.substr( 0, rawPath.lastIndexOf(slash()) ) : rawPath;
				if( directory.length==0 && containsFileName && rawPath.charAt(0)==slash() )
					directory = "/"; // dir is only a single leading slash (eg. "/file.txt")
				else if( directory.length==0 )
					directory = null;
			}

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

			// Remove useless "."
			var dirs = getDirectoryArray();
			if( dirs.length>1 ) {
				var i = 1; // keep first "."
				while( i<dirs.length ) {
					if( dirs[i]=="." )
						dirs.splice(i, 1);
					else
						i++;
				}
				if( dirs.length==0 )
					directory = null;
				else
					directory = dirs.join( slash() );
			}

			// Sanitize dirs
			if( directory!=slash() && directory!=null ) {
				var ignore = 0;
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


	/**
		Remove illegal characters (such as slashes/backslashes or *) from given file name. A file name should NOT include a path.
		Example: my image file01.png
	**/
	public static function cleanUpFileName(fileName:String, replaceWith="_") {
		if( fileName==null )
			return "";
		else
			return ~/[*{}\/\\<>?|:]/g.replace( fileName, replaceWith );
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
			( isWindowsNetworkDrive && !_useWinNetDriveUriFormat
				? slash() // re-add second leading slash
				: ( uriScheme!=null
					? uriAuthority==null ? '$uriScheme:/' : '$uriScheme://$uriAuthority/'
					: ""
				)
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


	/** Return directory fragments as array (c:/some/foo/file.txt returns [c:,some,foo])**/
	public function getDirectoryArray() : Array<String> {
		if( directory==null )
			return [];
		else if( directory==slash() )
			return [ slash() ];
		else
			return directory.split(slash());
	}


	/**
		Return full "sub" directories as array.
		- with `discardDriveLetter`==FALSE: "`c:/some/foo/file.txt`" returns [ c:, c:/some, c:/some/foo ]
		- with `discardDriveLetter`==TRUE: "`c:/some/foo/file.txt`" returns [ c:/some, c:/some/foo ]

	**/
	public function getSubDirectories(discardDriveLetter:Bool) : Array<String> {
		var parts = getDirectoryArray();
		if( parts.length==0 )
			return [];

		var subs = [];
		for(i in 0...parts.length) {
			if( discardDriveLetter && i==0 && hasDriveLetter() ) // discard drive letter
				continue;

			var sub = [];
			for(j in 0...i+1)
				sub.push( parts[j] );

			var p = sub.join( slash() );
			if( p=="" )
				p = slash();
			subs.push(p);
		}
		return subs;
	}


	/** Return directory fragments as array (c:/some/foo/file.txt returns [c:,some,foo,file.txt])**/
	public function getDirectoryAndFileArray() {
		var out = getDirectoryArray();
		if( fileWithExt!=null )
			out.push(fileWithExt);
		return out;
	}

	/** Return last directory name, if any **/
	public function getLastDirectory() : Null<String> {
		if( directory==null )
			return null;
		var arr = getDirectoryArray();
		return arr[arr.length-1];
	}

	/** Remove last directory, if any **/
	public function removeLastDirectory() {
		if( directory==null )
			return this;
		var arr = getDirectoryArray();
		arr.pop();
		if( arr.length==0 )
			directory = null;
		else
			directory = arr.join( slash() );

		return this;
	}

	/** Return first directory name, if any **/
	public function getFirstDirectory() : Null<String> {
		if( directory==null )
			return null;

		var arr = getDirectoryArray();
		if( hasDriveLetter() )
			return arr[1];
		else
			return arr[0];
	}

	/** Remove first directory, if any **/
	public function removeFirstDirectory() {
		if( directory==null )
			return this;

		var arr = getDirectoryArray();

		if( hasDriveLetter() )
			arr.splice(1,1);
		else
			arr.shift();

		if( arr.length==0 )
			directory = null;
		else
			directory = arr.join( slash() );
		return this;
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
		Cleanup a path by parsing it/returning it.
	**/
	public static inline function cleanUp(path:String, isFile:Bool) {
		var p = isFile ? fromFile(path) : fromDir(path);
		return p.full;
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
	public static inline function extractExtension(path:String, lowercase=false) : Null<String> {
		var e = FilePath.fromFile(path).extension;
		if( lowercase && e!=null )
			return e.toLowerCase();
		else
			return e;
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
		CiAssert.equals( FilePath.fromDir("/user/foo").directory, "/user/foo" );
		CiAssert.equals( FilePath.fromDir("/user/foo.png").directory, "/user/foo.png" );
		CiAssert.equals( FilePath.fromDir("/").directory, "/" );
		CiAssert.equals( FilePath.fromDir("/").directoryWithSlash, "/" );
		CiAssert.equals( FilePath.fromDir("").directory, null );
		CiAssert.equals( FilePath.fromDir("").directoryWithSlash, null );
		CiAssert.equals( FilePath.fromDir("/user").directoryWithSlash, "/user/" );
		CiAssert.equals( FilePath.fromDir("").fileName, null );
		CiAssert.equals( FilePath.fromDir("").extension, null );
		CiAssert.isTrue( FilePath.fromDir("").isEmpty() );
		CiAssert.isTrue( FilePath.fromDir(null).isEmpty() );
		CiAssert.isTrue( FilePath.fromFile(null).isEmpty() );
		CiAssert.equals( FilePath.fromDir("user/?/test").directory, "user/_/test");
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

		// Append/set dirs
		CiAssert.equals( FilePath.fromFile("test.txt").appendDirectory("foo").directory, "foo" );
		CiAssert.equals( FilePath.fromFile("bar/test.txt").appendDirectory("foo").directory, "bar/foo" );
		CiAssert.equals( FilePath.fromFile("test.txt").setDirectory("foo").directory, "foo" );
		CiAssert.equals( FilePath.fromFile("bar/test.txt").setDirectory("foo").directory, "foo" );

		// Dir array
		CiAssert.equals( FilePath.fromDir("c:").getDirectoryArray().length, 1 );
		CiAssert.equals( FilePath.fromDir("/user").getDirectoryArray().length, 2 );

		CiAssert.equals( FilePath.fromDir("c:/foo/bar").getSubDirectories(true).length, 2 );
		CiAssert.equals( FilePath.fromDir("c:/foo/bar").getSubDirectories(false).length, 3 );
		CiAssert.equals( FilePath.fromDir("c:/foo/bar").getSubDirectories(false)[0], "c:" );
		CiAssert.equals( FilePath.fromDir("c:/foo/bar").getSubDirectories(true)[0], "c:/foo" );
		CiAssert.equals( FilePath.fromDir("c:/foo/bar").getSubDirectories(true)[1], "c:/foo/bar" );
		CiAssert.equals( FilePath.fromDir("/").getSubDirectories(false)[0], "/" );
		CiAssert.equals( FilePath.fromDir("/user").getSubDirectories(false)[0], "/" );
		CiAssert.equals( FilePath.fromDir("/user").getSubDirectories(false)[1], "/user" );

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
		CiAssert.equals( FilePath.fromFile("file.txt").directory, null );
		CiAssert.equals( FilePath.fromFile("/file.txt").directory, "/" );
		CiAssert.equals( FilePath.fromFile("./file.txt").directory, "." );


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

		// First/last dir
		CiAssert.equals( FilePath.fromFile("c:/windows/system/foo.txt").getFirstDirectory(), "windows" );
		CiAssert.equals( FilePath.fromFile("/windows/system/foo.txt").getFirstDirectory(), "" );
		CiAssert.equals( FilePath.fromFile("./windows/system/foo.txt").getFirstDirectory(), "." );
		CiAssert.equals( FilePath.fromFile("ftp://a@b.com:21/foo/bar/pouet.txt").getFirstDirectory(), "foo" );


		CiAssert.equals( FilePath.fromDir("c:/windows/system").getLastDirectory(), "system" );
		CiAssert.equals( FilePath.fromFile("c:/windows/system/foo.txt").getLastDirectory(), "system" );
		CiAssert.equals( FilePath.fromFile("c:/windows/system/./foo.txt").getLastDirectory(), "system" );
		CiAssert.equals( FilePath.fromFile("c:/windows/system/../foo.txt").getLastDirectory(), "windows" );

		CiAssert.equals( FilePath.fromFile("foo/bar/file.txt").removeFirstDirectory().full, "bar/file.txt" );
		CiAssert.equals( FilePath.fromFile("foo/bar/file.txt").removeLastDirectory().full, "foo/file.txt" );
		CiAssert.equals( FilePath.fromFile("c:/windows/system/foo.txt").removeFirstDirectory().full, "c:/system/foo.txt" );
		CiAssert.equals( FilePath.fromFile("ftp://a@b.com:21/foo/bar/pouet.txt").removeFirstDirectory().full, "ftp://a@b.com:21/bar/pouet.txt" );

		// Relative transformations
		CiAssert.equals( FilePath.fromDir("/dir/foo/bar").makeRelativeTo("/dir").full, "foo/bar" );
		CiAssert.equals( FilePath.fromDir("/dir/a").makeRelativeTo("/dir/b").full, "../a" );
		CiAssert.equals( FilePath.fromDir("/dir/a1/a2").makeRelativeTo("/dir/b").full, "../a1/a2" );
		CiAssert.equals( FilePath.fromDir("/dir/a1/a2").makeRelativeTo("/dir/b1/b2").full, "../../a1/a2" );
		CiAssert.equals( FilePath.fromDir("c:/dir").makeRelativeTo("d:/dir").full, "c:/dir" );
		CiAssert.equals( FilePath.fromDir("c:/").makeRelativeTo("d:/").full, "c:" );

		// Absolute paths
		CiAssert.isTrue( FilePath.fromDir("c:/windows/system").isAbsolute() );
		CiAssert.isTrue( FilePath.fromDir("file:///windows/system").isAbsolute() );
		CiAssert.isTrue( FilePath.fromDir("file://host/windows/system").isAbsolute() );
		CiAssert.isTrue( FilePath.fromDir("file:/windows/system").isAbsolute() );
		CiAssert.isTrue( FilePath.fromDir("/windows/system").isAbsolute() );
		CiAssert.isTrue( FilePath.fromFile("/windows/file.txt").isAbsolute() );
		CiAssert.isTrue( !FilePath.fromFile("windows/file.txt").isAbsolute() );
		CiAssert.isTrue( !FilePath.fromFile("./windows/file.txt").isAbsolute() );
		CiAssert.isTrue( !FilePath.fromFile("../windows/file.txt").isAbsolute() );
		CiAssert.isTrue( !FilePath.fromDir("windows").isAbsolute() );
		CiAssert.isTrue( !FilePath.fromFile("file.txt").isAbsolute() );


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
		CiAssert.equals( FilePath.fromFile("file:///pouet.txt").full, "file:/pouet.txt" );

		// Windows network drives
		CiAssert.equals( FilePath.fromFile("\\\\foo\\bar\\test.txt").isWindowsNetworkDrive, true );
		CiAssert.equals( FilePath.fromDir("\\\\host-abc5\\dir").isWindowsNetworkDrive, true );
		CiAssert.equals( FilePath.fromDir("\\\\host-abc5\\dir").convertWindowsNetworkDriveToUri().isWindowsNetworkDrive, true );

		CiAssert.equals( FilePath.fromFile("\\\\foo\\bar\\test.txt").full, "\\\\foo\\bar\\test.txt" );
		CiAssert.equals( FilePath.fromFile("\\\\foo\\bar\\test.txt").uriAuthority, "foo" );
		CiAssert.equals( FilePath.fromDir("\\\\host-abc5\\dir").full, "\\\\host-abc5\\dir" );

		CiAssert.equals( FilePath.fromFile("\\\\foo\\bar\\test.txt").convertWindowsNetworkDriveToUri().full, "file://foo/bar/test.txt" );
		CiAssert.equals( FilePath.fromFile("\\\\host-abc5\\dir\\test.txt").convertWindowsNetworkDriveToUri().full, "file://host-abc5/dir/test.txt" );
		CiAssert.equals( FilePath.fromFile("\\\\host-abc5\\dir\\test.txt").convertWindowsNetworkDriveToUri().uriAuthority, "host-abc5" );
		CiAssert.equals( FilePath.fromDir("\\\\host-abc5\\dir").convertWindowsNetworkDriveToUri().full, "file://host-abc5/dir" );


		// Cleanup
		CiAssert.equals( FilePath.cleanUp("/home//dir/./foo.txt",true), "/home/dir/foo.txt" );
		CiAssert.equals( FilePath.cleanUp("./home//\\dir/./foo.txt",true), "./home/dir/foo.txt" );
		CiAssert.equals( FilePath.cleanUp("//home/dir/foo.txt",true), "/home/dir/foo.txt" );
		CiAssert.equals( FilePath.cleanUp("file://home/dir/foo.txt",true), "file://home/dir/foo.txt" );
		CiAssert.equals( FilePath.cleanUp("https://domain.com/foo/bar//pouet.txt",true), "https://domain.com/foo/bar/pouet.txt" );

		CiAssert.equals( FilePath.cleanUpFileName("My file/name is*cool:.txt"), "My file_name is_cool_.txt" );
	}
}