package dn.heaps;

import dn.Color;

class GameFocusHelper extends dn.Process {
    var suspended = false;
    var mask : h2d.Object;
    var font : h2d.Font;
    var scene : h2d.Scene;
    var showIntro = false;

    public function new(s:h2d.Scene, font:h2d.Font) {
        super();

        this.font = font;
        this.scene = s;
        createRoot(scene);
        root.visible = false;

        #if js
        showIntro = true;
        suspendGame();
        #else
        if( !isFocused() )
            suspendGame();
        #end

        // #if js
        // @:privateAccess hxd.snd.NativeChannel.stopInput(null);
        // #end
    }

    var oldSprLibTmod = 1.0;
    function suspendGame() {
        if( suspended )
            return;

        suspended = true;
        oldSprLibTmod = dn.heaps.slib.SpriteLib.TMOD;
        dn.heaps.slib.SpriteLib.TMOD = 0;

        // Pause other process
        for(p in Process.ROOTS)
            if( p!=this )
                p.pause();

        // Create mask
        root.visible = true;
        root.removeChildren();

        var bg = new h2d.Bitmap( h2d.Tile.fromColor(showIntro?0x252e43:0x0, 1, 1, showIntro?1:0.6), root );
        var i = new h2d.Interactive(1,1, root);

        var tf = new h2d.Text(font, root);
        if( showIntro )
            tf.text = "Click anywhere to start";
        else
            tf.text = "PAUSED - click anywhere to resume";

        createChildProcess(
            function(c) {
                // Resize dynamically
                tf.setScale( M.imax(1, Math.floor( w()*0.35 / tf.textWidth )) );
                tf.x = Std.int( w()*0.5 - tf.textWidth*tf.scaleX*0.5 );
                tf.y = Std.int( h()*0.5 - tf.textHeight*tf.scaleY*0.5 );

                i.width = w()+1;
                i.height = h()+1;
                bg.scaleX = w()+1;
                bg.scaleY = w()+1;

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
        dn.heaps.slib.SpriteLib.TMOD = oldSprLibTmod;

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
        #if flash
        return true;
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