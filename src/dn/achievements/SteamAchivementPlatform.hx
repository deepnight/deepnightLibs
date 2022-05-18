package dn.achievements;

import cdb.Types.ArrayRead;
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

	public function getUnlocked(?achs:cdb.Types.ArrayRead<Achievements>):Array<String>{
        var dones = new Array<String>();
		for(idx in 0...steam.Api.getNumAchievements()) {
			var id = steam.Api.getAchievementAPIName(idx);
			if( steam.Api.getAchievement(id) )
				dones.push(getAchById(id,achs).Id.toString());
		}
        return dones;
    }

	public function unlock(ach:Achievements):Bool {
		return steam.Api.setAchievement(ach.steamID);
	}

	override function getAchById(id:String, achs:ArrayRead<Achievements>):Achievements {
        for (ach in achs){
            if(ach.steamID == id) return ach;
        }
        return null;
	}
}
#end