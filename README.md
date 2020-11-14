# About

The general purpose personal libs I use in all my Haxe projects.

[![Build Status](https://travis-ci.com/deepnight/deepnightLibs.svg?branch=master)](https://travis-ci.com/deepnight/deepnightLibs)

# Install

## Stable

Use this version if you plan to use the libs for your own projects. 

```bash
haxelib install deepnightLibs
```

## Latest Git version (mostly stable)

Use this version if you're building one of my own projects, such as LDtk or one of my gamejam entry.

```bash
haxelib git deepnightLibs https://github.com/deepnight/deepnightLibs
```

# Usage

In your HXML file, add:
```hxml
-lib deepnightLibs
```

All the libs are in the `dn.*` package.

```haxe
class MyProject {
	public function new() {
		trace( dn.Color.intToHex(0) ); // "#000000"
	}
}
```

# Tips

Use global imports! To import libs in every HX files, just add a ``import.hx`` (this exact name & caps) file to the **root** of your ``src`` folder:

```
dn.*;
dn.Color as C;
```

 - The first line imports all classes in ``dn`` package,

 - The second one imports ``Color`` as an alias "C",

 - Feel free to add your own convenient imports there.

# Noteworthy classes

## dn.M

My re-implementation of the Math class, with high-performances in mind:

```haxe
M.fmin(0.5, 0.9); // 0.5
M.frandRange(0, 2); // random Float number between 0 -> 2
M.randRange(0, 2); // either 0, 1 or 2
M.pow(val, 2); // turns into val*val at compilation time
```

## dn.Color

The color management lib.

It mostly works using ``UInt`` colors (``0xRRGGBB``, like ``0xffcc00``), but contains many useful methods to convert color to various formats (HSL, ARGB, String).

```haxe
dn.Color.intToHex(0); // #000000
dn.Color.toWhite(0xff0000, 0.5); // Interpolates color to white at 50%
dn.Color.getPerceivedLuminosityInt(0x7799ff); // return perceived luminosity (0 to 1.0)
```

## dn.DecisionHelper

A nice tool to easily pick a value among many others using any custom criterion.

```haxe
var arr = [ "a", "foo", "bar", "food", "hello" ];

var dh = new dn.DecisionHelper(arr);

/* Iterates all values in arr and increase their internal score by 1 if they contain the letter "o". */
dh.score( v -> StringTools.contains(v,"o") ? 1 : 0 );

/* Increase score of each values using 10% of their length (ie. longer strings get slightly higher score) */
dh.score( v -> v.length*0.1 );

/* Discard any value containing the letter "h" */
dh.remove( v -> StringTools.contains(v,"h") );

/* Only keep values with length>1 */
dh.keepOnly( v -> v.length>1 );

trace( dh.getBest() ); // -> food
/* Internal scores: a (discarded), foo (1.3), bar (0.3), food (1.4), hello (discarded). */
```
