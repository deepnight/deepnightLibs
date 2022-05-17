package dn.achievements;

import haxe.ds.StringMap;
import dn.data.AchievementDb;

/**
 * Local Achivement platform
 * Save in localMap
 * Id => Bool
 */
class LocalAchivementPlatform extends AbstractAchievementPlatform {
	var dones : Map<String,Bool>;

	public function new(?originalStatus:Map<String,Bool> = null) {
		super();
		if(originalStatus == null) originalStatus = new Map<String,Bool>();
		dones = originalStatus;
	}
	public function init() {}

	function internalClear(ach:Achievements) {
        var ok = dones.remove(ach.Id.toString());
		trace(ach.Id+": "+(ok?"Ok":"FAILED!"));
    }

	public function getUnlocked():Map<String,Bool>{
        return dones;
    }

	public function unlock(ach:Achievements):Bool {
		dones.set(ach.Id.toString(),true);
		return true;
	}
}