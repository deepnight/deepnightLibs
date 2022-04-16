package dn.js;

import js.node.Fs;

/**
	Many useful methods from NodeJS.

	RECOMMENDED: add `import NodeTools as NT;` to your `import.hx` file.
**/
class NodeTools {
	public static inline function isWindows() return js.node.Os.platform()=="win32";
	public static inline function isMacOs() return js.node.Os.platform()=="darwin";
	public static inline function isLinux() return js.node.Os.platform()=="linux";

	/** Return TRUE if given path exists **/
	public static function fileExists(path:String) {
		return path==null || path.length==0 ? false : js.node.Fs.existsSync(path);
	}

	/** Return TRUE if given path is a directory **/
	public static function isDirectory(path:String) {
		return
			try ( fileExists(path) && Fs.statSync(path).isDirectory() )
			catch(_) false;
	}

	/** Rename a file and return TRUE if it worked. **/
	public static function renameFile(oldPath:String, newPath:String) : Bool {
		if( !fileExists(oldPath) || fileExists(newPath) )
			return false;
		else
			return
				try { js.node.Fs.renameSync(oldPath,newPath); true; }
				catch(e:Dynamic) false;
	}

	/** Delete a file **/
	public static function removeFile(path:String) : Bool {
		if( !fileExists(path) )
			return false;
		else {
			return
				try { js.node.Fs.unlinkSync(path); true; }
				catch(e:Dynamic) false;
		}
	}

	/** Load file content as String **/
	public static function readFileString(path:String) : Null<String> {
		if( !fileExists(path) )
			return null;
		else
			return js.node.Fs.readFileSync(path).toString();
	}

	/** Load file content as Haxe Bytes **/
	public static function readFileBytes(path:String) : Null<haxe.io.Bytes> {
		if( !fileExists(path) )
			return null;
		else
			return js.node.Fs.readFileSync(path).hxToBytes();
	}

	/** Write a String to a file **/
	public static function writeFileString(path:String, str:String) {
		js.node.Fs.writeFileSync( path, str );
	}

	/** Write Haxe Bytes to a file **/
	public static function writeFileBytes(path:String, bytes:haxe.io.Bytes) {
		js.node.Fs.writeFileSync( path, js.node.Buffer.hxFromBytes(bytes) );
	}

	/** Creates a path recursively **/
	public static function createDirs(dirPath:String) {
		if( fileExists(dirPath) )
			return false;

		// Split sub dirs
		var subDirs = dn.FilePath.fromDir(dirPath).getSubDirectories(true);
		for(subPath in subDirs)
			if( !fileExists(subPath) )
				js.node.Fs.mkdirSync(subPath);
		return true;
	}

	/** Copy a file **/
	public static function copyFile(from:String, to:String) {
		if( !fileExists(from) )
			return;

		(cast js.node.Fs).copyFileSync(from, to);
	}

	/** Remove a directory **/
	public static function removeDir(path:String) {
		if( !isDirectory(path) )
			return;

		js.node.Fs.rmdirSync(path, {
			recursive: true, retryDelay: 1000, maxRetries: 3 // WARNING: requires NodeJS 12+
		});
	}

	/** Return TRUE if the directory contains anything: file or sub-dirs (even empty ones) **/
	public static function dirContainsAnything(path:String) {
		if( !isDirectory(path) )
			return false;

		for( f in js.node.Fs.readdirSync(path) )
			return true;

		return false;
	}

	/** Return TRUE if the directory contains any file (empty sub-dirs will be ignored) **/
	public static function dirContainsAnyFile(path:String) {
		if( !isDirectory(path) )
			return false;

		var pendings = [ path ];
		while( pendings.length>0 ) {
			var fp = dn.FilePath.fromDir( pendings.shift() );
			for( f in Fs.readdirSync(fp.full) ) {
				var inf = Fs.lstatSync(fp.full+"/"+f);
				if( !inf.isDirectory() )
					return true;
				else if( !inf.isSymbolicLink() ) {}
					pendings.push( fp.full+"/"+f );
			}
		}

		return false;
	}

	/** Delete all FILES in directory AND its sub-dirs **/
	public static function removeAllFilesInDir(path:String, ?onlyExts:Array<String>) {
		if( !isDirectory(path) )
			return;

		var extMap = new Map();
		if( onlyExts!=null )
			for(e in onlyExts)
				extMap.set(e, true);

		js.node.Require.require("fs");
		var fp = dn.FilePath.fromDir(path);
		for(f in js.node.Fs.readdirSync(path)) {
			fp.fileWithExt = f;
			if( js.node.Fs.lstatSync(fp.full).isFile() && ( onlyExts==null || extMap.exists(fp.extension) ) )
				js.node.Fs.unlinkSync(fp.full);
		}
	}

	/** List all entries in a given directory **/
	public static function readDir(path:String) : Array<String> {
		if( !isDirectory(path) )
			return [];

		js.node.Require.require("fs");
		return try js.node.Fs.readdirSync(path) catch(_) [];
	}

	/** Find all files in given directory and its subdirs **/
	public static function findFilesRecInDir(dirPath:String, ?ext:String) : Array<dn.FilePath> {
		if( !isDirectory(dirPath) )
			return [];

		var all = [];
		var pendings = [dirPath];
		while( pendings.length>0 ) {
			var dir = pendings.shift();
			for(f in readDir(dir)) {
				var fp = dn.FilePath.fromFile(dir+"/"+f);
				if( js.node.Fs.lstatSync(fp.full).isFile() ) {
					if( ext==null || fp.extension==ext )
						all.push(fp);
				}
				else if( !js.node.Fs.lstatSync(fp.full).isSymbolicLink() )
					pendings.push(fp.full);
			}
		}
		return all;
	}

}
