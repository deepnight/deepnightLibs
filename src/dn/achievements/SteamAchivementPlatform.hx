package dn.achievements;

#if hlsteam
import dn.data.AchievementDb;

/**
 * Steam platform support
 */
class SteamAchivementPlatform extends AbstractAchievementPlatform {
    

	public function init() {}

	function internalClear(ach:Achievements) {
        var ok = steam.Api.clearAchievement(ach.steamID);
		trace(ach.Id+": "+(ok?"Ok":"FAILED!"));
    }

	public function getUnlocked():Map<String,Bool>{
        var dones = new Map<String,Bool>();
		for(idx in 0...steam.Api.getNumAchievements()) {
			var id = steam.Api.getAchievementAPIName(idx);
			if( steam.Api.getAchievement(id) )
				dones.set(id, true);
		}
        return dones;
    }

	public function unlock(ach:Achievements):Bool {
		return steam.Api.setAchievement(ach.steamID);
	}
}
#end