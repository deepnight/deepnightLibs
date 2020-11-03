package dn.legacy;

#if( flash||nme||openfl )
import flash.display.Bitmap;
import flash.display.BitmapData;
#if haxe3
import haxe.ds.StringMap.StringMap;
#end
#end


class Lib {
	#if( flash9 || openfl || sys )
	inline static function _getLocalCookie( cookieName ){
		#if (flash || openfl)
		return flash.net.SharedObject.getLocal( cookieName );
		#elseif sys
		return new LocalCookie( cookieName );
		#end
	}

	public static function getCookie(cookieName:String, varName:String, ?defValue:Dynamic) : Dynamic {
		try {
			var cookie = _getLocalCookie(cookieName);
			return
				if ( Reflect.hasField(cookie.data, varName) )
					Reflect.field(cookie.data, varName);
				else
					defValue;
		}
		catch( e:Dynamic ) {
			return defValue;
		}
	}

	public static function setCookie(cookieName:String, varName:String, value:Dynamic) {
		try {
			var cookie = _getLocalCookie(cookieName);
			Reflect.setField(cookie.data, varName, value);
			cookie.flush();
			return true;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}

	public static function removeCookie(cookieName:String, varName:String) {
		try {
			var cookie = _getLocalCookie(cookieName);
			if( cookie!=null ) {
				Reflect.deleteField(cookie.data, varName);
				cookie.flush();
			}
			return true;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}

	public static function resetCookie(cookieName:String, ?obj:Dynamic) {
		try {
			var cookie = _getLocalCookie(cookieName);
			cookie.clear();
			if (obj!=null)
				for (key in Reflect.fields(obj))
					Reflect.setField(cookie.data, key, Reflect.field(obj, key));
			cookie.flush();
			return true;
		}
		catch( e:Dynamic ) {
			return false;
		}
	}
	#end


	#if (flash || openfl)
	public static inline function constraintBox(o:flash.display.DisplayObject, maxWid, maxHei) {
		var r = M.fmin( M.fmin(1, maxWid/o.width), M.fmin(1, maxHei/o.height) );
		o.scaleX = r;
		o.scaleY = r;
		return r;
	}

	public static inline function isOverlap(a:flash.geom.Rectangle, b:flash.geom.Rectangle) : Bool {
		return
			b.x>=a.x-b.width && b.x<=a.right &&
			b.y>=a.y-b.height && b.y<=a.bottom;
	}
	#end



	#if flash9
	public static inline function isMac() {
		return flash.system.Capabilities.os.indexOf("mac")>=0;
	}

	public static inline function isAndroid() {
		return flash.system.Capabilities.version.indexOf("AND")>=0;
	}

	public static inline function isIos() {
		return flash.system.Capabilities.version.indexOf("IOS")>=0;
	}

	public static inline function isAir() {
		return flash.system.Capabilities.playerType=="Desktop";
	}

	public static function getFlashVersion() { // renvoie Float sous la forme "11.2"
		var ver = flash.system.Capabilities.version.split(" ")[1].split(",");
		return Std.parseFloat(ver[0]+"."+ver[1]);
	}

	public static function atLeastVersion(version:String) { // format : xx.xx.xx.xx ou xx,xx,xx,xx
		var s = StringTools.replace(version, ",", ".");
		var req = s.split(".");
		var fv = flash.system.Capabilities.version;
		var mine = fv.substr(fv.indexOf(" ")+1).split(",");
		for (i in 0...req.length) {
			if (mine[i]==null || req[i]==null)
				break;
			var m = Std.parseInt(mine[i]);
			var r = Std.parseInt(req[i]);
			if ( m>r )	return true;
			if ( m<r )	return false;

		}
		return true;
	}
	#end

	public static function redirectTracesToConsole(?customPrefix = "") {
		#if( ( flash || openfl ) && !sys )
		haxe.Log.trace = function(m, ?pos) {
			try {
				if ( pos != null && pos.customParams == null )
					pos.customParams = ["debug"];

				flash.external.ExternalInterface.call("console.log", pos.fileName + "(" + pos.lineNumber + ") : " + customPrefix + Std.string(m));
			}
			catch (e:Dynamic) {}
		}
		#else
		trace("cannot redirect to console !");
		#end
	}


	#if (flash9 || nme || openfl)
	public static function flatten(o:flash.display.DisplayObject, padding=0.0, copyTransforms=false, ?quality) {
		// Change quality
		var qold = try { flash.Lib.current.stage.quality; } catch(e:Dynamic) { flash.display.StageQuality.MEDIUM; };
		if( quality!=null )
			try {
				flash.Lib.current.stage.quality = quality;
			} catch( e:Dynamic ) {
				throw("Flatten quality error");
			}

		// Cancel transforms to draw into BitmapData
		var b = o.getBounds(o);
		var bmp = new flash.display.Bitmap( new flash.display.BitmapData(M.ceil(b.width+padding*2), M.ceil(b.height+padding*2), true, 0x0) );
		var m = new flash.geom.Matrix();
		m.translate(-b.x, -b.y);
		m.translate(padding, padding);
		bmp.bitmapData.draw(o, m, o.transform.colorTransform);

		// Apply transforms to Bitmap parent
		var m = new flash.geom.Matrix();
		m.translate(b.x, b.y);
		m.translate(-padding, -padding);
		if( copyTransforms ) {
			m.scale(o.scaleX, o.scaleY);
			m.rotate( M.toRad(o.rotation) );
			m.translate(o.x, o.y);
		}
		bmp.transform.matrix = m;

		// Restore quality
		if( quality!=null )
			try {
				flash.Lib.current.stage.quality = qold;
			} catch( e:Dynamic ) {
				throw("Flatten quality error");
			}
		return bmp;
	}


	public static function createTexture(source:flash.display.BitmapData, width:Float, height:Float, autoDisposeSource:Bool) {
		var bd = new BitmapData(M.ceil(width), M.ceil(height), source.transparent, 0x0);
		bd.lock();

		var pt = new flash.geom.Point();
		for(x in 0...M.ceil(width/source.width))
			for(y in 0...M.ceil(height/source.height)) {
				pt.x = x * source.width;
				pt.y = y * source.height;
				bd.copyPixels(source, source.rect, pt, source, true);
			}

		bd.unlock();

		if( autoDisposeSource ) {
			source.dispose();
			source = null;
		}
		return bd;
	}


	public static function scaleBitmap(source:BitmapData, scale:Float, ?q:flash.display.StageQuality, disposeSource:Bool) {
		var bd = new BitmapData( M.round(source.width*scale), M.round(source.height*scale), source.transparent, 0x0 );
		var m = new flash.geom.Matrix();
		m.scale(scale, scale);

		#if (flash11_3 && !openfl)
		if( q!=null )
			bd.drawWithQuality(source, m, false, q);
		else
		#end
			bd.draw(source, m);

		if( disposeSource )
			source.dispose();

		return bd;
	}


	public static function flipBitmap(bd:BitmapData, flipX:Bool, flipY:Bool) {
		var tmp = bd.clone();
		var m = new flash.geom.Matrix();
		if( flipX ) {
			m.scale(-1, 1);
			m.translate(bd.width, 0);
		}
		if( flipY ) {
			m.scale(1, -1);
			m.translate(0, bd.height);
		}
		bd.draw(tmp, m);
		tmp.dispose();
	}
	#end


	public static function makeXmlNode(name:String, ?attributes:Map<String, String>, ?inner:String) {
		if( attributes==null && inner==null )
			return '<$name/>';

		var a = [];
		for(k in attributes.keys())
			a.push( k+"='"+attributes.get(k)+"'" );

		var begin = '<$name ${a.join(" ")}';
		var end = inner!=null ? '>$inner</$name>' : "/>";
		return begin+end;
	}


	#if flash
	public static function loadFile(onComplete:flash.utils.ByteArray->flash.net.FileReference->Void) {
		var file = new flash.net.FileReference();
		file.addEventListener(flash.events.Event.SELECT, function(_) {
			file.load();
		});
		file.addEventListener(flash.events.Event.COMPLETE, function(_) {
			onComplete(file.data, file);
		});
		file.browse();
	}


	public static function saveFile(defaultName:String, data:String, ?onComplete:Void->Void) {
		var file = new flash.net.FileReference();
		file.addEventListener(flash.events.Event.COMPLETE, function(_) if( onComplete!=null ) onComplete() );
		file.save(data, defaultName);
	}
	#end


	#if flash
	static var LAST_COPY_CANCEL : Void->Void = null;
	public static function h2dCopyToClipboard(o:Dynamic) {
		if( LAST_COPY_CANCEL!=null )
			LAST_COPY_CANCEL();

		var s = new flash.display.Sprite();
		flash.Lib.current.addChild(s);
		s.graphics.beginFill(0x0080FF,1);
		s.graphics.drawRect(10,10, 200,50);

		var tf = new flash.text.TextField();
		s.addChild(tf);
		tf.text = "Press C to confirm copy";
		tf.x = tf.y = 10;
		tf.textColor = 0xFFFFFF;
		tf.width = 200;
		tf.selectable = tf.mouseEnabled = false;

		var cancelRef = null;
		function onKeyDown(e:flash.events.KeyboardEvent) {
			if( e.keyCode==flash.ui.Keyboard.C )
				flash.system.System.setClipboard( Std.string(o) );
			cancelRef();
		}

		var t = 0;
		function onEnterFrame(_) {
			if( t>=flash.Lib.current.stage.frameRate*3 )
				cancelRef();
			else
				t++;
		}

		function cancel() {
			flash.Lib.current.stage.removeEventListener( flash.events.KeyboardEvent.KEY_DOWN, onKeyDown );
			flash.Lib.current.stage.removeEventListener( flash.events.Event.ENTER_FRAME, onEnterFrame );
			s.parent.removeChild(s);
			s = null;
			cancelRef = null;
			LAST_COPY_CANCEL = null;
		}
		cancelRef = cancel;
		LAST_COPY_CANCEL = cancel;

		flash.Lib.current.stage.addEventListener( flash.events.Event.ENTER_FRAME, onEnterFrame );
		flash.Lib.current.stage.addEventListener( flash.events.KeyboardEvent.KEY_DOWN, onKeyDown );
	}
	#end

	public static function getUserAgent() : String {
		#if flash
		try{
			var userAgent = flash.external.ExternalInterface.call("window.navigator.userAgent.toString");
			return
				if( userAgent.indexOf("Chrome") != -1 )			"chrome";
				else if( userAgent.indexOf("Safari") != -1 )	"safari";
				else if( userAgent.indexOf("Firefox") != -1 )	"firefox";
				else if( userAgent.indexOf("MSIE") != -1 )		"ie";
				else if( userAgent.indexOf("Opera") != -1 )		"opera";
				else "unknown";
		}
		catch (e:Dynamic) {
			// Could not access ExternalInterface in containing page
			return "unknown";
		}
		#else
		return "unknown";
		#end
	}

}




#if (!(flash||openfl) && sys)
private class LocalCookie {
	public var name : String;
	public var data : Dynamic;

	public function new( name : String ){
		this.name = name;

		var p = path();
		if( sys.FileSystem.exists(p) )
			data = try haxe.Unserializer.run(sys.io.File.getContent(path())) catch( e : Dynamic ) {};
		else
			clear();
	}

	public function flush(){
		var d = Sys.getCwd()+"/_cookies";
		if( !sys.FileSystem.exists(d) )
			sys.FileSystem.createDirectory(d);

		sys.io.File.saveContent(path(), haxe.Serializer.run(data));
	}

	public inline function clear(){
		data = {};
	}

	inline function path(){
		return Sys.getCwd()+"/_cookies/"+name;
	}
}
#end
