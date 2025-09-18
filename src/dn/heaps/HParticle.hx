package dn.heaps;

#if !heaps
#error "heaps is required for HParticle"
#end

import dn.M;
import h2d.Tile;
import h2d.SpriteBatch;
import dn.Lib;
import hxd.impl.AllocPos;
import dn.TinyTween;


class HParticle extends BatchElement {
	public static var DEFAULT_BOUNDS : h2d.col.Bounds = null;

	var pool					: ParticlePool;
	public var poolIdx(default,null)	: Int;
	var stamp					: Float;
	public var dx				: Float;
	public var dy				: Float;
	public var da				: Float; // alpha
	public var ds				: Float; // scale
	public var dsX				: Float; // scale
	public var dsY				: Float; // scale
	public var dsFrict			: Float;
	public var scaleMul			: Float;
	public var scaleXMul		: Float;
	public var scaleYMul		: Float;
	public var dr				: Float;
	public var drFrict			: Float;
	public var frict(get,set)	: Float;
	public var frictX			: Float;
	public var frictY			: Float;
	public var gx				: Float;
	public var gy				: Float;
	public var bounceMul		: Float;
	public var bounds			: Null<h2d.col.Bounds>;
	public var groundY			: Null<Float>;
	public var groupId			: Null<String>;
	public var fadeOutSpeed		: Float;
	public var maxAlpha(default,set): Float;
	public var alphaFlicker		: Float;
	public var customTmod		: Void->Float;

	var scaleX_tween(default,null) : TinyTween;
	var scaleY_tween(default,null) : TinyTween;

	var delayedCb : Null< HParticle->Void >;
	var delayedCbTimeS : Float;


	public var lifeS(never,set)	: Float;
	public var lifeF(never,set)	: Float;
	var rLifeF					: Float;
	var maxLifeF				: Float;
	public var elapsedLifeS(get,never) : Float;
	public var remainingLifeS(get,never) : Float;
	/** From 0 (start) to 1 (death) **/
	public var curLifeRatio(get,never) : Float;

	public var delayS(get, set)		: Float;
	public var delayF(default, set)	: Float;

	public var onStart			: Null<Void->Void>;
	public var onBounce			: Null<Void->Void>;
	public var onTouchGround	: Null<HParticle->Void>;
	public var onUpdate			: Null<HParticle->Void>;
	public var onFadeOutStart	: Null<HParticle->Void>;
	public var onKill : Null<Void->Void>;
	public var onKillP : Null<HParticle->Void>;
	public var onLeaveBounds : Null<HParticle->Void>;

	public var killOnLifeOut	: Bool;
	public var killed			: Bool;

	/** If greater than 0, particle will keep its rotation aligned with movement. 1 means always strictly equal to current direction, below 1 means slower rotation tracking. **/
	public var autoRotateSpeed(default,set) : Float;
		inline function set_autoRotateSpeed(v) return autoRotateSpeed = M.fclamp(v,0,1);

	public var userData : Dynamic;

	var fromColor : Col;
	var toColor : Col;
	var dColor : Float;
	var rColor : Float;

	public var data0 : Float;
	public var data1 : Float;
	public var data2 : Float;
	public var data3 : Float;
	public var data4 : Float;
	public var data5 : Float;
	public var data6 : Float;
	public var data7 : Float;

	var fps : Int;

	#if debug
	@:allow(dn.heaps.ParticlePool)
	var allocPos : AllocPos;
	#end

	private function new(p:ParticlePool, tile:Tile, fps:Int, x:Float=0., y:Float=0.) {
		super(tile);
		this.fps = fps;
		pool = p;
		poolIdx = -1;

		scaleX_tween = new TinyTween(fps);
		scaleY_tween = new TinyTween(fps);

		reset(null, x,y);
	}


	var animLib : Null<dn.heaps.slib.SpriteLib>;
	var animId : Null<String>;
	var animCursor : Float;
	var animXr : Float;
	var animYr : Float;
	var animLoop : Bool;
	var animStop : Bool;
	public var animSpd : Float;
	public inline function playAnimAndKill(lib:dn.heaps.slib.SpriteLib, k:String, spd=1.0) {
		animLib = lib;
		animId = k;
		animCursor = 0;
		animLoop = false;
		animSpd = spd;
		applyAnimFrame();
	}
	public inline function playAnimLoop(lib:dn.heaps.slib.SpriteLib, k:String, spd=1.0) {
		animLib = lib;
		animId = k;
		animCursor = 0;
		animLoop = true;
		animSpd = spd;
		applyAnimFrame();
	}
	public inline function playAnimAndStop(lib:dn.heaps.slib.SpriteLib, k:String, spd=1.0) {
		animLib = lib;
		animId = k;
		animCursor = 0;
		animLoop = false;
		animSpd = spd;
		animStop = true;
		applyAnimFrame();
	}

	public inline function randomizeAnimCursor() {
		animCursor = irnd(0, animLib.getAnim(animId).length-1);
		applyAnimFrame();
	}


	public inline function setScale(v:Float) scale = v;
	public inline function setPosition(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}

	public inline function tweenBothScales(from:Float, to:Float, durationS:Float, interp:TinyTweenInterpolation=Linear) {
		scaleX_tween.start(from, to, durationS, interp);
		scaleX = from;

		scaleY_tween.start(from, to, durationS, interp);
		scaleY = from;
	}

	public inline function tweenScaleX(from:Float, to:Float, durationS:Float, interp:TinyTweenInterpolation=Linear) {
		scaleX_tween.start(from, to, durationS, interp);
		scaleX = from;
	}

	public inline function tweenScaleY(from:Float, to:Float, durationS:Float, interp:TinyTweenInterpolation=Linear) {
		scaleY_tween.start(from, to, durationS, interp);
		scaleY = from;
	}

	public inline function squashX(s:Float, durationS=0.06) {
		scaleX_tween.start(scaleX*s, scaleX, durationS, Linear);
		scaleY_tween.start(scaleX*(2-s), scaleY, durationS, Linear);
	}

	public inline function squashY(s:Float, durationS=0.06) {
		scaleX_tween.start(scaleX*(2-s), scaleX, durationS, Linear);
		scaleY_tween.start(scaleY*s, scaleY, durationS, Linear);
	}

	@:deprecated("Use resizeTo (note: second arg is now optional)") @:noCompletion
	public inline function scaleTo(w:Float, h:Float) resizeTo(w,h);
	public inline function resizeTo(w:Float, h=-1.) {
		resizeXTo(w);
		resizeYTo(h>=0 ? h : w);
	}

	@:deprecated("Use resizeXTo") @:noCompletion
	public inline function scaleXTo(len:Float) resizeXTo(len);
	public inline function resizeXTo(len:Float) {
		scaleX = len/t.width;
	}

	@:deprecated("Use resizeYTo") @:noCompletion
	public inline function scaleYTo(len:Float) resizeYTo(len);
	public inline function resizeYTo(len:Float) {
		scaleY = len/t.height;
	}


	@:access(h2d.Tile)
	public inline function setTile(tile:Tile) {
		this.t.setPosition(tile.x, tile.y);
		this.t.setSize(tile.width, tile.height);
		this.t.dx = tile.dx;
		this.t.dy = tile.dy;
		this.t.switchTexture(tile);
	}

	public inline function mulRGB(v:Float) {
		r*=v;
		g*=v;
		b*=v;
	}

	public inline function isSet0() return !Math.isNaN(data0);
	public inline function isSet1() return !Math.isNaN(data1);
	public inline function isSet2() return !Math.isNaN(data2);
	public inline function isSet3() return !Math.isNaN(data3);
	public inline function isSet4() return !Math.isNaN(data4);
	public inline function isSet5() return !Math.isNaN(data5);
	public inline function isSet6() return !Math.isNaN(data6);
	public inline function isSet7() return !Math.isNaN(data7);

	public inline function initIfNull0(v:Float) if( Math.isNaN(data0) ) data0 = v;
	public inline function initIfNull1(v:Float) if( Math.isNaN(data1) ) data1 = v;
	public inline function initIfNull2(v:Float) if( Math.isNaN(data2) ) data2 = v;
	public inline function initIfNull3(v:Float) if( Math.isNaN(data3) ) data3 = v;
	public inline function initIfNull4(v:Float) if( Math.isNaN(data4) ) data4 = v;
	public inline function initIfNull5(v:Float) if( Math.isNaN(data5) ) data5 = v;
	public inline function initIfNull6(v:Float) if( Math.isNaN(data6) ) data6 = v;
	public inline function initIfNull7(v:Float) if( Math.isNaN(data7) ) data7 = v;

	public inline function inc0() return Math.isNaN(data0) ? data0=1 : ++data0;
	public inline function inc1() return Math.isNaN(data1) ? data1=1 : ++data1;
	public inline function inc2() return Math.isNaN(data2) ? data2=1 : ++data2;
	public inline function inc3() return Math.isNaN(data3) ? data3=1 : ++data3;
	public inline function inc4() return Math.isNaN(data4) ? data4=1 : ++data4;
	public inline function inc5() return Math.isNaN(data5) ? data5=1 : ++data5;
	public inline function inc6() return Math.isNaN(data6) ? data6=1 : ++data6;
	public inline function inc7() return Math.isNaN(data7) ? data7=1 : ++data7;

	inline function reset(sb:Null<SpriteBatch>, ?tile:Tile, x:Float=0., y:Float=0.) {
		if( tile!=null )
			setTile(tile);

		if( batch!=sb ) {
			if( batch!=null )
				remove();
			if( sb!=null )
				sb.add(this);
		}

		// Batch-element base fields
		setPosition(x,y);
		scaleX = 1;
		scaleY = 1;
		rotation = 0;
		r = g = b = a = 1;
		alpha = 1;
		visible = true;

		// Hparticle fields
		data0 = data1 = data2 = data3 = data4 = data5 = data6 = data7 = Math.NaN;
		customTmod = null;
		animId = null;
		animLib = null;
		scaleMul = 1;
		scaleXMul = scaleYMul = 1;
		dsFrict = 1;
		alphaFlicker = 0;
		fromColor = 0x0;
		dColor = rColor = Math.NaN;

		stamp = haxe.Timer.stamp();
		setCenterRatio(0.5, 0.5);
		killed = false;
		maxAlpha = 1;
		dx = dy = 0;
		da = 0;
		dr = 0;
		ds = dsX = dsY = 0;
		gx = gy = 0;
		frictX = frictY = 1;
		drFrict = 1;
		fadeOutSpeed = 0.1;
		bounceMul = 0.85;
		delayS = 0;
		lifeS = 1;
		bounds = DEFAULT_BOUNDS;
		killOnLifeOut = false;
		groundY = null;
		groupId = null;
		autoRotateSpeed = 0;
		delayedCbTimeS = 0;

		// Tweens
		scaleX_tween.reset();
		scaleY_tween.reset();

		// Callbacks
		onStart = null;
		onKillP = null;
		onKill = null;
		onBounce = null;
		onUpdate = null;
		onFadeOutStart = null;
		onTouchGround = null;
		onLeaveBounds = null;
		delayedCb = null;
	}



	public inline function colorAnimS(from:Col, to:Col, t:Float) {
		fromColor = from;
		toColor = to;
		dColor = 1/(t*fps);
		rColor = 0;
	}


	public inline function rnd(min,max,?sign) return Lib.rnd(min,max,sign);
	public inline function irnd(min,max,?sign) return Lib.irnd(min,max,sign);

	inline function set_maxAlpha(v) {
		if( alpha>v )
			alpha = v;
		maxAlpha = v;
		return v;
	}

	/**
		Set pivot ratios. If `pixelPerfect` is true (default), then pivots will snap to closest pixel.
	**/
	public inline function setCenterRatio(xr:Float, yr:Float, pixelPerfect=false) {
		if( pixelPerfect ) {
			xr = M.round(t.width*xr) / t.width;
			yr = M.round(t.height*yr) / t.height;
		}
		t.setCenterRatio(xr,yr);
		animXr = xr;
		animYr = yr;
	}
	inline function set_frict(v) return frictX = frictY = v;
	inline function get_frict() return ( frictX + frictY ) * 0.5;


	public inline function uncolorize() r = g = b = 1;

	public inline function colorize(c:Col, ratio=1.0) {
		c.colorizeH2dBatchElement(this, ratio);
	}

	public inline function colorizeRandomDarker(c:Col, range:Float) {
		colorize( c.toBlack( rnd(0,range) ) );
	}

	public inline function colorizeRandomLighter(c:Col, range:Float) {
		colorize( c.toWhite( rnd(0,range) ) );
	}

	public inline function randScale(min:Float, max:Float, sign=false) {
		setScale( rnd(min, max, sign) );
	}

	public inline function colorizeRandom(min:Col, max:Col) {
		min.interpolate( max, rnd(0,1) ).colorizeH2dBatchElement(this, 1);
	}


	public inline function randFlipXY() {
		scaleX *= RandomTools.sign();
		scaleY *= RandomTools.sign();
	}
	public inline function randFlipX() scaleX *= RandomTools.sign();
	public inline function randFlipY() scaleY *= RandomTools.sign();
	public inline function randRotation() rotation = RandomTools.fullCircle();
	public inline function randRotationAndFlips() {
		randFlipXY();
		randRotation();
	}

	public inline function delayCallback(cb:HParticle->Void, sec:Float) {
		delayedCb = cb;
		delayedCbTimeS = sec;
	}

	public inline function fade(targetAlpha:Float, fadeInSpd=1.0, fadeOutSpd=1.0) {
		this.alpha = 0;
		maxAlpha = targetAlpha;
		da = targetAlpha*0.1*fadeInSpd;
		fadeOutSpeed = targetAlpha*0.1*fadeOutSpd;
	}

	public inline function setFadeS(targetAlpha:Float, fadeInDurationS:Float, fadeOutDurationS:Float) : Void {
		this.alpha = 0;
		maxAlpha = targetAlpha;
		if( fadeInDurationS<=0 )
			alpha = maxAlpha;
		else
			da = targetAlpha / (fadeInDurationS*fps);
		if( fadeOutDurationS<=0 )
			fadeOutSpeed = 99;
		else
			fadeOutSpeed = targetAlpha / (fadeOutDurationS*fps);
	}

	public inline function fadeIn(alpha:Float, spd:Float) {
		this.alpha = 0;
		maxAlpha = alpha;
		da = spd;
	}

	public inline function autoRotate(spd=1.0) {
		autoRotateSpeed = spd;
		rotation = getMoveAng();
	}

	public inline function disableAutoRotate() {
		autoRotateSpeed = 0;
	}

	@:keep
	public function toString() {
		return 'HPart@$x,$y (lifeS=$remainingLifeS)';
	}

	public inline function clone() : HParticle {
		var s = new haxe.Serializer();
		s.useCache = true;
		s.serialize(this);
		return haxe.Unserializer.run( s.toString() );
	}

	inline function set_delayS(d:Float):Float {
		delayF = d*fps;
		return d;
	}
	inline function get_delayS() return delayF/fps;

	inline function set_delayF(d:Float):Float {
		d = M.fmax(0,d);
		visible = !killed && d <= 0;
		return delayF = d;
	}

	inline function set_lifeS(v:Float) {
		rLifeF = maxLifeF = M.fmax(fps*v,0);
		return v;
	}

	inline function set_lifeF(v:Float) {
		rLifeF = maxLifeF = M.fmax(v,0);
		return v;
	}


	public inline function mulLife(f:Float) {
		rLifeF*=f;
	}

	inline function get_elapsedLifeS() return (maxLifeF-rLifeF)/fps;
	inline function get_remainingLifeS() return rLifeF/fps;
	inline function get_curLifeRatio() return 1-rLifeF/maxLifeF; // 0(start) -> 1(end)

	inline function onKillCallbacks() {
		var any = false;
		if( onKillP!=null ) {
			var cb = onKillP;
			onKillP = null;
			cb(this);
			any = true;
		}
		if( onKill!=null ) {
			var cb = onKill;
			onKill = null;
			cb();
			any = true;
		}
		return any;
	}

	/** Remove particle immediately without fading out **/
	public inline function kill() {
		if( !killed ) {
			onKillCallbacks();

			alpha = 0;
			lifeS = 0;
			delayS = 0;
			killed = true;
			visible = false;

			@:privateAccess pool.free(this);
		}
	}

	public inline function fadeOutAndKill(fadeOutDurationS:Float) {
		if( fadeOutDurationS<=0 )
			kill();
		else {
			lifeS = 0;
			fadeOutSpeed = M.fmax( alpha / (fadeOutDurationS*fps), fadeOutSpeed );
		}
	}

	/** Lower life to 0 and start fading out **/
	public inline function timeoutNow() {
		rLifeF = 0;
	}

	function dispose() {
		reset(null);

		pool = null;
		bounds = null;
		scaleX_tween = null;
		scaleY_tween = null;
	}

	public inline function isAlive() {
		return rLifeF>0;
	}

	public inline function getSpeed() {
		return Math.sqrt( dx*dx + dy*dy );
	}

	public inline function sign() {
		return Std.random(2)*2-1;
	}

	public inline function randFloat(f:Float) {
		return Std.random( Std.int(f*10000) ) / 10000;
	}

	public inline function setGravityAng(a:Float, spd:Float) {
		gx = Math.cos(a)*spd;
		gy = Math.sin(a)*spd;
	}


	public inline function cancelVelocities() {
		dx = dy = gx = gy = 0;
	}

	public inline function moveAng(a:Float, spd:Float) {
		dx = Math.cos(a)*spd;
		dy = Math.sin(a)*spd;
	}

	public inline function moveTo(x:Float,y:Float, spd:Float) {
		var a = Math.atan2(y-this.y, x-this.x);
		dx = Math.cos(a)*spd;
		dy = Math.sin(a)*spd;
	}

	public inline function moveAwayFrom(x:Float,y:Float, spd:Float) {
		var a = Math.atan2(y-this.y, x-this.x);
		dx = -Math.cos(a)*spd;
		dy = -Math.sin(a)*spd;
	}

	public inline function getMoveAng() {
		return Math.atan2(dy,dx);
	}

	public inline function stretchTo(tx:Float, ty:Float) {
		scaleX = M.dist(x,y, tx,ty) / t.width;
		rotation = Math.atan2(ty-y, tx-x);
	}


	inline function applyAnimFrame() {
		var f = animLib.getAnim(animId)[Std.int(animCursor)];
		var fd = animLib.getFrameData(animId, f);
		var tile = animLib.getTile( animId, f );
		t.setPosition(tile.x, tile.y);
		t.setSize(tile.width, tile.height);
		t.dx = -Std.int(fd.realWid * animXr + fd.realX);
		t.dy = -Std.int(fd.realHei * animYr + fd.realY);
	}

	public inline function optimPow(v:Float, p:Float) {
		return ( p==1 || v==0 || v==1 ) ? v : Math.pow(v,p);
	}

	inline function updatePart(tmod:Float) {
		if( customTmod!=null )
			tmod = customTmod();
		delayF -= tmod;

		if( delayF<=0 && !killed ) {
			// Start callback
			if( onStart!=null ) {
				var cb = onStart;
				onStart = null;
				cb();
			}

			// Anim
			if( animId!=null ) {
				applyAnimFrame();
				animCursor+=animSpd*tmod;
				if( animCursor>=animLib.getAnim(animId).length ) {
					if( animLoop )
						animCursor-=animLib.getAnim(animId).length;
					else if (animStop) {
						animId = null;
						animLib = null;
					} else {
						animId = null;
						animLib = null;
						animCursor = 0;
						kill();
					}
				}
			}

			if( !killed ) {
				// Gravity
				dx += gx * tmod;
				dy += gy * tmod;

				// Velocities
				x += dx * tmod;
				y += dy * tmod;

				// Frictions
				if( frictX==frictY ){
					var frictTmod = optimPow(frictX, tmod);
					dx *= frictTmod;
					dy *= frictTmod;
				}
				else {
					dx *= optimPow(frictX, tmod);
					dy *= optimPow(frictY, tmod);
				}

				// Ground
				if( groundY!=null && dy>0 && y>=groundY ) {
					if( bounceMul==0 )
						gy = 0;
					dy = -dy*bounceMul;
					y = groundY-1;
					if( onBounce!=null )
						onBounce();
					if( onTouchGround!=null )
						onTouchGround(this);
				}

				if( !killed ) { // Could have been killed in onBounce
					rotation += dr * tmod;
					dr *= optimPow(drFrict, tmod);

					var scaleMulTmod = optimPow(scaleMul, tmod);

					// X scale
					if( scaleX_tween.isCurrentlyRunning() ) {
						scaleX_tween.update(tmod);
						scaleX = scaleX_tween.curValue;
					}
					else {
						scaleX += (ds+dsX) * tmod;
						scaleX *= scaleMulTmod;
						scaleX *= optimPow(scaleXMul, tmod);
					}

					// Y scale
					if( scaleY_tween.isCurrentlyRunning() ) {
						scaleY_tween.update(tmod);
						scaleY = scaleY_tween.curValue;
					}
					else {
						scaleY += (ds+dsY) * tmod;
						scaleY *= scaleMulTmod;
						scaleY *= optimPow(scaleYMul, tmod);
					}

					ds     *= optimPow(dsFrict, tmod);
					dsX    *= optimPow(dsFrict, tmod);
					dsY    *= optimPow(dsFrict, tmod);


					if( autoRotateSpeed!=0 )
						rotation += M.radSubstract( getMoveAng(), rotation ) * M.fmin(1,autoRotateSpeed*tmod);

					// Color animation
					if( !Math.isNaN(rColor) ) {
						rColor = M.fclamp(rColor+dColor*tmod, 0, 1);
						colorize( fromColor.interpolate(toColor, rColor) );
					}

					// Fade in
					if ( rLifeF > 0 && da != 0 ) {
						alpha += da * tmod;
						if( alpha>maxAlpha ) {
							da = 0;
							alpha = maxAlpha;
						}
					}

					// Fade out start callback
					if( onFadeOutStart!=null && rLifeF>0 && rLifeF-tmod<=0 )
						onFadeOutStart(this);

					rLifeF -= tmod;

					// Fade out (life)
					if( rLifeF <= 0 )
						alpha -= fadeOutSpeed * tmod;
					else if( alphaFlicker>0 )
						alpha = M.fclamp( alpha + rnd(0, alphaFlicker, true), 0, maxAlpha );


					// Check bounds
					if( bounds!=null && !( x>=bounds.xMin && x<bounds.xMax && y>=bounds.yMin && y<bounds.yMax ) ) {
						if( onLeaveBounds!=null )
							onLeaveBounds(this);
						kill();
					}
					else if( rLifeF<=0 && ( alpha<=0 || killOnLifeOut ) ) {
						// Timed out
						kill();
					}
					else if( onUpdate!=null ) {
						// Update CB
						onUpdate(this);
					}

					// Delayed callback
					if( !killed && delayedCb!=null && elapsedLifeS>=delayedCbTimeS ) {
						var cb = delayedCb;
						delayedCb = null;
						delayedCbTimeS = 0;
						cb(this);
					}
				}
			}

		}
	}
}



/************************************************************
	Particle Pool manager
************************************************************/

class ParticlePool {
	var all : haxe.ds.Vector<HParticle>;
	var nalloc : Int;

	public var size(get,never) : Int;
		inline function get_size() return all.length;

	public var allocated(get,never) : Int;
		inline function get_allocated() return nalloc;

	public function new(tile:h2d.Tile, count:Int, fps:Int) {
		all = new haxe.ds.Vector(count);
		nalloc = 0;

		for(i in 0...count) {
			var p = @:privateAccess new HParticle(this, tile.clone(), fps);
			all[i] = p;
			p.kill();
		}
	}

	public inline function alloc(sb:SpriteBatch, t:h2d.Tile, x:Float, y:Float, ?pos: AllocPos) : HParticle {
		return if( nalloc<all.length ) {
			// Use a killed part
			var p = all[nalloc];
			@:privateAccess p.reset(sb, t, x,y);
			@:privateAccess p.poolIdx = nalloc;
			nalloc++;
			#if debug
			p.allocPos = pos;
			#end
			p;
		}
		else {
			// Find oldest active part
			var best : HParticle = null;
			for(p in all)
				if( best==null || @:privateAccess p.stamp<=@:privateAccess best.stamp ) // TODO optimize that
					best = p;

			@:privateAccess best.onKillCallbacks();
			@:privateAccess best.reset(sb, t, x, y);
			#if debug
			best.allocPos = pos;
			#end
			best;
		}
	}

	/** Direct access to a HParticle by its index **/
	public inline function get(idx:Int) return idx>=0 && idx<nalloc ? all[idx] : null;

	/**
		When a particle is killed, pick last allocated one and move it here. This prevents "gaps" in the pool.
	**/
	inline function free(kp:HParticle) {
		if( all!=null ) {
			if( nalloc>1 ) {
				var idx = @:privateAccess kp.poolIdx;
				var tmp = all[idx];
				all[idx] = all[nalloc-1];
				@:privateAccess all[idx].poolIdx = idx;
				all[nalloc-1] = tmp;
				nalloc--;
			}
			else
				nalloc = 0;
		}
	}

	/** Count active particles **/
	@:noCompletion @:deprecated("Use `allocated` var")
	public inline function count() return nalloc;


	/** Destroy every active particles **/
	public function clear() {
		// Because new particles might be allocated during onKill() callbacks,
		// it's sometimes necessary to repeat the clearing loop multiple times.
		var repeat = false;
		var maxRepeats = 10;
		var p : HParticle = null;
		do {
			repeat = false;

			for(i in 0...size) {
				p = all[i];
				if( @:privateAccess p.onKillCallbacks() )
					repeat = true;
				@:privateAccess p.reset(null);
				p.visible = false;
			}

			if( repeat && maxRepeats--<=0 )
				throw("Infinite loop during clear: an onKill() callback is repeatingly allocating new particles.");
		} while( repeat );
	}


	@:noCompletion @:deprecated("Use clear()")
	public inline function killAll() clear();

	public inline function killAllWithFade() {
		for( i in 0...nalloc) {
			all[i].lifeS = 0;
			all[i].fadeOutSpeed = M.fmax(all[i].fadeOutSpeed, 0.03);
		}
	}

	public function dispose() {
		for(p in all)
			@:privateAccess p.dispose();
		all = null;
	}

	public inline function getAllocatedRatio() return allocated/size;

	public inline function update(tmod:Float, ?updateCb:HParticle->Void) {
		var i = 0;
		var p : HParticle;
		while( i < nalloc ) {
			p = all[i];
			@:privateAccess p.updatePart(tmod);
			if( !p.killed ) {
				if( updateCb!=null )
					updateCb( p );
				i++;
			}
		}
	}
}


/************************************************************
	Particle auto emitter
************************************************************/

class Emitter {
	public var id : Null<String>;
	public var x : Float;
	public var y : Float;
	public var wid : Float;
	public var hei : Float;
	public var cd : dn.Cooldown;
	public var delayer : dn.Delayer;

	/** If this method is set, it should return TRUE to enable the emitter or FALSE to disable it. **/
	public var activeCond : Null<Void->Bool>;

	/** Active state of the emitter **/
	public var active(default,set) : Bool;
	public var tmod : Float;
	public var destroyed(default,null) : Bool;

	/** Frequency (in seconds) of the `onUpdate` calls **/
	public var tickS : Float;

	public var padding : Int;

	public var top(get,never) : Float;  inline function get_top() return y;
	public var bottom(get,never) : Float;  inline function get_bottom() return y+hei-1;
	public var left(get,never) : Float;  inline function get_left() return x;
	public var right(get,never) : Float;  inline function get_right() return x+wid-1;
	var permanent = true;

	public function new(?id:String, fps:Int) {
		tickS = 0;
		this.id = id;
		destroyed = false;
		x = y = 0;
		wid = hei = 0;
		padding = 0;
		active = true;

		delayer = new Delayer(fps);
		cd = new Cooldown(fps);
	}

	public inline function setPosition(x,y, ?w, ?h) {
		this.x = x;
		this.y = y;
		if( w!=null ) wid = w;
		if( h!=null ) hei = h;
		if( h==null && w!=null ) hei = w;
	}

	public inline function setSize(w, h) {
		wid = w;
		hei = h;
	}

	public inline function setDurationS(t:Float) {
		cd.setS("emitterLife", t);
		permanent = false;
	}

	public dynamic function onActivate() {}
	public dynamic function onDeactivate() {}
	public dynamic function onUpdate() {}
	public dynamic function onDispose() {}

	inline function set_active(v:Bool) {
		if( v==active || destroyed )
			return active;

		active = v;
		if( active )
			onActivate();
		else
			onDeactivate();
		return active;
	}

	public function dispose() {
		if( destroyed )
			return;

		destroyed = true;
		cd.dispose();
		delayer.dispose();
		onDispose();
		activeCond = null;
		cd = null;
	}

	public inline function update(tmod:Float) {
		if( activeCond!=null )
			active = activeCond();

		if( active && !destroyed ) {
			this.tmod = tmod;
			cd.update(tmod);
			delayer.update(tmod);

			if( tickS<=0 || !cd.has("emitterTick") ) {
				onUpdate();
				cd.setS("emitterTick", tickS);
			}

			if( !permanent && !cd.has("emitterLife") )
				dispose();
		}

	}
}

