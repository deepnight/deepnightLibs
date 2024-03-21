package dn.store.impl;

#if !hlsteam
#error "HLSteam is required"
#end

class SteamImpl extends dn.store.StoreAPI {
	var appId : Int;

	public function new(appId) {
		super();
		this.appId = appId;
		name = 'Steam#$appId';
	}

	override function preBootInit() {
		super.preBootInit();
		if( !steam.Api.init(appId) )
			print("Steam init failed.");
	}

	override function isActive() {
		return steam.Api.active;
	}

	override function appInit() {
		super.appInit();

		// Check Steam
		if( !isActive() ) {
			#if !debug
			throw "Steam is not running!";
			#end
		}

		#if debug
		print("Steam ready.");
		#end

		steam.Api.onOverlay = onOverlay;

	}
}