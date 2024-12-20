package dn.heaps.slib;

import dn.M;

private class AnimInstance {
	public static inline var LOOP_PLAYS = 999999;

	var spr : SpriteInterface;
	public var group : String;
	public var frames : Array<Int> = [];

	public var animCursor = 0;
	public var curFrameCpt = 0.0;
	public var plays = 1;
	public var playDuration = -1.;
	public var paused = false;
	public var isStateAnim = false;
	public var killAfterPlay = false;
	public var stopOnLastFrame = false;
	public var speed = 1.0;
	public var reverse = false;


	public inline function new(s:SpriteInterface, g:String) {
		spr = s;
		group = g;
		if( !spr.lib.exists(group) )
			throw "unknown group "+group;
		frames = spr.lib.getGroup(group).anim;
	}

	public inline function overLastFrame() return animCursor>=frames.length;

	var lastFrame : Int;
	public inline function applyFrame() {
		var f = frames[ reverse ? frames.length-1-animCursor : animCursor ];
		if( spr.anim.onEnterFrame!=null && lastFrame!=f )
			spr.anim.onEnterFrame(f);

		if( spr.groupName!=group )
			spr.set(group, f);
		else if( spr.frame!=f )
			spr.setFrame(f);

		lastFrame = f;
		onEachFrame();
	}

	public inline function loop() {
		plays = LOOP_PLAYS;
	}

	public dynamic function onEnd() {}
	public dynamic function onEachFrame() {}
	public dynamic function onEachLoop() {}
}


private class StateAnim {
	public var group : String;
	public var priority : Float;
	public var cond : Void->Bool;
	public var spd : Float;

	public function new(g:String, ?cb) {
		group = g;
		priority = 0;
		cond = cb;
		spd = 1.0;
	}
}


private class Transition {
	public var from : String;
	public var to : String;
	public var anim : String;
	public var cond : Void->Bool;
	public var spd : Float;
	public var reverse : Bool;

	public function new(f,t,a,cb) {
		from = f;
		to = t;
		anim = a;
		cond = cb;
		spd = 1.0;
		reverse = false;
	}
}


class AnimManager {
	static final ANYTHING = "*";

	var spr : SpriteInterface;

	var overlap : Null<AnimInstance>;
	var stack : Array<AnimInstance> = [];
	var stateAnims : Array<StateAnim> = [];
	var transitions : Array<Transition> = [];
	var stateAnimsActive = true;

	var genSpeed = 1.0;
	var needUpdates = false;
	var destroyed = false;
	var suspended = false;
	var disabledF = 0.;

	public var onEnterFrame : Null<Int->Void>;


	public function new(spr:SpriteInterface) {
		this.spr = spr;
	}

	@:allow(dn.heaps.slib.SpriteLib)
	inline function getCurrentAnim() {
		return stack[0];
	}

	public function getDurationF() {
		return !hasAnim() ? 0 : spr.lib.getAnimDurationF( getCurrentAnim().group ) / genSpeed / getCurrentAnim().speed;
	}

	public function getPlayRatio() : Float { // 0-1
		return isStoppedOnLastFrame() ? 1 : !hasAnim() ? 0 : getCurrentAnim().animCursor / getCurrentAnim().frames.length;
	}

	public function setPlayRatio(r:Float) : AnimManager {
		if( hasAnim() ) {
			getCurrentAnim().animCursor = Std.int( r * (getCurrentAnim().frames.length-1) );
			getCurrentAnim().applyFrame();
		}
		return this;
	}

	public function getDurationS(fps:Float) {
		return getDurationF() / fps;
	}

	inline function getLastAnim() {
		return stack[stack.length-1];
	}

	inline function startUpdates() {
		needUpdates = true;
	}

	inline function stopUpdates() {
		needUpdates = false;
	}

	public function destroy() {
		destroyed = true;
		stopWithoutStateAnims();
		stopUpdates();
		stateAnims = null;
		stack = null;
		spr = null;
	}



	public inline function hasAnim() return !destroyed && stack.length>0;
	public inline function isPlaying(group:String) return hasAnim() && getCurrentAnim().group==group;
	public inline function isAnimFirstFrame() return hasAnim() ? getCurrentAnim().animCursor==0 : false;
	public inline function isAnimLastFrame() return hasAnim() ? getCurrentAnim().animCursor>=getCurrentAnim().frames.length-1 : false;
	public inline function isStoppedOnLastFrame(?id:String) return !hasAnim() && ( id==null || spr.groupName==id ) && spr.frame==spr.totalFrames()-1;
	public inline function getAnimCursor() return hasAnim() ? getCurrentAnim().animCursor : 0;
	public inline function getAnimId() :Null<String> return hasAnim() ? getCurrentAnim().group : null;

	public inline function chain(id:String, plays=1) {
		play(id, plays, true);
		return this;
	}

	public inline function chainCustomSequence(id:String, from:Int, to:Int) {
		playCustomSequence(id, from, to, true);
		return this;
	}

	public inline function chainLoop(id:String) {
		play(id, AnimInstance.LOOP_PLAYS, true);
		return this;
	}

	public inline function chainFor(id:String, durationFrames:Float) {
		play(id, AnimInstance.LOOP_PLAYS, true);
		if( hasAnim() )
			getLastAnim().playDuration = durationFrames;
		return this;
	}

	public inline function playForF(group:String, dframes:Float) {
		if( dframes>0 ) {
			playAndLoop(group);
			if( hasAnim() )
				getLastAnim().playDuration = dframes;
		}
		return this;
	}

	public inline function playAndLoop(k:String) {
		return play(k).loop();
	}

	public function playCustomSequence(group:String, from:Int, to:Int, queueAnim=false) {
		var g = spr.lib.getGroup(group);
		if( g==null ) {
			#if debug
			trace("WARNING: unknown anim "+group);
			#end
			return this;
		}

		if( !queueAnim && hasAnim() )
			stopWithoutStateAnims();

		var a = new AnimInstance(spr,group);
		stack.push(a);
		a.reverse = from>to;
		a.frames = [];
		if( from>to ) {
			var tmp = from;
			from = to;
			to = tmp;
		}
		for(f in from...to+1)
			a.frames.push(f);

		startUpdates();
		if( !queueAnim )
			initCurrentAnim();

		return this;
	}

	public function play(group:String, plays=1, queueAnim=false) : AnimManager {
		var g = spr.lib.getGroup(group);
		if( g==null ) {
			#if debug
			trace("WARNING: unknown anim "+group);
			#end
			return this;
		}

		if( g.anim==null || g.anim.length==0 )
			return this;

		if( !queueAnim && hasAnim() )
			stack = [];

		var a = new AnimInstance(spr,group);
		stack.push(a);
		a.plays = plays;

		startUpdates();
		if( !queueAnim )
			initCurrentAnim();

		return this;
	}

	public function playOverlap(g:String, spd=1.0, loop=false) {
		if( !spr.lib.exists(g) ) {
			#if debug
			trace("WARNING: unknown overlap anim "+g);
			#end
			return;
		}
		clearOverlapAnim();
		overlap = new AnimInstance(spr,g);
		overlap.speed = spd;
		overlap.applyFrame();
		overlap.loop();
		startUpdates();
	}

	public function playConditionalOverlap(g:String, spd=1.0, continueCond:Void->Bool) {
		playOverlap(g, spd, true);
		if( overlap!=null )
			overlap.onEachFrame = ()->{
				if( !continueCond() )
					clearOverlapAnim();
			};
	}

	public function clearOverlapAnim() {
		overlap = null;
	}

	public function hasOverlapAnim() return overlap!=null;


	public function loop() {
		if( hasAnim() )
			getLastAnim().loop();
		return this;
	}

	public function cancelLoop() {
		if( hasAnim() )
			getLastAnim().plays = 0;
		return this;
	}

	public function stopOnLastFrame() {
		if( hasAnim() )
			getLastAnim().stopOnLastFrame = true;
		return this;
	}

	public function reverse() {
		if( hasAnim() ) {
			getLastAnim().reverse = true;
			if( getLastAnim()==getCurrentAnim() )
				getCurrentAnim().applyFrame();
		}
		return this;
	}

	public function killAfterPlay() {
		if( hasAnim() )
			getLastAnim().killAfterPlay = true;
		return this;
	}

	public function onEnd(cb:Void->Void) {
		if( hasAnim() )
			getLastAnim().onEnd = cb;
		return this;
	}

	public function onEachLoop(cb:Void->Void) {
		if( hasAnim() )
			getLastAnim().onEachLoop = cb;
		return this;
	}


	static var UNSYNC : Map<String,Int> = new Map();
	public function unsync() {
		if( !hasAnim() )
			return this;

		var a = getCurrentAnim();
		if( !UNSYNC.exists(a.group) )
			UNSYNC.set(a.group, 1);
		else
			UNSYNC.set(a.group, UNSYNC.get(a.group)+1);

		var offset = M.ceil(a.frames.length/3);
		a.animCursor = ( offset * UNSYNC.get(a.group) + Std.random(100) ) % a.frames.length;
		return this;
	}

	public function pauseCurrentAnim() {
		if( hasAnim() )
			getCurrentAnim().paused = true;
	}

	public function resumeCurrentAnim() {
		if( hasAnim() )
			getCurrentAnim().paused = false;
	}

	public function stopWithStateAnims() {
		stateAnimsActive = true;
		stack = [];
		applyStateAnims();
	}

	public function stopWithoutStateAnims(?k:String, frame=-1) {
		stateAnimsActive = false;
		stack = [];
		if( k!=null )
			spr.set(k, frame!=null ? frame : 0);
		else if( frame>=0 )
			spr.setFrame(frame);
	}


	@:noCompletion @:deprecated("Use enable()") public inline function unsuspend() enable();
	@:noCompletion @:deprecated("Use disable()") public inline function suspend() disable();

	/** Disable all animation playbacks **/
	public function disable() {
		disabledF = 99999999;
	}

	/** Re-enable animations **/
	public function enable() {
		disabledF = 0;
	}

	public inline function setEnabled(v:Bool) {
		if( v )
			enable();
		else
			disable();
	}

	public function disableForF(frames:Int) {
		disabledF = frames + 1;
	}

	public inline function isEnabled() return disabledF<=0;


	public inline function getPlaySpeed() return genSpeed * ( hasAnim() ? getLastAnim().speed : 1.0 );
	public inline function setGlobalSpeed(s:Float) {
		genSpeed = s;
		return this;
	}

	public inline function setSpeed(s:Float) {
		if( hasAnim() )
			getLastAnim().speed = s;
		return this;
	}

	inline function initCurrentAnim() {
		// Transitions
		var t = getTransition( spr.groupName, getCurrentAnim().group );

		if( t!=null && t.anim!=spr.groupName ) {
			if( spr.lib.exists(t.anim) ) {
				var a = new AnimInstance(spr, t.anim);
				stack.insert(0,a);
				a.speed = t.spd;
				a.reverse = t.reverse;
			}
			else {
				#if debug
				trace("WARNING: unknown transition anim "+t.anim);
				#end
			}

		}

		getCurrentAnim().applyFrame();
	}


	public inline function registerTransitions(froms:Array<String>, tos:Array<String>, animId:String, spd=1.0, reverse=false) {
		for(from in froms)
		for(to in tos)
			registerTransition(from, to, animId, spd, reverse);
	}

	function alwaysTrue() return true;

	/**
		Register a transition anim between 2 existing anims. `from` or `to` can be equal to "*", which means "any animation". Example:
		```haxe
		registerTransition("*", "idle", "toIdle"); // means: play "toIdle" before "idle" starts
		```
	**/
	public function registerTransition(from:String, to:String, animId:String, spd=1.0, reverse=false, ?cond:Void->Bool) {
		if( from==ANYTHING && to==ANYTHING )
			throw "* is not allowed for both from and to animations.";

		for(t in transitions)
			if( t.from==from && t.to==to ) {
				t.anim = animId;
				t.spd = spd;
				return;
			}

		var t = new Transition(from,to, animId, cond==null ? alwaysTrue : cond);
		t.spd = spd;
		t.reverse = reverse;
		transitions.push(t);
	}

	function isTransition(anim:String) {
		for(t in transitions)
			if( t.anim==anim )
				return true;
		return false;
	}

	function getTransition(from:String, to:String) : Null<Transition> {
		for(t in transitions)
			if( (t.from==ANYTHING || t.from==from) && (t.to==ANYTHING || t.to==to) && t.cond() )
				return t;

		return null;
	}

	public function appendStateAnim(group:String, spd=1.0, ?condition:Void->Bool) {
		var maxPrio = 0.;
		for(s in stateAnims)
			maxPrio = M.fmax(s.priority, maxPrio);
		registerStateAnim(group, maxPrio+1, spd, condition);
	}

	public function prependStateAnim(group:String, spd=1.0, ?condition:Void->Bool) {
		var minPrio = 0.;
		for(s in stateAnims)
			minPrio = M.fmin(s.priority, minPrio);
		registerStateAnim(group, minPrio-1, spd, condition);
	}

	public function registerStateAnim(group:String, priority:Float, spd=1.0, ?condition:Void->Bool) {
		if( condition==null )
			condition = function() return true;

		removeStateAnim(group, priority);
		var s = new StateAnim(group, condition);
		s.priority = priority;
		s.spd = spd;
		stateAnims.push(s);
		stateAnims.sort( function(a,b) return -Reflect.compare(a.priority, b.priority) );

		stateAnimsActive = true;
		applyStateAnims();
	}

	public function setStateAnimSpeed(group:String, spd:Float) {
		for(s in stateAnims)
			if( s.group==group ) {
				s.spd = spd;
				if( isPlaying(group) )
					getCurrentAnim().speed = spd;
			}
	}

	public function removeStateAnim(group:String, priority:Float) {
		var i = 0;
		while( i<stateAnims.length )
			if( stateAnims[i].group==group && stateAnims[i].priority==priority )
				stateAnims.splice(i,1);
			else
				i++;
	}

	public function removeAllStateAnims() {
		stateAnims = [];
		stopWithoutStateAnims();
	}

	function applyStateAnims() {
		if( !stateAnimsActive )
			return;

		if( hasAnim() && !getCurrentAnim().isStateAnim )
			return;

		for(sa in stateAnims)
			if( sa.cond() ) {
				if( hasAnim() && getCurrentAnim().group==sa.group )
					break;

				playAndLoop(sa.group).setSpeed(sa.spd);
				if( hasAnim() )
					getLastAnim().isStateAnim = true;
				break;
			}
	}

	public function isPlayingStateAnim() : Bool {
		if( !stateAnimsActive || !hasAnim() ) return false;

		var current = getCurrentAnim().group;
		for (a in stateAnims) if (a.group == current)
			return true;

		return false;
	}


	public function toString() {
		return
			"AnimManager("+spr+")" +
			(hasAnim() ? "Playing(stack="+stack.length+")" : "NoAnim");
	}


	public inline function update(dt:Float) {
		if( needUpdates )
			_update(dt);
	}

	function _update(dt:Float) {
		if( SpriteLib.DISABLE_ANIM_UPDATES )
			return;

		if( !isEnabled() ) {
			disabledF-=dt;
			if( disabledF<=0 )
				enable();
			return;
		}

		// State anims
		applyStateAnims();

		// Playback
		var a = getCurrentAnim();
		if( a!=null && !a.paused ) {
			a.curFrameCpt += dt * genSpeed * a.speed;

			// Duration playback
			if( a.playDuration>0 ) {
				a.playDuration-=dt;
				if( a.playDuration<=0 ) {
					a.plays = 0;
					a.animCursor = a.frames.length;
					a.curFrameCpt = 1; // force entering the loop
				}
			}

			while( a.curFrameCpt>1 ) {
				a.curFrameCpt--;
				a.animCursor++;

				// Normal frame
				if( !a.overLastFrame() ) {
					a.applyFrame();
					continue;
				}

				// Anim complete
				a.animCursor = 0;
				a.plays--;

				// Loop
				if( a.plays>0 || a.playDuration>0 ) {
					a.onEachLoop();
					a = getCurrentAnim();
					a.applyFrame();
					continue;
				}

				if( a.stopOnLastFrame )
					stopWithoutStateAnims();

				// No loop
				a.onEnd();

				if( a.killAfterPlay ) {
					spr.remove();
					break;
				}

				// Next anim
				if( hasAnim() ) {
					stack.shift();
					if( stack.length==0 )
						stopWithStateAnims();
					else
						initCurrentAnim();
					a = getCurrentAnim();
				}

				if( !hasAnim() )
					break;
			}
		}

		// Overlap anim
		if( overlap!=null && !spr.destroyed ) {
			overlap.curFrameCpt += dt * genSpeed * overlap.speed;
			while( overlap.curFrameCpt>1 ) {
				overlap.curFrameCpt--;
				overlap.animCursor++;
				if( overlap.overLastFrame() ) {
					overlap = null;
					if( getCurrentAnim()!=null )
						getCurrentAnim().applyFrame();
					break;
				}
			}
			if( overlap!=null )
				overlap.applyFrame();
		}

		// Nothing to do
		if( !destroyed && !hasAnim() && overlap==null )
			stopUpdates();
	}
}