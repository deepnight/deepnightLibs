package dn.heaps;

#if !macro
import dn.M;
import hxd.snd.*;
import hxd.res.Sound;
#end


// --- SFX ------------------------------------------------------

class Sfx {
	static var FILEPATH_TO_UID : Map<String,Int> = new Map();
	static var UNIQ = 0;

	/**
		Folder importer using macro
	**/
	@:noCompletion
	macro public static function importDirectory(dir:String) {
		haxe.macro.Context.fatalError("ERROR: use dn.heaps.assets.SfxDirectory.load()", haxe.macro.Context.currentPos());
		return macro null;
	}

	#if placeholderSfx
	/**
		Return a hxd.res.Sound object from the provided placeholder path in `-D placeholderSfx=path/to/placeholder.wav`
	**/
	macro public static function getPlaceholderSfx() {
		var path = haxe.macro.Context.getDefines().get("placeholderSfx");
		return macro hxd.Res.load( $v{path} ).toSound();
	}
	#end


	#if !macro
	static var SPATIAL_LISTENER_X = 0.;
	static var SPATIAL_LISTENER_Y = 0.;
	static var SPATIAL_LISTENER_RANGE = 1.;
	static var ON_PLAY_CB : Map<Int, Sfx->Void> = new Map();
	static var SOUND_VOLUMES_OVERRIDE : Map<Int,Float> = new Map();
	static var SOUND_DEFAULT_GROUPS : Map<Int,Int> = new Map();

	static var GLOBAL_GROUPS : Map<Int, GlobalGroup> = new Map();
	public static var DEFAULT_GROUP_ID = 0;

	var lastChannel : Null<Channel>;
	public var sound(default,null) : Sound;
	public var groupId(default,set) : Int;
	public var soundGroup(get,never) : Null<SoundGroup>;

	public var filePath(get,never) : Null<String>;
		inline function get_filePath() return sound==null || sound.entry==null ? null : sound.entry.path;

	public var soundUid : Int;


	/**
		Target sound volume. Please note that the actual "final" volume will be a mix of this value, the Group volume and optional spatialization.
	**/
	public var volume(default,set) : Float;

	/** Sound duration in seconds **/
	public var baseDurationS(get,never) : Float;
		inline function get_baseDurationS() return sound.getData().duration;

	public var curPlayDurationS(get,never) : Float;
		inline function get_curPlayDurationS() return lastChannel!=null ? lastChannel.duration : 0.;

	var spatialX : Null<Float>;
	var spatialY : Null<Float>;

	/** Multiplier to default spatial max hearing distance **/
	var spatialRangeMul : Float;

	/** This custom ID can be whatever you want. Purely for your own internal usage. **/
	public var customIdentifier : Null<String>;

	/** This callback will be called ONCE when the currently playing sound will stop. **/
	var onEndCurrent : Null< Void->Void >;


	public function new(s:Sound) {
		sound = s;
		volume = 1;
		spatialRangeMul = 1.0;
		groupId = DEFAULT_GROUP_ID;
		soundUid = resolveUid(filePath);
	}

	inline function resolveUid(path:String) : Int {
		if( !FILEPATH_TO_UID.exists(path) )
			FILEPATH_TO_UID.set(path, UNIQ++);
		return FILEPATH_TO_UID.get(path);
	}

	public function dispose() {
		stop();
		sound = null;
		lastChannel = null;
		onEndCurrent = null;
	}

	public function toString() {
		return "Sfx"+( filePath==null?"":'[$filePath]' ) + ( customIdentifier!=null ? customIdentifier : Std.string(sound) );
	}



	inline function set_groupId(v) {
		#if debug
		if( isPlaying() )
			trace("WARNING: changing groupId of a playing Sfx will not affect it immediately.");
		#end
		return groupId = v;
	}

	inline function get_soundGroup() return getGlobalGroup(groupId).soundGroup;

	inline function set_volume(v) {
		volume = M.fclamp(v,0,1);
		if( isPlaying() )
			applyVolume();
		return volume;
	}

	public static inline function setSpatialListenerPosition(x:Float, y:Float, maxRange:Float) {
		SPATIAL_LISTENER_X = x;
		SPATIAL_LISTENER_Y = y;
		SPATIAL_LISTENER_RANGE = maxRange;
	}

	static function getGlobalGroup(id) : GlobalGroup {
		if( !GLOBAL_GROUPS.exists(id) )
			GLOBAL_GROUPS.set(id, new GlobalGroup(id));
		return GLOBAL_GROUPS.get(id);
	}

	public static function setGroupVolume(id:Int, v:Float) {
		getGlobalGroup(id).setVolume(v);
	}

	public static function getGroupVolume(id:Int) {
		return getGlobalGroup(id).getVolume();
	}

	public static function overrideSoundVolume(s:Sfx, newDefaultVolumeMul:Float) {
		SOUND_VOLUMES_OVERRIDE.set(s.soundUid, newDefaultVolumeMul);
	}

	public static function setOnPlayCb(s:Sfx, cb:Sfx->Void) {
		ON_PLAY_CB.set(s.soundUid, cb);
	}

	public static function removeOnPlayCb(s:Sfx, cb:Sfx->Void) {
		ON_PLAY_CB.remove(s.soundUid);
	}

	public static function resetOverridenSoundVolume(s:Sfx) {
		SOUND_VOLUMES_OVERRIDE.remove(s.soundUid);
	}

	public static function setSoundDefaultGroup(s:Sfx, groupId:Int) {
		SOUND_DEFAULT_GROUPS.set(s.soundUid, groupId);
	}

	public static function unsetSoundDefaultGroup(s:Sfx) {
		SOUND_DEFAULT_GROUPS.remove(s.soundUid);
	}


	public inline function togglePlayStop(?loop=false, ?vol:Float) {
		if( isPlaying() ) {
			stop();
			return false;
		}
		else {
			play(loop, vol);
			return true;
		}
	}

	public function togglePlayPause() {
		if( lastChannel==null )
			return false;

		if( !isPaused() ) {
			pause();
			return false;
		}
		else {
			resume();
			return true;
		}
	}

	public function pause() {
		if( lastChannel!=null )
			lastChannel.pause = true;
	}

	public function resume() {
		if( lastChannel!=null )
			lastChannel.pause = false;
	}

	public inline function isPaused() return lastChannel!=null && lastChannel.pause;

	/**
		Update internal stuff when the Sound starts playing.
	**/
	inline function onStartPlaying(c:Channel) {
		onEndCurrent = null;
		lastChannel = c;
		lastChannel.onEnd = ()->{
			if( lastChannel.loop )
				onLoop();

			if( onEndCurrent!=null ) {
				var cb = onEndCurrent;
				onEndCurrent = null;
				cb();
			}

		}
		applyVolume();

		// On play global callbacks
		if( ON_PLAY_CB.exists(soundUid) )
			ON_PLAY_CB.get(soundUid)(this);
	}

	/**
		Called when a looping sound loops.
		This method can be replaced.
	**/
	public dynamic function onLoop() {}

	/**
		Play sound
	**/
	public function play(?loop=false, ?vol:Float) {
		if( vol!=null )
			volume = vol;

		if( isPlaying() )
			stop();

		if( SOUND_DEFAULT_GROUPS.exists(soundUid) )
			groupId = SOUND_DEFAULT_GROUPS.get(soundUid);
		onStartPlaying( sound.play(loop, volume, getGlobalGroup(groupId).soundGroup) );
		return this;
	}

	/**
		Play sound
	**/
	public inline function playFadeIn(?loop=false, targetVol:Float, sec:Float) {
		play(loop, 0);
		fadeTo(targetVol, sec);
		return this;
	}

	/**
		Play sound using spatial localization
	**/
	public function playSpatial(x:Float, y:Float, ?vol:Float) {
		if( vol!=null )
			volume = vol;

		if( isPlaying() )
			stop();

		onStartPlaying(  sound.play(false, volume, getGlobalGroup(groupId).soundGroup) );
		setSpatialPos(x,y);
		return this;
	}

	/**
		Change spatial location of the playing sound

		SOUND MUST BE PLAYING.
	**/
	public inline function setSpatialPos(x:Float, y:Float) {
		spatialX = x;
		spatialY = y;
		applyVolume();

		return this;
	}

	/**
		Change spatial range
	**/
	public inline function setSpatialRangeMul(rangeMul=1.0) {
		spatialRangeMul = rangeMul;
		if( isPlaying() )
			applyVolume();
		return this;
	}

	/**
		Disable spatialization
	**/
	public inline function disableSpatialization() {
		spatialX = spatialY = null;
		applyVolume();
		return this;
	}

	function applyVolume() {
		if( _requiresChannel() )
			lastChannel.volume = getFinalVolume();
	}

	/**
		Return final actual volume (a mix of Sfx, spatialization and Group factors)
	**/
	public inline function getFinalVolume() {
		return getMixedVolumeFactor() * volume;
	}


	/**
		Get the multiplier factor that should be applied to volume value to reflect spatialization and group volumes.
	**/
	function getMixedVolumeFactor() {
		var spatial = 1.0;
		if( M.isValidNumber(spatialX) && M.isValidNumber(spatialY) ) {
			var dist = Math.sqrt( (spatialX-SPATIAL_LISTENER_X)*(spatialX-SPATIAL_LISTENER_X) + (spatialY-SPATIAL_LISTENER_Y)*(spatialY-SPATIAL_LISTENER_Y) );
			var f = M.fclamp( 1 - dist / ( SPATIAL_LISTENER_RANGE * spatialRangeMul ), 0, 1 );
			spatial = f*f*f;
		}

		final overrideVol : Float = SOUND_VOLUMES_OVERRIDE.exists(soundUid) ? SOUND_VOLUMES_OVERRIDE.get(soundUid) : 1;

		return getGlobalGroup(groupId).getVolume() * spatial * overrideVol;
	}

	/**
		Bind a callback to the end of currently playing sound

		SOUND MUST BE PLAYING.
	**/
	public function onEnd(cb:Void->Void) {
		if( _requiresChannel() )
			onEndCurrent = cb;
	}

	public function clearOnEndCallback() {
		onEndCurrent = null;
	}

	/**
		Check for the existence of a Channel (ie. sounds is currently playing). In "debug" mode, an exception is thrown if none is found.
	**/
	inline function _requiresChannel() : Bool {
		if( lastChannel==null || lastChannel.isReleased() ) {
			#if debug
			throw "Sound must be playing to use this method";
			#end
			return false;
		}
		else
			return true;
	}

	public inline function isPlaying() {
		return lastChannel!=null && !isPaused();
	}

	public inline function isFading() {
		return lastChannel!=null && @:privateAccess lastChannel.currentFade!=null;
	}

	/**
		Stop sound
	**/
	public function stop() {
		if( lastChannel!=null )
			lastChannel.stop();
		lastChannel = null;
	}

	/**
		Stop sound with a fade-out
	**/
	public inline function stopWithFadeOut(duratonS:Float) {
		if( lastChannel!=null && lastChannel.volume<=0.03 )
			stop();
		else
			fadeTo(0, duratonS, stop);
	}

	/**
		Fade volume to given level

		SOUND MUST BE PLAYING.
	**/
	public function fadeTo(vol:Float, duratonS=1.0, ?onComplete:Void->Void) {
		if( _requiresChannel() )
			lastChannel.fadeTo(vol * getMixedVolumeFactor(), duratonS, onComplete);
		return this;
	}


	/**
		Play sound on given group
	**/
	public function playOnGroup(gid:Int, ?loop=false, ?vol:Float) {
		groupId = gid;
		play(loop, vol);
		return this;
	}


	/**
		Change play position (in seconds).

		SOUND MUST BE PLAYING.
	**/
	public inline function setPositionS(time:Float) {
		if( _requiresChannel() )
			lastChannel.position = time;
		return this;
	}


	/**
		Change play position using a ratio of the total duration (0-1).

		SOUND MUST BE PLAYING.
	**/
	public inline function setPositionRatio(r:Float) {
		if( _requiresChannel() )
			lastChannel.position = baseDurationS*r;
		return this;
	}

	/**
		Attach an Effect to the currently playing sound

		SOUND MUST BE PLAYING.
	**/
	public inline function addEffect(e:Effect) {
		if( _requiresChannel() )
			lastChannel.addEffect(e);
		return this;
	}

	/**
		Adjust pitch randomly withing +/- `range` (percentage, "0.02" means "+/- 2%")

		SOUND MUST BE PLAYING.
	**/
	public inline function pitchRandomly(range=0.12) {
		if( _requiresChannel() )
			addEffect(  new hxd.snd.effect.Pitch( Lib.rnd(1-M.fabs(range), 1+M.fabs(range)) )  );
		return this;
	}


	/**
		Mute a group of Sfx completely
	**/
	public static function muteGroup(id) {
		getGlobalGroup(id).muted = true;
	}

	/**
		Unmute a group
	**/
	public static function unmuteGroup(id) {
		getGlobalGroup(id).muted = false;
	}

	/**
		Toggle muted status of a group
	**/
	public static function toggleMuteGroup(id) {
		var g = getGlobalGroup(id);
		g.muted = !g.muted;
		return g.muted;
	}

	/**
		Return TRUE if given group is muted
	**/
	public static inline function isMuted(id) {
		return getGlobalGroup(id).muted;
	}


	/** Create a random-picking list from an array of Sounds **/
	public static inline function createRandomList(sounds:Array<Sound>) : RandomSfxList {
		return new RandomSfxList(sounds);
	}
	#end
}




// --- GLOBAL PLAY GROUP ------------------------------------------------------
#if !macro
private class GlobalGroup {
	var id : Int;
	var volume : Float;

	/** Currently associated Heaps SoundGroup **/
	public var soundGroup(default,null) : SoundGroup;

	/** Muted status of this group **/
	public var muted(default,set) : Bool;

	public function new(id:Int) {
		this.id = id;
		volume = 1;
		soundGroup = new hxd.snd.SoundGroup("global"+id);
	}

	/**
		Set the group volume (0-1)
	**/
	public inline function setVolume(v) {
		volume = M.fclamp(v,0,1);
		soundGroup.volume = getVolume();
	}

	/**
		Return current group volume
	**/
	public inline function getVolume() {
		return muted ? 0 : volume;
	}

	function set_muted(v) {
		muted = v;
		if( v )
			soundGroup.volume = 0;
		else
			soundGroup.volume = volume;

		return v;
	}
}
#end



/**
	A small helper class to pick sounds randomly from a list
**/
class RandomSfxList {
	var getters : Array< Void->Sfx >;

	/**
		You can replace this with your own random method
	**/
	public var randomFunc : Int->Int = Std.random;

	/**
		Create a random picking list.

		One array must be provided: either an array of resource Sounds, or an array of paths relative to the "res/" folder (eg. "mySounds/file1.wav", with "mySounds" being in the root of the "res" folder).
	**/
	public function new(?sounds:Array<Sound>, ?resSoundsPaths:Array<String>) {
		if( ( sounds==null || sounds.length==0 ) && ( resSoundsPaths==null || resSoundsPaths.length==0 ) )
			throw "One of the arrays must not be empty";

		if( sounds!=null && sounds.length>0 )
			getters = sounds.map( snd -> function() return new Sfx(snd) );
		else if( resSoundsPaths!=null && resSoundsPaths.length>0 ) {
			getters = resSoundsPaths.map( path -> function() return new Sfx( hxd.Res.load(path).toSound() ) );
		}
	}

	/** Return a random Sfx **/
	public inline function draw() {
		return getters[ randomFunc(getters.length) ]() ;
	}


	/** Return a random Sfx and play it **/
	public inline function drawAndPlay(vol=1.0) {
		var s = draw();
		s.play(vol);
		return s;
	}

	public function getAllSfx() : Array<Sfx> {
		return getters.map( g->g() );
	}
}