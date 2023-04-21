package dn.js;

#if !electron
#error "HaxeLib \"electron\" is required";
#end

import electron.main.IpcMain;
import electron.renderer.IpcRenderer;

class ElectronDialogs {
	static function isWindows() {
		return js.Node.process.platform.toLowerCase().indexOf("win")==0;
	}


	public static function initMain(browserWindow:electron.main.BrowserWindow) {
		if( IpcMain==null )
			throw "Should only be called in Electron Main";

		IpcMain.handle("openDialog", function(event, options) {
			var result = electron.main.Dialog.showOpenDialogSync(browserWindow, options);
			return switch Type.typeof(result) {
				case TClass(String): result;
				case TClass(Array): result[0];
				case _: result;
			}
		});

		IpcMain.handle("saveAsDialog", function(event, options) {
			var filePaths = electron.main.Dialog.showSaveDialogSync(browserWindow, options);
			return filePaths==null ? null : filePaths;
		});
	}

	public static function openFile(?extWithDots:Array<String>, startDir:String, onLoad:(filePath:String)->Void) {
		if( isWindows() )
			startDir = FilePath.convertToBackslashes(startDir);

		var options = {
			filters: extWithDots==null
				? [{ name:"Any file type", extensions:["*"] }]
				: [{ name:"Supported file types", extensions:extWithDots.map( function(ext) return ext.substr(1) ) }],
			defaultPath: startDir,
		}
		IpcRenderer.invoke("openDialog", options).then( function(res) {
			if( res!=null )
				onLoad( Std.string(res) );
		});
	}

	public static function openDir(startDir:String, onLoad:(filePath:String)->Void) {
		if( isWindows() )
			startDir = FilePath.convertToBackslashes(startDir);

		var options = {
			defaultPath: startDir,
			properties: ["openDirectory"],
		}
		IpcRenderer.invoke("openDialog", options).then( function(res) {
			if( res!=null )
				onLoad( Std.string(res) );
		});
	}


	public static function saveFileAs(?extWithDots:Array<String>, startDir:String, onFileSelect:(filePath:String)->Void) {
		if( isWindows() )
			startDir = FilePath.convertToBackslashes(startDir);

		var options = {
			filters: extWithDots==null
				? [{ name:"Any file type", extensions:["*"] }]
				: [{ name:"Supported file types", extensions:extWithDots.map( function(ext) return ext.substr(1) ) }],
			defaultPath: startDir,
		}
		IpcRenderer.invoke("saveAsDialog", options).then( function(res) {
			if( res!=null )
				onFileSelect( Std.string(res) );
		});
	}
}
