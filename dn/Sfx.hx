package dn;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#else
import dn.DM;
import hxd.snd.*;
import hxd.res.Sound;
//import mt.deepnight.Tweenie;
//import mt.deepnight.Lib;
#end


#if !macro
private class GlobalGroup {
	var id : Int;
	var volume : Float;
	public var group : SoundGroup;
	public var muted(default,set) : Bool;

	public function new(id:Int) {
		this.id = id;
		volume = 1;
		group = new hxd.snd.SoundGroup("global"+id);
	}

	public inline function setVolume(v) {
		volume = DM.fclamp(v,0,1);
		group.volume = getVolume();
	}
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


class Sfx {
	#if !macro
	//static var PLAYING : Array<Sfx> = [];
	//static var MUTED = false;
	//static var DISABLED = false;
	//static var GLOBAL_VOLUME = 1.0;
	//@:noCompletion public static var TW = new Tweenie(30);
	static var GLOBAL_GROUPS : Map<Int, GlobalGroup> = new Map();


	public var channel : Null<Channel>;
	public var sound : Sound;
	public var group(get,never) : Null<SoundGroup>;
	public var volume(default,set) : Float;
	public var groupId : Int;
	//var panning				: Float;
	//var curPlay				: Null<Dynamic>;
	//var muted				: Bool;

	//var onEnd				: Null<Void->Void>;

	//var mp3Fix				: Bool;
	//var vtween				: Null<Tween>;
	//var ptween				: Null<Tween>;
//
	//var spatialX			: Float;
	//var spatialY			: Float;
	//var spatialMaxDist		: Float;
//
	//var beatT				: Float;
	//var beatDuration		: Float;
	//var beatFrame			: Bool;

	//var streaming(get,set) : Bool;
	//inline function get_streaming() return channel==null ? false : channel.streaming;
	//inline function set_streaming(v) return channel==null ? false : channel.streaming = v;

	var duration(get,never) : Float;
	inline function get_duration() return channel==null ? 0 : channel.duration;



	public function new(s:Sound) {
		sound = s;
		volume = 1;
		groupId = 0;
	}

	public function toString() {
		return Std.string(sound);
	}



	inline function get_group() return getGlobalGroup(groupId).group;

	inline function set_volume(v) {
		volume = DM.fclamp(v,0,1);
		if( group!=null )
			group.volume = v;
		return volume;
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



	public function play(?loop=false, ?vol:Float) {
		if( vol!=null )
			volume = vol;
		var c = sound.play(loop, volume, getGlobalGroup(groupId).group);
		c.volume = volume*getGlobalGroup(groupId).getVolume();
		return this;
	}

	public function isPlaying() {
		return @:privateAccess sound.channel!=null;
	}
	public function stop() {
		sound.stop();
	}


	public function playOnGroup(gid:Int, ?loop=false, ?vol:Float) {
		groupId = gid;
		play(loop, vol);
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

	/*
	public inline function getSoundDuration() {
		return sound.length;
	}

	public function playSpatial(x:Float, y:Float, maxDist:Float, ?vol:Float) {
		if ( DEBUG ) trace("playSpatial");
		spatialize(x, y, maxDist);
		return play(vol);
	}

	public function spatialize(x:Float, y:Float, maxDist:Float) {
		spatialized = true;
		spatialX = x;
		spatialY = y;
		spatialMaxDist = maxDist;
		refresh();
		return this;
	}

	public function cancelSpatialization() {
		spatialized = false;
	}

	public function playOnChannel(channelId:Int, ?vol:Float, ?pan:Float) {
		if ( DEBUG ) trace("playOnChannel");
		if( vol==null )
			vol = volume;

		if( pan==null )
			pan = panning;

		channel = channelId;
		var loops = #if (openfl && mobile) 0 #else 1 #end;
		start(loops, vol, pan, 0);
		return this;
	}

	public function playLoopOnChannel(channelId:Int, ?loops = 9999, ?vol:Float, ?pan:Float, ?startOffsetSec = 0.) {
		if ( DEBUG ) trace("playLoopOnChannel");
		if( vol==null )
			vol = volume;

		if( pan==null )
			pan = panning;

		channel = channelId;
		#if (openfl && mobile)
		loops = loops-1;
		#end
		start(loops, vol, pan, startOffsetSec);
		return this;
	}

	public function playLoop(?loops = 9999, ?vol:Float, ?startOffsetSec = 0.) {
		if ( DEBUG ) trace("playLoop");
		if( vol==null )
			vol = volume;
		#if (openfl && mobile)
		loops = loops-1;
		#end
		start(loops, vol, 0, startOffsetSec);
		return this;
	}

	public inline function getChannel() return channel;
	public function setChannel(channelId:Int) {
		channel = channelId;
		refresh();
	}

	function start(loops:Int, vol:Float, pan:Float, startOffset:Float) {
		#if disableSfx
		return;
		#end
		if( DISABLED )
			return;

		if( isPlaying() )
			stop();

		volume = vol;
		panning = pan;
		var st = new SoundTransform( getRealVolume(), getRealPanning() );
		PLAYING.push(this);
		curPlay = sound.play( startOffset, loops, st);
		if( curPlay != null )
			curPlay.addEventListener(flash.events.Event.SOUND_COMPLETE, onComplete);
	}

	public inline function isPlaying() {
		return curPlay!=null;
	}

	public inline function getPlayCursor() {
		return curPlay.position;
	}

	function onComplete(_) {
		stop();
		if( onEnd!=null ) {
			var cb = onEnd;
			onEnd = null;
			cb();
		}
	}

	public inline function getRealVolume() {
		var chan = getChannelInfos(channel);
		var v = volume * GLOBAL_VOLUME * chan.volume * (DISABLED?0:1) * (MUTED?0:1) * (muted?0:1) * (chan.muted?0:1);

		if( spatialized )
			v *= 1 - DM.fmin(1, Lib.distance(spatialX,spatialY, LISTENER_X,LISTENER_Y) / spatialMaxDist );

		return normalizeVolume(v);
	}

	public inline function getTheoricalVolume() {
		return volume;
	}

	public function setVolume(v:Float) {
		volume = v;
		refresh();
	}

	inline function getPanningFromPosition(sourceX:Float, sourceY:Float, listenerX:Float, listenerY:Float) : Float {
		return (listenerX>sourceX?-1:1) * DM.fmin( 0.9, Lib.distanceSqr(listenerX,listenerY, sourceX,sourceY) / SPATIAL_PANNING_RANGE2 );
	}

	public inline function getRealPanning() {
		return normalizePanning( !spatialized ? panning : getPanningFromPosition(spatialX, spatialY, LISTENER_X, LISTENER_Y) );
	}

	public function setPanning(p:Float) {
		panning = p;
		refresh();
	}

	public function removeEndCallback() {
		onEnd = null;
	}

	public function onEndOnce(cb:Void->Void) {
		onEnd = cb;
	}


	public function stop(?fadeOutMs=0.0) {
		if( isPlaying() ) {
			if( fadeOutMs<=0 ) {
				curPlay.stop();
				curPlay = null;
				PLAYING.remove(this);
			}
			else
				fade(0, fadeOutMs).onEnd = stop.bind(0);
		}
	}

	public function toggleMute() {
		muted = !muted;
		setVolume(volume);
	}
	public function mute() {
		muted = true;
		setVolume(volume);
	}
	public function unmute() {
		muted = false;
		setVolume(volume);
	}

	inline function refresh() {
		if( isPlaying() )
			curPlay.soundTransform = new SoundTransform(getRealVolume(), getRealPanning());
	}

	@:noCompletion public function twVolume(?from:Float, to:Float, milliseconds:Float) : Tween {
		if( vtween!=null )
			vtween.endWithoutCallbacks();

		if( from!=null )
			setVolume(from);

		vtween = TW.createMs(volume, to, milliseconds);
		vtween.onUpdate = refresh;
		return vtween;
	}


	@:noCompletion public function twPanning(?from:Float, to:Float, milliseconds:Float) : Tween {
		if( ptween!=null )
			ptween.endWithoutCallbacks();
		if( from!=null )
			panning = from;

		ptween = TW.createMs(panning, to, milliseconds);
		ptween.onUpdate = refresh;
		return ptween;
	}



	static inline function refreshAll() {
		for(s in PLAYING)
			s.refresh();
	}

	public static function toggleMuteGlobal() {
		if( MUTED )
			unmuteGlobal();
		else
			muteGlobal();
	}

	public static function muteGlobal() {
		MUTED = true;
		refreshAll();
	}

	public static function unmuteGlobal() {
		MUTED = false;
		refreshAll();
	}

	public static function setChannelVolume(channel:Int, vol:Float) {
		getChannelInfos(channel).volume = vol;
		refreshAll();
	}

	public static function clearChannel(channel:Int) {
		for( s in getByChannel(channel) )
			s.stop();
	}

	public static function clearChannelWithFadeOut(channel:Int, fadeDuration:Float) {
		for( s in getByChannel(channel) )
			s.fade(0, fadeDuration).onEnd = function() { // TODO
				s.stop();
			}
	}

	public static function getByChannel(channel:Int) {
		return PLAYING.filter( function(s) return s.channel==channel );
	}

	public static function toggleMuteChannel(channel:Int) {
		if( getChannelInfos(channel).muted ) {
			unmuteChannel(channel);
			return true;
		}
		else {
			muteChannel(channel);
			return false;
		}
	}

	public static inline function isChannelMuted(channel:Int) {
		return getChannelInfos(channel).muted;
	}

	public static function muteChannel(channel:Int) {
		getChannelInfos(channel).muted = true;
		refreshAll();
	}

	public static function unmuteChannel(channel:Int) {
		getChannelInfos(channel).muted = false;
		refreshAll();
	}

	public static inline function playOne( randList:Array<?Float->Sfx>, ?volume=1.0) {
		return randList[Std.random(randList.length)]().play(volume);
	}

	public static inline function getOne( randList:Array<?Float->Sfx> ) {
		return randList[Std.random(randList.length)]();
	}

	static inline function normalizeVolume(f:Float) return DM.fclamp(f, 0, 1);
	static inline function normalizePanning(f:Float) return DM.fclamp(f, -1, 1);

	public static inline function getGlobalVolume() {
		return GLOBAL_VOLUME;
	}

	public static function setGlobalVolume(vol:Float) {
		GLOBAL_VOLUME = normalizeVolume(vol);
		refreshAll();
	}

	public static function disable() {
		if( DISABLED )
			return;

		DISABLED = true;
		refreshAll();
	}

	public static function enable() {
		if( !DISABLED )
			return;

		DISABLED = false;
		refreshAll();
	}

	public static function setSpatialSettings(listenerX:Float, listenerY:Float, ?spatialPanningRange:Null<Float>) {
		if( spatialPanningRange!=null )
			SPATIAL_PANNING_RANGE2 = spatialPanningRange*spatialPanningRange;
		LISTENER_X = listenerX;
		LISTENER_Y = listenerY;
		//MAX_SPATIAL_DIST_VOLUME = maxDistForVolume*maxDistForVolume;
		//MAX_SPATIAL_DIST_PANNING = maxDistForPanning*maxDistForPanning;
		refreshAll();
	}

	static inline function getChannelInfos(cid:Int) : ChannelInfos {
		if( CHANNELS.exists(cid) )
			return CHANNELS.get(cid);
		else {
			CHANNELS.set(cid, {volume:1, muted:false});
			return CHANNELS.get(cid);
		}
	}
	#end


	public macro function fade(ethis:Expr, toExpr:ExprOf<Float>, duration_ms:ExprOf<Float>) {
		var p = Context.currentPos();
		var from = macro null;
		var to = toExpr;
		switch( toExpr.expr ) {
			case EBinop(OpGt, e1, e2) :
				from = e1;
				to = e2;

			case EBinop(_), EField(_), EConst(_), EParenthesis(_), ECall(_), EUnop(_), ETernary(_) :

			default:
				Context.error("Invalid tweening expression ("+toExpr.expr.getName()+"). Please ask Seb :)", toExpr.pos);
		}

		return macro $ethis.twVolume( $from, $to, $duration_ms);
	}


	public macro function pan(ethis:Expr, toExpr:ExprOf<Float>, duration_ms:ExprOf<Float>) {
		var p = Context.currentPos();
		var from = macro null;
		var to = toExpr;
		switch( toExpr.expr ) {
			case EBinop(OpGt, e1, e2) :
				from = e1;
				to = e2;

			case EBinop(_), EField(_), EConst(_), EParenthesis(_), ECall(_), EUnop(_), ETernary(_) :

			default:
				Context.error("Invalid tweening expression ("+toExpr.expr.getName()+"). Please ask Seb :)", toExpr.pos);
		}

		return macro $ethis.twPanning( $from, $to, $duration_ms);
	}


	#if !macro

	public static function terminateTweens() {
		TW.completeAll();
	}
	public static function update() {
		TW.update();
	}
	#end
	*/

	#end




	macro public static function importDirectory( dir : String ) {
		var p = Context.currentPos();
		var sounds = [];
		var r_names = ~/[^A-Za-z0-9]+/g;
		var n = 0;
		var paths = Context.getClassPath();
		var custResDir = haxe.macro.Context.definedValue("resourcesPath");
		paths.push( (custResDir==null ? "res" : custResDir)+"/" );

		for( cp in paths ) {
			var path = cp+dir;
			if( !sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path) )
				continue;

			for( fName in sys.FileSystem.readDirectory(path) ) {
				var ext = fName.split(".").pop().toLowerCase();
				if( ext != "wav" && ext != "mp3" && ext != "ogg" ) continue;

				n++;

				var fStr = { expr:EConst(CString(dir+"/"+fName)), pos:p }
				var newSoundExpr = macro hxd.Res.load($fStr).toSound();
				var newSfxExpr = 	macro new mt.deepnight.Sfx($e{newSoundExpr});

				// Create field method
				var tfloat = macro : Null<Float>;
				var f : haxe.macro.Function = {
					ret : null,
					args : [{name:"quickPlayVolume", opt:true, type:tfloat, value:null}],
					expr : macro {
						if( quickPlayVolume!=null ) {
							#if disableSfx
							return $newSfxExpr;
							#else
							var s = $newSfxExpr;
							return s.play(quickPlayVolume);
							#end
						}
						else
							return $newSfxExpr;
					},
					params : [],
				}

				// Add field
				var fieldName = fName.substr(0, fName.length-4); // remove extension
				fieldName = r_names.replace(fieldName,"_"); // cleanup
				var wrapperExpr : Expr = { pos:p, expr:EFunction(fieldName, f) }
				sounds.push({ field:fieldName, expr:wrapperExpr });
			}
			if( n>0 ) break;
		}

		if ( n==0 ) Context.error("Invalid directory (not found or empty): " + dir, p);

		return { pos : p, expr : EObjectDecl(sounds) };
	}

}
