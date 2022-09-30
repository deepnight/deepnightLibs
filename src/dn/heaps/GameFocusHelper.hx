package dn.heaps;

class GameFocusHelper extends dn.Process {
    var suspended = false;
    var mask : h2d.Object;
    var font : h2d.Font;
    var scene : h2d.Scene;
    var showIntro = false;
    var thumb : h2d.Tile;

    #if js
    var jsFocus = false;
    #end

    public function new(s:h2d.Scene, font:h2d.Font, ?thumb:h2d.Tile) {
        super();

        this.thumb = thumb;
        this.font = font;
        this.scene = s;
        createRoot(scene);
        root.visible = false;

        #if (js && !nodejs)
        showIntro = true;
        suspendGame();
        var doc = js.Browser.document;
        function _checkTouch(ev:js.html.Event) {
            var jsCanvas = @:privateAccess hxd.Window.getInstance().canvas;
            var te : js.html.Element = cast ev.target;
            jsFocus = jsCanvas.isSameNode(te);
        }
        doc.addEventListener("touchstart", _checkTouch);
        doc.addEventListener("click", _checkTouch);
        #else
        if( !isFocused() ) {
            showIntro = true;
            suspendGame();
        }
        #end

        // #if js
        // @:privateAccess hxd.snd.NativeChannel.stopInput(null);
        // #end
    }

    static function isMobile() {
        #if js
            var mobileReg = ~/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/gi;
            return mobileReg.match( js.Browser.navigator.userAgent );
        #else
            return false;
        #end
    }

    public static function isUseful() {
        #if js
        return !isMobile();
        #else
        return switch hxd.System.platform {
            case WebGL: !isMobile();
            case IOS, Android: false;
            case PC: false;
            case Console: false;
            case FlashPlayer: true;
        }
        #end
    }

    function suspendGame() {
        if( suspended )
            return;

        suspended = true;
        dn.heaps.slib.SpriteLib.DISABLE_ANIM_UPDATES = true;

        // Pause other process
        for(p in Process.ROOTS)
            if( p!=this )
                p.pause();

        // Create mask
        root.visible = true;
        root.removeChildren();

        var isThumb = showIntro && thumb!=null;
        var t = showIntro && thumb==null
            ? h2d.Tile.fromColor(0x252e43, 1,1, 1)
            : showIntro && thumb!=null
                ? thumb
                : h2d.Tile.fromColor(0x0, 1,1, 0.6);
        var bg = new h2d.Bitmap(t, root);
        var i = new h2d.Interactive(1,1, root);

        var tf = new h2d.Text(font, root);
        if( showIntro )
            tf.text = "Click anywhere to start";
        else
            tf.text = "PAUSED - click anywhere to resume";

        createChildProcess(
            function(c) {
                // Resize dynamically
                tf.setScale( M.imax(1, Math.floor( w()*0.5 / tf.textWidth )) );
                tf.x = Std.int( w()*0.5 - tf.textWidth*tf.scaleX*0.5 );
                tf.y = Std.int( h()*0.5 - tf.textHeight*tf.scaleY*0.5 );

                i.width = w()+1;
                i.height = h()+1;
                if( isThumb ) {
                    var s = M.fmax( w()/thumb.width, h()/thumb.height );
                    bg.filter = new h2d.filter.Blur(32,1,3);
                    bg.setScale(s);
                    bg.x = w()*0.5 - bg.tile.width*bg.scaleX*0.5;
                    bg.y = h()*0.5 - bg.tile.height*bg.scaleY*0.5;
                }
                else {
                    bg.scaleX = w()+1;
                    bg.scaleY = h()+1;
                }

                // Auto-kill
                if( !suspended )
                    c.destroy();
            }, true
        );

        var loadingMsg = showIntro;
        i.onPush = function(_) {
            if( loadingMsg ) {
                tf.text = "Loading, please wait...";
                tf.x = Std.int( w()*0.5 - tf.textWidth*tf.scaleX*0.5 );
                tf.y = Std.int( h()*0.5 - tf.textHeight*tf.scaleY*0.5 );
                delayer.addS(resumeGame, 1);
            }
            else
                resumeGame();
            i.remove();
        }

        showIntro = false;
    }

    function resumeGame() {
        if( !suspended )
            return;
        dn.heaps.slib.SpriteLib.DISABLE_ANIM_UPDATES = false;

        delayer.addF(function() {
            root.visible = false;
            root.removeChildren();
        }, 1);
        suspended = false;

        for(p in Process.ROOTS)
            if( p!=this )
                p.resume();
    }

    inline function isFocused() {
        #if (flash || nodejs)
        return true;
        #elseif js
        return jsFocus;
        #else
        var w = hxd.Window.getInstance();
        return w.isFocused;
        #end
    }

    override function update() {
        super.update();

        if( suspended )
            scene.over(root);

        if( !cd.hasSetS("check",0.2) ) {
            if( !isFocused() && !suspended )
                suspendGame();
        }
    }
}
