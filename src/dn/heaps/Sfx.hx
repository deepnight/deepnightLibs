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
	public var group(default,null) : SoundGroup;

	/** Muted status of this group **/
	public var muted(default,set) : Bool;

	public function new(id:Int) {
		this.id = id;
		volume = 1;
		group = new hxd.snd.SoundGroup("global"+id);
	}

	/**
		Set the group volume (0-1)
	**/
	public inline function setVolume(v) {
		volume = M.fclamp(v,0,1);
		group.volume = getVolume();
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
			group.volume = 0;
		else
			group.volume = volume;

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

	public var channel : Null<Channel>;
	public var sound : Sound;
	public var group(get,never) : Null<SoundGroup>;
	public var volume(default,set) : Float;
	public var groupId : Int;
	public var duration(get,never) : Float; inline function get_duration() return channel==null ? 0 : channel.duration;

	/** This custom ID can be whatever you want. Purely for your own internal usage. **/
	public var customIdentifier : Null<String>;

	public var onEnd : Null< Void->Void >;


	public function new(s:Sound) {
		sound = s;
		volume = 1;
		groupId = DEFAULT_GROUP_ID;
	}

	public function toString() {
		return Std.string(sound);
	}




	inline function get_group() return getGlobalGroup(groupId).group;

	inline function set_volume(v) {
		volume = M.fclamp(v,0,1);
		if( group!=null )
			group.volume = v;
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
		if( channel!=null )
			channel.pause = true;
	}

	public function resume() {
		if( channel!=null )
			channel.pause = false;
	}

	public inline function isPaused() return channel!=null && channel.pause;

	/**
		Play sound
	**/
	public function play(?loop=false, ?vol:Float) {
		if( vol!=null )
			volume = vol;
		setChannel( sound.play(loop, volume, getGlobalGroup(groupId).group) );
		channel.volume = volume*getGlobalGroup(groupId).getVolume();
		return this;
	}

	public function playSpatial(x:Float, y:Float, ?vol:Float) {
		if( vol!=null )
			volume = vol;
		setChannel(  sound.play(false, volume, getGlobalGroup(groupId).group) );
		setSpatialPos(x,y);
		return this;
	}

	public function setSpatialPos(x:Float, y:Float) {
		if( isPlaying() ) {
			var dist = Math.sqrt( (x-SPATIAL_LISTENER_X)*(x-SPATIAL_LISTENER_X) + (y-SPATIAL_LISTENER_Y)*(y-SPATIAL_LISTENER_Y) );
			var f = M.fclamp( 1-dist/SPATIAL_LISTENER_RANGE, 0, 1 );
			channel.volume = volume*getGlobalGroup(groupId).getVolume() * f*f*f;
		}
		return this;
	}

	/**
		Set channel and bind callbacks
	**/
	inline function setChannel(c:Channel) {
		channel = c;
		channel.onEnd = ()->{
			if( onEnd==null )
				return;

			var cb = onEnd;
			onEnd = null;
			cb();
		}
	}

	public inline function isPlaying() {
		return channel!=null && !isPaused();
	}

	/**
		Stop sound
	**/
	public function stop() {
		sound.stop();
		channel = null;
	}

	/**
		Stop sound with a fade-out
	**/
	public inline function stopWithFadeOut(duratonS:Float) {
		fadeTo(0, duratonS, stop);
	}

	/**
		Fade volume to given level
	**/
	public function fadeTo(vol:Float, duratonS=1.0, ?onComplete:Void->Void) {
		if( isPlaying() )
			channel.fadeTo(vol, duratonS, onComplete);
	}


	/**
		Play sound on given group
	**/
	public function playOnGroup(gid:Int, ?loop=false, ?vol:Float) {
		groupId = gid;
		play(loop, vol);
		return this;
	}


	/** Attach an effect to the currently playing sound **/
	public inline function addEffect(e:Effect) {
		if( isPlaying() )
			channel.addEffect(e);
		return this;
	}

	/**
		Adjust pitch randomly withing +/- `range` (percentage, "0.02" means "+/- 2%")
	**/
	public inline function pitchRandomly(range=0.02) {
		addEffect(  new hxd.snd.effect.Pitch( Lib.rnd(1-M.fabs(range), 1+M.fabs(range)) )  );
		return this;
	}


	public static function muteGroup(id) {
		getGlobalGroup(id).muted = true;
	}

	public static function unmuteGroup(id) {
		getGlobalGroup(id).muted = false;
	}

	public static function toggleMuteGroup(id) {
		var g = getGlobalGroup(id);
		g.muted = !g.muted;
		return g.muted;
	}

	public static inline function isMuted(id) {
		return getGlobalGroup(id).muted;
	}
	#end
}