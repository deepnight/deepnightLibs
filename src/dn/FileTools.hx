package dn;

class FileTools {
	#if sys
	public static function deleteDirectoryRec(path:String) {
		var fp = FilePath.fromDir(path);
		fp.useSlashes();
		path = fp.directory;

		if( !sys.FileSystem.exists(path) )
			return;

		try {
			var all = listAllFilesRec(path);

			// Remove files
			for(f in all.files)
				sys.FileSystem.deleteFile(f);

			// Remove folders
			all.dirs.reverse();
			for(path in all.dirs)
				sys.FileSystem.deleteDirectory(path);
		}
		catch( err:Dynamic ) {
			throw "Couldn't delete directory "+path+" (ERR: "+err+")";
		}
	}
	#end

	#if sys
	public static function copyDirectoryRec(from:String, to:String) {
		var to = dn.FilePath.extractDirectoryWithSlash(to,false);
		var all = listAllFilesRec(from);

		var dirName = FilePath.fromDir(from).getLastDirectory();
		if( dirName=="." || dirName==".." )
			throw "Unsupported operation with a path terminated by dots ("+from+")";

		sys.FileSystem.createDirectory(to+dirName);
		to+=dirName+"/";

		// Create directory structure
		for(d in all.dirs) {
			if( d.indexOf(from)==0 )
				d = d.substr(from.length);
			while( d.charAt(0)=="/" )
				d = d.substr(1);

			if( d.length==0 )
				continue;

			sys.FileSystem.createDirectory(to+d);
		}

		// Copy files
		for(f in all.files) {
			var target = f;
			if( target.indexOf(from)==0 )
				target = target.substr(from.length);
			while( target.charAt(0)=="/" )
				target = target.substr(1);

			sys.io.File.copy(f, to+target);
		}
	}
	#end

	#if sys
	public static function listAllFilesRec(path:String) : { dirs:Array<String>, files:Array<String> } {
		// List elements
		var pendingDirs = [path];
		var dirs = [];
		var files = [];
		while( pendingDirs.length>0 ) {
			var cur = pendingDirs.shift();
			dirs.push( FilePath.fromDir(cur).full );
			for( e in sys.FileSystem.readDirectory(cur) ) {
				if( sys.FileSystem.isDirectory(cur+"/"+e) )
					pendingDirs.push(cur+"/"+e);
				else
					files.push(  FilePath.fromDir(cur+"/"+e).full );
			}
		}
		return {
			dirs: dirs,
			files: files,
		}
	}
	#end


	#if sys
	public static function zipFolder(zipPath:String, dirPath:String, ?onProgress:(fileName:String, size:Int)->Void) {
		// List entries
		var entries : List<haxe.zip.Entry> = new List();
		var pendingDirs = [ dirPath ];
		while( pendingDirs.length>0 ) {
			var cur = pendingDirs.shift();
			for( fName in sys.FileSystem.readDirectory(cur) ) {
				var path = cur+"/"+fName;
				if( sys.FileSystem.isDirectory(path) ) {
					pendingDirs.push(path);
					entries.add({
						fileName: path.substr(dirPath.length+1) + "/",
						fileSize: 0,
						fileTime: sys.FileSystem.stat(path).ctime,
						data: haxe.io.Bytes.alloc(0),
						dataSize: 0,
						compressed: false,
						crc32: null,
					});
				}
				else {
					var bytes = sys.io.File.getBytes(path);
					entries.add({
						fileName: path.substr(dirPath.length+1),
						fileSize: sys.FileSystem.stat(path).size,
						fileTime: sys.FileSystem.stat(path).ctime,
						data: bytes,
						dataSize: bytes.length,
						compressed: false,
						crc32: null,
					});
				}
			}
		}

		// Zip entries
		var out = new haxe.io.BytesOutput();
		for(e in entries)
			if( e.data.length>0 ) {
				if( onProgress!=null )
					onProgress(e.fileName, e.fileSize);
				e.crc32 = haxe.crypto.Crc32.make(e.data);
				haxe.zip.Tools.compress(e,9);
			}
		var w = new haxe.zip.Writer(out);
		w.write(entries);
		sys.io.File.saveBytes(zipPath, out.getBytes());
	}
	#end
}
