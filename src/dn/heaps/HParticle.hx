package dn.heaps;

#if !heaps
#error "heaps is required for HParticle"
#end

import dn.M;
import h2d.Tile;
import h2d.SpriteBatch;
import dn.Lib;
import hxd.impl.AllocPos;

class ParticlePool {
	var all : haxe.ds.Vector<HParticle>;
	var nalloc : Int;
	public var size(get,never) : Int; inline function get_size() return all.length;

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
				if( best==null || @:privateAccess p.stamp<=@:privateAccess best.stamp )
					best = p;

			@:privateAccess best.onKillCallbacks();
			@:privateAccess best.reset(sb, t, x, y);
			#if debug
			best.allocPos = pos;
			#end
			best;
		}
	}

	function free(kp:HParticle) {
		if( all==null )
			return;

		if( nalloc>1 ) {
			var idx = @:privateAccess kp.poolIdx;
			var tmp = all[idx];
			all[idx] = all[nalloc-1];
			@:privateAccess all[idx].poolIdx = idx;
			all[nalloc-1] = tmp;
			nalloc--;
		}
		else {
			nalloc = 0;
		}
	}

	/** Count active particles **/
	public inline function count() return nalloc;


	/** Destroy every active particles **/
	public function clear() {
		// Because new particles might be allocated during onKill() callbacks,
		// it's sometimes necessary to repeat the clear() process multiple times.
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
			var p = all[i];
			p.lifeS = 0;
		}
	}

	public function dispose() {
		for(p in all)
			@:privateAccess p.dispose();
		all = null;
	}

	public function update(tmod:Float, ?updateCb:HParticle->Void) {
		var i = 0;
		while( i < nalloc ){
			var p = all[i];
			@:privateAccess p.updatePart(tmod);
			if( !p.killed ){
				if( updateCb!=null )
					updateCb( p );
				i++;
			}
		}
	}
}


class Emitter {
	public var id : Null<String>;
	public var x : Float;
	public var y : Float;
	public var wid : Float;
	public var hei : Float;
	public var cd : dn.Cooldown;
	public var delayer : dn.Delayer;
	public var activeCond : Null<Void->Bool>;
	public var active(default,set) : Bool;
	public var tmod : Float;
	public var destroyed(default,null) : Bool;
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
		cd.destroy();
		delayer.destroy();
		onDispose();
		activeCond = null;
		cd = null;
	}

	public function update(tmod:Float) {
		if( activeCond!=null )
			active = activeCond();
		if( !active || destroyed )
			return;

		this.tmod = tmod;
		cd.update(tmod);
		delayer.update(tmod);

		if( tickS<=0 || !cd.hasSetS("emitterTick", tickS) )
			onUpdate();

		if( !permanent && !cd.has("emitterLife") )
			dispose();
	}
}




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

	public var lifeS(never,set)	: Float;
	public var lifeF(never,set)	: Float;
	var rLifeF					: Float;
	var maxLifeF				: Float;
	public var remainingLifeS(get,never)	: Float;
	public var curLifeRatio(get,never)		: Float; // 0(start) -> 1(end)

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

	var fromColor : UInt;
	var toColor : UInt;
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
	public function playAnimAndKill(lib:dn.heaps.slib.SpriteLib, k:String, spd=1.0) {
		animLib = lib;
		animId = k;
		animCursor = 0;
		animLoop = false;
		animSpd = spd;
		applyAnimFrame();
	}
	public function playAnimLoop(lib:dn.heaps.slib.SpriteLib, k:String, spd=1.0) {
		animLib = lib;
		animId = k;
		animCursor = 0;
		animLoop = true;
		animSpd = spd;
		applyAnimFrame();
	}
	public function playAnimAndStop(lib:dn.heaps.slib.SpriteLib, k:String, spd=1.0) {
		animLib = lib;
		animId = k;
		animCursor = 0;
		animLoop = false;
		animSpd = spd;
		animStop = true;
		applyAnimFrame();
	}


	public inline function setScale(v:Float) scale = v;
	public inline function setPosition(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}


	@:access(h2d.Tile)
	public function setTile(tile:Tile) {
		this.t.setPosition(tile.x, tile.y);
		this.t.setSize(tile.width, tile.height);
		this.t.dx = tile.dx;
		this.t.dy = tile.dy;
		this.t.switchTexture(tile);
	}

	function reset(sb:Null<SpriteBatch>, ?tile:Tile, x:Float=0., y:Float=0.) {
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
		dx = dy = da = dr = ds = dsX = dsY = 0;
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

		// Callbacks
		onStart = null;
		onKillP = null;
		onKill = null;
		onBounce = null;
		onUpdate = null;
		onFadeOutStart = null;
		onTouchGround = null;
		onLeaveBounds = null;
	}



	public function colorAnimS(from:UInt, to:UInt, t:Float) {
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

	public inline function setCenterRatio(xr:Float, yr:Float) {
		t.setCenterRatio(xr,yr);
		animXr = xr;
		animYr = yr;
	}
	inline function set_frict(v) return frictX = frictY = v;
	inline function get_frict() return ( frictX + frictY ) * 0.5;


	public inline function uncolorize() r = g = b = 1;

	public inline function colorize(c:UInt, ratio=1.0) {
		dn.Color.colorizeBatchElement(this, c, ratio);
	}

	public inline function colorizeRandomDarker(c:UInt, range:Float) {
		colorize( Color.toBlack(c,rnd(0,range)) );
	}

	public inline function colorizeRandomLighter(c:UInt, range:Float) {
		colorize( Color.toWhite(c,rnd(0,range)) );
	}

	public inline function randScale(min:Float, max:Float, sign=false) {
		setScale( rnd(min, max, sign) );
	}

	public inline function colorizeRandom(min:UInt, max:UInt) {
		dn.Color.colorizeBatchElement(this, dn.Color.interpolateInt(min,max,rnd(0,1)), 1);
	}

	public function fade(targetAlpha:Float, fadeInSpd=1.0, fadeOutSpd=1.0) {
		this.alpha = 0;
		maxAlpha = targetAlpha;
		da = targetAlpha*0.1*fadeInSpd;
		fadeOutSpeed = targetAlpha*0.1*fadeOutSpd;
	}

	public function setFadeS(targetAlpha:Float, fadeInDurationS:Float, fadeOutDurationS:Float) {
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

	public function fadeIn(alpha:Float, spd:Float) {
		this.alpha = 0;
		maxAlpha = alpha;
		da = spd;
	}

	public inline function autoRotate(spd=1.0) {
		autoRotateSpeed = spd;
		rotation = getMoveAng();
	}

	function toString() {
		return 'HPart@$x,$y (lifeS=$remainingLifeS)';
	}

	public function clone() : HParticle {
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

	function set_lifeS(v:Float) {
		rLifeF = maxLifeF = M.fmax(fps*v,0);
		return v;
	}

	function set_lifeF(v:Float) {
		rLifeF = maxLifeF = M.fmax(v,0);
		return v;
	}


	public inline function mulLife(f:Float) {
		rLifeF*=f;
	}

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

	public function kill() {
		if( killed )
			return;

		onKillCallbacks();

		alpha = 0;
		lifeS = 0;
		delayS = 0;
		killed = true;
		visible = false;

		@:privateAccess pool.free(this);
	}

	function dispose() {
		remove();
		bounds = null;
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
		return (p==1||v==0||v==1) ? v : Math.pow(v,p);
	}

	inline function updatePart(tmod:Float) {
		if( customTmod!=null )
			tmod = customTmod();
		delayF -= tmod;
		if( delayF<=0 && !killed ) {
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
				// gravité
				dx += gx * tmod;
				dy += gy * tmod;

				// mouvement
				x += dx * tmod;
				y += dy * tmod;

				// friction
				if( frictX==frictY ){
					var frictTmod = optimPow(frictX, tmod);
					dx *= frictTmod;
					dy *= frictTmod;
				}else{
					dx *= optimPow(frictX, tmod);
					dy *= optimPow(frictY, tmod);
				}

				// Ground
				if( groundY!=null && dy>0 && y>=groundY ) {
					dy = -dy*bounceMul;
					y = groundY-1;
					if( onBounce!=null )
						onBounce();
					if( onTouchGround!=null )
						onTouchGround(this);
				}

				if( !killed ) { // can be killed in onBounce
					rotation += dr * tmod;
					dr *= optimPow(drFrict, tmod);
					scaleX += (ds+dsX) * tmod;
					scaleY += (ds+dsY) * tmod;
					var scaleMulTmod = optimPow(scaleMul, tmod);
					scaleX *= scaleMulTmod;
					scaleX *= optimPow(scaleXMul, tmod);
					scaleY *= scaleMulTmod;
					scaleY *= optimPow(scaleYMul, tmod);
					ds     *= optimPow(dsFrict, tmod);
					dsX    *= optimPow(dsFrict, tmod);
					dsY    *= optimPow(dsFrict, tmod);

					if( autoRotateSpeed!=0 )
						rotation += M.radSubstract( getMoveAng(), rotation ) * M.fmin(1,autoRotateSpeed*tmod);

					// Color animation
					if( !Math.isNaN(rColor) ) {
						rColor = M.fclamp(rColor+dColor*tmod, 0, 1);
						colorize( dn.Color.interpolateInt(fromColor, toColor, rColor) );
					}

					// Fade in
					if ( rLifeF > 0 && da != 0 ) {
						alpha += da * tmod;
						if( alpha>maxAlpha ) {
							da = 0;
							alpha = maxAlpha;
						}
					}

					if( onFadeOutStart!=null && rLifeF>0 && rLifeF-tmod<=0 )
						onFadeOutStart(this);
					rLifeF -= tmod;

					// Fade out (life)
					if( rLifeF <= 0 )
						alpha -= fadeOutSpeed * tmod;
					else if( alphaFlicker>0 )
						alpha = M.fclamp( alpha + rnd(0, alphaFlicker, true), 0, maxAlpha );


					if( bounds!=null && !( x>=bounds.xMin && x<bounds.xMax && y>=bounds.yMin && y<bounds.yMax ) ) {
						// Left bounds
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
				}
			}

		}
	}
}

