package dn.js;

#if !electron
#error "HaxeLib \"electron\" is required";
#end

import electron.main.IpcMain;
import electron.renderer.IpcRenderer;
import electron.main.App;

import js.Node.__dirname;
import js.Node.process;


typedef SubMenuItem = {
	var label : String;
	var click : Void->Void;
	var ?accelerator : String;
}


/**
	Various useful methods for Electron based apps.

	USAGE:
	. add `ElectronTools.initMain(..)` to Main process (after the creation of the BrowserWindow instance)
	. RECOMMENDED: add `import ElectronTools as ET` to `import.hx`
**/

class ElectronTools {
	static var mainWindow : electron.main.BrowserWindow;

	/**
		This init MUST be called after the creation of the BrowserWindow instance in "Main" process.
	**/
	public static function initMain(win:electron.main.BrowserWindow) {
		mainWindow = win;

		// Invoke()/handle()
		IpcMain.handle("exitApp", exitApp);
		IpcMain.handle("reloadWindow", reloadWindow);
		IpcMain.handle("toggleDevTools", toggleDevTools);
		IpcMain.handle("openDevTools", openDevTools);
		IpcMain.handle("closeDevTools", closeDevTools);
		IpcMain.handle("setFullScreen", (ev,flag)->setFullScreen(flag));
		IpcMain.handle("setWindowTitle", (ev,str)->setWindowTitle(str));
		IpcMain.handle("fatalError", (ev,str)->fatalError(str));
		IpcMain.handle("showError", (ev,title,str)->showError(title,str));

		// SendSync()/on()
		IpcMain.on("getScreenWidth", ev->ev.returnValue = getScreenWidth());
		IpcMain.on("getScreenHeight", ev->ev.returnValue = getScreenHeight());
		IpcMain.on("getZoom", ev->ev.returnValue = getZoom());
		IpcMain.on("getPixelRatio", ev->ev.returnValue = getPixelRatio());
		IpcMain.on("getRawArgs", ev->ev.returnValue = getRawArgs());
		IpcMain.on("getAppResourceDir", ev->ev.returnValue = getAppResourceDir());
		IpcMain.on("getExeDir", ev->ev.returnValue = getExeDir());
		IpcMain.on("getLogDir", ev->ev.returnValue = getLogDir());
		IpcMain.on("getUserDataDir", ev->ev.returnValue = getUserDataDir());
		IpcMain.on("isFullScreen", ev->ev.returnValue = isFullScreen());
		IpcMain.on("isDevToolsOpened", ev->ev.returnValue = isDevToolsOpened());
		IpcMain.on("locate", (ev,path,isFile)->ev.returnValue = locate(path,isFile));
	}

	/** Return TRUE in electron "renderer" process **/
	public static inline function isRenderer() {
		return electron.main.App==null;
	}

	/** Close app **/
	public static function exitApp()
		isRenderer() ? IpcRenderer.invoke("exitApp") : App.exit();

	/** Reload current window **/
	public static function reloadWindow()
		isRenderer() ? IpcRenderer.invoke("reloadWindow") : mainWindow.reload();

	/** Toggle browser dev tools **/
	public static function toggleDevTools()
		isRenderer() ? IpcRenderer.invoke("toggleDevTools") : mainWindow.webContents.toggleDevTools();

	/** Open browser dev tools **/
	public static function openDevTools()
		isRenderer() ? IpcRenderer.invoke("openDevTools") : mainWindow.webContents.openDevTools();

	/** Close browser dev tools **/
	public static function closeDevTools()
		isRenderer() ? IpcRenderer.invoke("closeDevTools") : mainWindow.webContents.closeDevTools();

	/** Set fullscreen mode **/
	public static function setFullScreen(full:Bool)
		isRenderer() ? IpcRenderer.invoke("setFullScreen",full) : mainWindow.setFullScreen(full);

	/** Change window title **/
	public static function setWindowTitle(str:String)
		isRenderer() ? IpcRenderer.invoke("setWindowTitle",str) : mainWindow.setTitle(str);

	/** Return fullscreen mode **/
	public static function isFullScreen() : Bool
		return isRenderer() ? IpcRenderer.sendSync("isFullScreen") : mainWindow.isFullScreen();

	/** Return status of the dev tools panel **/
	public static function isDevToolsOpened() : Bool
		return isRenderer() ? IpcRenderer.sendSync("isDevToolsOpened") : mainWindow.webContents.isDevToolsOpened();

	/** Get primary display width in pixels **/
	public static function getScreenWidth() : Float
		return isRenderer()
			? IpcRenderer.sendSync("getScreenWidth")
			: electron.main.Screen.getPrimaryDisplay().size.width;

	/** Get primary display height in pixels **/
	public static function getScreenHeight() : Float
		return isRenderer()
			? IpcRenderer.sendSync("getScreenHeight")
			: electron.main.Screen.getPrimaryDisplay().size.height;

	/** Get primary display pixel density **/
	public static function getPixelRatio() : Float
		return isRenderer()
			? IpcRenderer.sendSync("getPixelRatio")
			: electron.main.Screen.getPrimaryDisplay().scaleFactor;

	/** Get the root of the app resources (where `package.json` is) **/
	public static function getAppResourceDir() : String
		return isRenderer() ? IpcRenderer.sendSync("getAppResourceDir") : App.getAppPath();

	/** Get the path to app log files (or create it if missing) **/
	public static function getLogDir() : String
		return isRenderer() ? IpcRenderer.sendSync("getLogDir") : App.getPath("logs");

	/** Get the path to the app EXE (Electron itself in debug, or the app executable in packaged versions) **/
	public static function getExeDir() : String
		return isRenderer() ? IpcRenderer.sendSync("getExeDir") : App.getPath("exe");

	/** Get OS user data folder **/
	public static function getUserDataDir() : String
		return isRenderer() ? IpcRenderer.sendSync("getUserDataDir") : App.getPath("userData");

	/** Get args as an array of Strings **/
	public static function getRawArgs() : Array<String> {
		return isRenderer()
			? try electron.renderer.IpcRenderer.sendSync("getRawArgs") catch(_) []
			: process.argv;
	}

	/** Get typed args **/
	public static function getArgs() : dn.Args {
		var raw : Array<String> = getRawArgs();
		raw.shift();
		return new dn.Args( raw.join(" ") );
	}

	/** Get zoom factor need to fit provided fittedWid/Hei. If container wid/hei aren't provided, the `mainWindow` inner client area size will be used instead. **/
	public static function getZoomToFit(fittedWid:Float, fittedHei:Float, ?containerWid:Float, ?containerHei:Float) : Float {
		return dn.M.fmax( 1/getPixelRatio(), dn.M.fmin(
			( containerWid==null ? mainWindow.getContentSize()[0] : containerWid ) / fittedWid,
			( containerHei==null ? mainWindow.getContentSize()[1] : containerHei) / fittedHei
		));
	}

	/** Get window zoom factor **/
	public static function getZoom() : Float
		return isRenderer() ? IpcRenderer.sendSync("getZoom") : mainWindow.webContents.getZoomFactor();



	/** Stop with an error message then close **/
	public static function fatalError(err:String) {
		if( isRenderer() )
			IpcRenderer.invoke("fatalError", err);
		else {
			electron.main.Dialog.showErrorBox("Fatal error", err);
			App.quit();
		}
	}

	public static function showError(title:String, err:String) {
		if( isRenderer() )
			IpcRenderer.invoke("showError", err);
		else
			electron.main.Dialog.showErrorBox(title, err);
	}

	/** Open system file explorer on target file or dir. Return FALSE if something didn't work. **/
	public static function locate(path:String, isFile:Bool) : Bool {
		if( path==null )
			return false;

		if( isRenderer() )
			return IpcRenderer.sendSync("locate", path, isFile);
		else {
			var fp = isFile ? dn.FilePath.fromFile(path) : dn.FilePath.fromDir(path);

			if( NodeTools.isWindows() )
				fp.useBackslashes();

			// Try to open parent folder
			if( isFile && !NodeTools.fileExists(fp.full) ) {
				isFile = false;
				fp.fileWithExt = null;
			}

			// Not found
			if( !NodeTools.fileExists(fp.full) )
				return false;

			// Open
			if( fp.fileWithExt==null )
				electron.Shell.openPath(fp.full);
			else
				electron.Shell.showItemInFolder(fp.full);

			return true;
		}

	}



	/* ELECTRON MAIN ONLY ************************************************/

	/** Clear current window menu **/
	public static function m_clearMenu() {
		mainWindow.setMenu(null);
	}

	/** Replace current window menu with a debug menu **/
	public static function m_createDebugMenu(?items:Array<SubMenuItem>) : electron.main.Menu {
		if( items==null )
			items = [];

		// Base
		var menu = electron.main.Menu.buildFromTemplate([{
			label: "Debug tools",
			submenu: cast [
				{
					label: "Reload",
					click: reloadWindow,
					accelerator: "CmdOrCtrl+R",
				},
				{
					label: "Dev tools",
					click: toggleDevTools,
					accelerator: "CmdOrCtrl+Shift+I",
				},
				{
					label: "Toggle full screen",
					click: function() setFullScreen( !isFullScreen() ),
					accelerator: "Alt+Enter",
				},
				{
					label: "Exit",
					click: exitApp,
					accelerator: "CmdOrCtrl+Q",
				},
			].concat(items)
		}]);

		mainWindow.setMenu(menu);

		return menu;
	}
}