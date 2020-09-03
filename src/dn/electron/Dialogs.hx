package dn.electron;

#if !electron
#error "HaxeLib \"electron\" is required";
#end

import electron.main.IpcMain;
import electron.renderer.IpcRenderer;

class Dialogs {
	public static function initMain() {
		if( IpcMain==null )
			throw "Should only be called in Main";

		IpcMain.handle("openDialog", function(event, options) {
			var filePaths = electron.main.Dialog.showOpenDialogSync(null, options);
			return filePaths==null ? null : filePaths[0];
		});

		IpcMain.handle("saveAsDialog", function(event, options) {
			var filePaths = electron.main.Dialog.showSaveDialogSync(null, options);
			return filePaths==null ? null : filePaths;
		});
	}

	public static function open(?extWithDots:Array<String>, rootDir:String, onLoad:(filePath:String)->Void) {
		var options = {
			filters: extWithDots==null
				? [{ name:"Any file type", extensions:["*"] }]
				: [{ name:"Supported file types", extensions:extWithDots.map( function(ext) return ext.substr(1) ) }],
			defaultPath: rootDir,
		}
		IpcRenderer.invoke("openDialog", options).then( function(res) {
			if( res!=null )
				onLoad( Std.string(res) );
		});
	}


	public static function saveAs(?extWithDots:Array<String>, rootDir:String, onFileSelect:(filePath:String)->Void) {
		var options = {
			filters: extWithDots==null
				? [{ name:"Any file type", extensions:["*"] }]
				: [{ name:"Supported file types", extensions:extWithDots.map( function(ext) return ext.substr(1) ) }],
			defaultPath: rootDir,
		}
		IpcRenderer.invoke("saveAsDialog", options).then( function(res) {
			if( res!=null )
				onFileSelect( Std.string(res) );
		});
	}
}
