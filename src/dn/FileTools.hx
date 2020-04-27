package dn;

class FileTools {
	#if( hl || neko )
	public static function deleteDirectoryRec(path:String) {
		var fp = FilePath.fromDir(path);
		fp.convertToSlashes();
		path = fp.directory;

		if( !sys.FileSystem.exists(path) )
			return;

		try {
			// List & remove files
			var pendingDirs = [path];
			var dirsToRemove = pendingDirs.copy();
			while( pendingDirs.length>0 ) {
				var cur = pendingDirs.shift();
				for( e in sys.FileSystem.readDirectory(cur) ) {
					if( sys.FileSystem.isDirectory(cur+"/"+e) ) {
						dirsToRemove.push(cur+"/"+e);
						pendingDirs.push(cur+"/"+e);
					}
					else {
						sys.FileSystem.deleteFile(cur+"/"+e);
					}
				}
			}

			// Remove folders
			dirsToRemove.reverse();
			for(path in dirsToRemove)
				sys.FileSystem.deleteDirectory(path);
		}
		catch( err:Dynamic ) {
			throw "Couldn't delete directory "+path+" (ERR: "+err+")";
		}
	}
	#end
}
