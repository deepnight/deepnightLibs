package dn.achievements;

import haxe.ds.StringMap;
import dn.data.AchievementDb;

/**
 * Local Achivement platform
 * Save in Array
 */
class LocalAchivementPlatform extends AbstractAchievementPlatform {
	var dones : Array<String>;

	public function new() {
		super();
		isLocal = true;
	}

	public function updateDones(originalStatus:Array<String> = null) {
		if(originalStatus == null) originalStatus = [];
		dones = originalStatus;
	}
	public function init() {}

	function internalClear(ach:Achievements) {
        var ok = dones.remove(ach.Id.toString());
		trace(ach.Id+": "+(ok?"Ok":"FAILED!"));
    }

	public function getUnlocked(?achs:cdb.Types.ArrayRead<Achievements>):Array<String>{
        return dones;
    }

	public function unlock(ach:Achievements):Bool {
		if(!dones.contains(ach.Id.toString()))dones.push(ach.Id.toString());
		return true;
	}
}