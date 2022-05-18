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
    
    public var isLocal(default,null):Bool = false;
    public function new(){}
    
    inline public function clear(ach:Achievements) {
        #if(debug)
        internalClear(ach);
		#else
		trace("Not allowed");
		#end
	}
    
    abstract public function init():Void;
    abstract public function getUnlocked(?achs:cdb.Types.ArrayRead<Achievements>):Array<String>;
    abstract public function unlock(ach:Achievements):Bool;
    
    abstract function internalClear(ach:Achievements):Void;
    function getAchById(id:String,achs:cdb.Types.ArrayRead<Achievements>):Achievements{
        for (ach in achs){
            if(ach.Id.toString() == id) return ach;
        }
        return null;
    }

}