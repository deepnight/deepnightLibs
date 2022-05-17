package dn.achievements;

import dn.achievements.AbstractAchievementPlatform;
import dn.data.AchievementDb;


class AchievementsManager {
	var dones : Map<String,Bool>;
	var platform:AbstractAchievementPlatform;

	public function new(platform:AbstractAchievementPlatform,?dbName:String = "achievements.cdb") {
		this.platform = platform;
		
		AchievementDb.load(hxd.Res.load(dbName).toText());
		dones = this.platform.getUnlocked();
	}

	public function clear(id:String) {
		dones.remove(id);
		platform.clear(getAchievementByName(id));
	}

	public function getAllIds() {
		var ids = [];
		for(ach in AchievementDb.achievements.all)
			ids.push(ach.Id.toString());
		return ids;
	}

	public function complete(id:String) {
		if( !isCompleted(id) ) {
			dones.set(id,true);
			platform.unlock(getAchievementByName(id));
			return true;
		}
		else
			return false;
	}

	public inline function isCompleted(id:String) {
		return hasAchievement(id) && dones.exists(id) && dones.get(id)==true;
	}

	public inline function hasAchievement(id:String):Bool {
		return getAchievementByName(id) != null;
	}

	public function getAchievementByName(name:String):Achievements{
		return AchievementDb.achievements.resolve(name);
	}
}