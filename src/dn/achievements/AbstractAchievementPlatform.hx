package dn.achievements;
import dn.data.AchievementDb;

/**
 * Abstract Platform Manager
 * Need to be extented for each platform you want to support
 * 
 * manage only states achivements
 * 
 */
abstract class AbstractAchievementPlatform {
    
    public function new(){}
    
    public function clear(ach:Achievements) {
        #if(debug)
        internalClear(ach);
		#else
		trace("Not allowed");
		#end
	}
    
    abstract public function init():Void;
    abstract function internalClear(ach:Achievements):Void;
    abstract public function getUnlocked():Map<String,Bool>;
    abstract public function unlock(ach:Achievements):Bool;

}