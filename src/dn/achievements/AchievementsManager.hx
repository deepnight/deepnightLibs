package dn.achievements;

import dn.achievements.AbstractAchievementPlatform;
import dn.data.AchievementDb;


class AchievementsManager {
	public var isLocal(get,never):Bool; inline function get_isLocal() return platform.isLocal;
	
	var dones : Array<String>;
	var platform:AbstractAchievementPlatform;

	public function new(platform:AbstractAchievementPlatform,?dbName:String = "achievements.cdb") {
		this.platform = platform;
		
		AchievementDb.load(hxd.Res.load(dbName).toText());
		dones = this.platform.getUnlocked(AchievementDb.achievements.all);
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
			platform.unlock(getAchievementByName(id));
			dones.push(id);
			return true;
		}
		else
			return false;
	}

	public inline function isCompleted(id:String) {
		return hasAchievement(id) && dones.contains(id);
	}

	public inline function hasAchievement(id:String):Bool {
		return getAchievementByName(id) != null;
	}

	public function getAchievementByName(name:String):Achievements{
		return AchievementDb.achievements.resolve(name);
	}
}