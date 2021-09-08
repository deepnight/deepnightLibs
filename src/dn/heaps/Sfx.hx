package dn.heaps;

#if !macro
import dn.M;
import hxd.snd.*;
import hxd.res.Sound;
#end



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


// --- SFX ------------------------------------------------------

class Sfx {
	static var SPATIAL_LISTENER_X = 0.;
	static var SPATIAL_LISTENER_Y = 0.;
	static var SPATIAL_LISTENER_RANGE = 1.;

	macro public static function importDirectory(dir:String) {
		haxe.macro.Context.error("ERROR: use dn.heaps.assets.SfxDirectory.load()", haxe.macro.Context.currentPos());
		return macro null;
	}

	#if !macro
	static var GLOBAL_GROUPS : Map<Int, GlobalGroup> = new Map();
	public static var DEFAULT_GROUP_ID = 0;

	var lastChannel : Null<Channel>;
	public var sound(default,null) : Sound;
	public var defaultGroupId(default,set) : Int;
	public var soundGroup(get,never) : Null<SoundGroup>;

	/**
		Target sound volume. Please note that the actual "final" volume will be a mix of this value, the Group volume and optional spatialization.
	**/
	public var volume(default,set) : Float;
	public var duration(get,never) : Float; inline function get_duration() return lastChannel==null ? 0 : lastChannel.duration;
	var spatialX : Null<Float>;
	var spatialY : Null<Float>;

	/** Multiplier to default spatial max hearing distance **/
	public var spatialRangeMul(default,set) : Float;

	/** This custom ID can be whatever you want. Purely for your own internal usage. **/
	public var customIdentifier : Null<String>;

	/** This callback will be called ONCE when the currently playing sound will stop. **/
	var onEndCurrent : Null< Void->Void >;


	public function new(s:Sound) {
		sound = s;
		volume = 1;
		spatialRangeMul = 1.0;
		defaultGroupId = DEFAULT_GROUP_ID;
	}

	public function toString() {
		return Std.string(sound);
	}



	inline function set_defaultGroupId(v) {
		#if debug
		if( isPlaying() )
			trace("WARNING: changing defaultGroupId of a playing Sfx will not affect it immediately.");
		#end
		return defaultGroupId = v;
	}

	inline function get_soundGroup() return getGlobalGroup(defaultGroupId).soundGroup;

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
		Play sound
	**/
	public function play(?loop=false, ?vol:Float) {
		if( vol!=null )
			volume = vol;
		onStartPlaying( sound.play(loop, volume, getGlobalGroup(defaultGroupId).soundGroup) );
		applyVolume();
		return this;
	}

	/**
		Play sound using spatial localization
	**/
	public function playSpatial(x:Float, y:Float, ?vol:Float) {
		if( vol!=null )
			volume = vol;
		onStartPlaying(  sound.play(false, volume, getGlobalGroup(defaultGroupId).soundGroup) );
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

	function set_spatialRangeMul(v) {
		spatialRangeMul = M.fmax(0,v);
		if( isPlaying() )
			applyVolume();
		return spatialRangeMul;
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
		var spatial = 1.0;
		if( M.isValidNumber(spatialX) && M.isValidNumber(spatialY) ) {
			var dist = Math.sqrt( (spatialX-SPATIAL_LISTENER_X)*(spatialX-SPATIAL_LISTENER_X) + (spatialY-SPATIAL_LISTENER_Y)*(spatialY-SPATIAL_LISTENER_Y) );
			var f = M.fclamp( 1 - dist / ( SPATIAL_LISTENER_RANGE * spatialRangeMul ), 0, 1 );
			spatial = f*f*f;
		}

		return volume * getGlobalGroup(defaultGroupId).getVolume() * spatial;
	}

	/**
		Update internal stuff when the Sound starts playing.
	**/
	inline function onStartPlaying(c:Channel) {
		onEndCurrent = null;
		lastChannel = c;
		lastChannel.onEnd = ()->{
			if( onEndCurrent==null )
				return;

			var cb = onEndCurrent;
			onEndCurrent = null;
			cb();
		}
	}

	/**
		Bind a callback to the end of currently playing sound

		SOUND MUST BE PLAYING.
	**/
	public function onEnd(cb:Void->Void) {
		if( _requiresChannel() )
			onEndCurrent = cb;
	}

	public function removeOnEnd() {
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
		fadeTo(0, duratonS, stop);
	}

	/**
		Fade volume to given level

		SOUND MUST BE PLAYING.
	**/
	public function fadeTo(vol:Float, duratonS=1.0, ?onComplete:Void->Void) {
		if( _requiresChannel() )
			lastChannel.fadeTo(vol, duratonS, onComplete);
	}


	/**
		Play sound on given group
	**/
	public function playOnGroup(gid:Int, ?loop=false, ?vol:Float) {
		defaultGroupId = gid;
		play(loop, vol);
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
	public inline function pitchRandomly(range=0.1) {
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


	public static function createRandomList(sounds:Array<Sound>) : RandomSfxList {
		var rl = new RandomSfxList(sounds);
		return rl;
		// var getters : Array< Void->Sfx > = snds.map( (snd)-> function() {trace(snd); return new Sfx(snd);} );
		// var rl : RandList< Void->Sfx > = new RandList(getters);
		// return rl;
	}
	#end
}


class RandomSfxList {
	var all : Array<Sound>;
	public function new(sounds:Array<Sound>) {
		if( sounds.length==0 )
			throw "Array must not be empty";
		all = sounds;
	}
	public inline function draw() {
		return new Sfx( all[ Std.random(all.length) ] );
	}
	public inline function drawAndPlay(vol=1.0) {
		var s = draw();
		s.play(vol);
		return s;
	}
}