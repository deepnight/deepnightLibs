package dn.js;

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

		autoUpdater.on("error", function(ev) {
			var ev : js.lib.Error = cast ev;
			if( isChecking )
				win.webContents.send("updateError", ev.message);
			isChecking = false;
		});

		IpcMain.handle("checkUpdate", function(event,args) {
			var prom = autoUpdater.checkForUpdates();
			prom.then(()->{}, (err)->{});
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

		IpcRenderer.on("updateError", function(ev, errMsg:String) {
			onError(errMsg);
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
		}, 500 );

		haxe.Timer.delay( function() {
			onUpdateDownloaded(info);
		}, 1000 );
	}

	public static function fetchLatestGitHubReleaseVersion(author:String, repo:String, onLoad:(ver:Null<Version>)->Void) {
		fetchLatestGitHubReleaseTag(author, repo, (?t)->{
			if( t==null ) {
				onLoad(null);
				return;
			}
			var reg = ~/([0-9]+\.[0-9.]*)/gi;
			if( reg.match(t) )
				onLoad( new dn.Version(reg.matched(1)) );
			else
				onLoad(null);
		});
	}

	public static function fetchLatestGitHubReleaseTag(author:String, repo:String, onLoad:(tag:Null<String>)->Void) {
		author = StringTools.urlEncode(author);
		repo = StringTools.urlEncode(repo);

		var options : js.node.Https.HttpsRequestOptions = {
			hostname: 'api.github.com',
			path: '/repos/$author/$repo/releases/latest',
			method: "GET",
			headers: { 'User-Agent': 'Electron/LDtk' },
		}
		js.node.Https.get( options, (res)->{
			if( res.aborted || res.statusCode<200 || res.statusCode>=400 ) {
				onLoad(null);
				return;
			}

			var full = "";
			res.on("data", (raw)->{
				full+=raw;
			});
			res.on("end", ()->{
				if( full.length==0 )
					onLoad(null);
				else {
					var json : Dynamic = try haxe.Json.parse(full) catch(e:Dynamic) null;
					if( json==null || json.tag_name==null )
						onLoad(null);
					else
						onLoad( Std.string( json.tag_name ) );
				}
			});
		}).on( "error", ()->onLoad(null) );
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
	public static dynamic function onError(msg:String) {}
	public static dynamic function onUpdateCheckComplete() {}

}

