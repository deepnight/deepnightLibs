package dn.electron;

import electron.main.IpcMain;
import electron.renderer.IpcRenderer;

#if !electron
#error "HaxeLib \"electron\" is required";
#end

private typedef UpdateInfo = {
	var version: String;
	var files: Array<Dynamic>;
	var ?releaseName: Null<String>;
	var ?releaseNotes: Null< haxe.extern.EitherType<String, Array<Dynamic>> >;
	var releaseDate: String;
	var ?stagingPercentage: Int;
}

private extern class AutoUpdater {
	public function checkForUpdates() : Dynamic;
	public function on(eventId:String, onEvent:UpdateInfo->Void) : Dynamic;
	public function quitAndInstall(isSilent:Bool=false, isForceRunAfter:Bool=false) : Dynamic;
}


class ElectronUpdater {
	public static var isIntalling(default,null) : Bool;

	/**
		Electron Main bindings
	**/
	public static function initMain(win:electron.main.BrowserWindow) {
		if( IpcMain==null )
			throw "Should only be called in electorn Main!";

		var autoUpdater : electronUpdater.AutoUpdater = js.node.Require.require("electron-updater").autoUpdater;
		isIntalling = false;
		var isChecking = false;
		var hasDownloadedUpdate = false;

		autoUpdater.on("checking-for-update", function(info) {
			isChecking = true;
			win.webContents.send("updateCheckStart", info);
		});

		autoUpdater.on("update-available", function(info) {
			isChecking = false;
			win.webContents.send("updateFound", info);
		});

		autoUpdater.on("update-not-available", function(info) {
			isChecking = false;
			win.webContents.send("updateNotFound");
		});

		autoUpdater.on("update-downloaded", function(info) {
			js.html.Console.log("Update ready!");
			win.webContents.send("updateDownloaded");
			hasDownloadedUpdate = true;
		});

		autoUpdater.on("error", function(_) {
			if( isChecking )
				win.webContents.send("updateError");
			isChecking = false;
		});

		IpcMain.handle("checkUpdate", function(event,args) {
			autoUpdater.checkForUpdates();
		});

		IpcMain.handle("installUpdate", function(event) {
			if( !hasDownloadedUpdate ) {
				js.html.Console.log("Need to download update first!");
				return;
			}
			js.html.Console.log("Installing update...");
			isIntalling = true;
			autoUpdater.quitAndInstall();
		});
	}

	/**
		Electron Renderer bindings
	**/
	public static function initRenderer() {
		if( IpcRenderer==null )
			throw "Should only be called in electron Renderer!";

		var info : Null<UpdateInfo> = null;

		IpcRenderer.on("updateError", function(ev) {
			onError();
			onUpdateCheckComplete();
		});

		IpcRenderer.on("updateCheckStart", function(ev) {
			onUpdateCheckStart();
		});

		IpcRenderer.on("updateFound", function(ev, i:UpdateInfo) {
			info = i;
			onUpdateFound(info);
			onUpdateCheckComplete();
		});

		IpcRenderer.on("updateNotFound", function(ev) {
			onUpdateNotFound();
			onUpdateCheckComplete();
		});

		IpcRenderer.on("updateDownloaded", function(ev) {
			onUpdateDownloaded(info);
		});
	}

	public static function emulate() {
		var info : UpdateInfo = {
			version: "0.0.0",
			releaseDate: "1981-01-15",
			files: [],
		}

		onUpdateCheckStart();

		haxe.Timer.delay( function() {
			onUpdateFound(info);
			onUpdateCheckComplete();
		}, 800 );

		haxe.Timer.delay( function() {
			onUpdateDownloaded(info);
		}, 2000 );
	}

	public static function checkNow() {
		IpcRenderer.invoke("checkUpdate");
	}

	public static function installNow() {
		IpcRenderer.invoke("installUpdate");
	}


	// Callbacks
	public static dynamic function onUpdateCheckStart() {}
	public static dynamic function onUpdateFound(info:UpdateInfo) {}
	public static dynamic function onUpdateDownloaded(info:UpdateInfo) {}
	public static dynamic function onUpdateNotFound() {}
	public static dynamic function onError() {}
	public static dynamic function onUpdateCheckComplete() {}

}

