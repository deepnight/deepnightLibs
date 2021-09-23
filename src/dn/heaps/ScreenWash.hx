package dn.heaps;

import dn.M;

private enum WashEase {
	Linear;
	EaseBoth;
	EaseIn;
	EaseOut;
}

/**
	"Wash" the whole screen by sliding a texture from one side to the other.
**/
class ScreenWash extends dn.Process {
	var linearRatio = 0.;
	var ratio(get,never) : Float;

	/** Wash angle (radians) **/
	public var ang : Float = 0;

	/** Easing method for the animation: Linear, EaseBoth, EaseIn or EaseOut (default) **/
	public var easing = EaseOut;

	/** Duration of the wash animation in seconds **/
	public var durationS : Float = 0.4;

	var color : Int = 0x0;
	var screenWidth : Int;
	var screenHeight : Int;

	var maskWidth(get,never) : Int;
	var maskHeight(get,never) : Int;

	var wrapper : h2d.Object;
	var tile : h2d.Tile;
	var sb : h2d.SpriteBatch;
	var mask : h2d.Bitmap;

	var invalidated = true;



	/**
		`t` is the Tile to be repeated on the edge of the wash mask. It should be transparent with white pixels.
		`color` (0xrrggbb) is applied to the wash mask and tile
	**/
	public function new(t:h2d.Tile, color:Int, ?displayCtx:h2d.Object, ?p:dn.Process) {
		super(p);

		if( displayCtx!=null )
			createRoot(displayCtx);
		else
			createRootInNoContext();

		wrapper = new h2d.Object(root);

		this.color = color;
		screenWidth = w();
		screenHeight = h();


		mask = new h2d.Bitmap( h2d.Tile.fromColor(color), wrapper );

		tile = t;
		sb = new h2d.SpriteBatch(tile, wrapper);
		sb.color.setColor( dn.Color.addAlphaF(color) );
	}

	/**
		Override screen dimensions
	**/
	public inline function setScreenSize(w,h) {
		screenWidth = w;
		screenHeight = h;
		invalidated = true;
		render();
	}


	override function onDispose() {
		super.onDispose();
		sb.remove();
	}


	inline function get_ratio() {
		return switch easing {
			case Linear:
				linearRatio;

			case EaseBoth:
				M.bezier4(linearRatio, 0,0, 1,1);

			case EaseIn:
				M.bezier3(linearRatio, 0, 0, 1);

			case EaseOut:
				M.bezier3(linearRatio, 0, 1, 1);
		}
	}


	inline function get_maskWidth() {
		return M.ceil(  M.fabs( screenWidth * Math.cos(ang) )  +  M.fabs( screenHeight * Math.sin(ang) )  );
	}

	inline function get_maskHeight() {
		return M.ceil(  M.fabs( screenHeight * Math.cos(ang) )  +  M.fabs( screenWidth * Math.sin(ang) )  );
	}


	function complete() {
		destroy();
		onComplete();
	}
	public dynamic function onComplete() {}


	function render() {
		if( invalidated ) {
			// Redraw tiles
			sb.clear();
			for(i in 0...M.ceil(maskHeight/tile.height)) {
				var be = new h2d.SpriteBatch.BatchElement(tile);
				be.y = i*tile.height;
				sb.add(be);
			}
			invalidated = false;
		}

		root.rotation = ang;
		root.setPosition(screenWidth*0.5, screenHeight*0.5);

		wrapper.setPosition(-maskWidth*0.5, -maskHeight*0.5);

		mask.setPosition(-tile.width*0.5, -tile.height*0.5);
		mask.scaleX = ( maskWidth + tile.width ) * ratio;
		mask.scaleY = ( maskHeight + tile.height );

		sb.x = mask.scaleX - tile.width;
	}


	override function postUpdate() {
		super.postUpdate();
		render();
	}


	override function update() {
		super.update();

		// Progress
		linearRatio += 1/durationS * 1/getDefaultFrameRate() * tmod;
		linearRatio = dn.M.fclamp(linearRatio, 0, 1);
		if( linearRatio>=1 ) {
			render();
			complete();
		}
	}
}