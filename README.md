# About

The general purpose personal libs I use in all my Haxe projects.

# Install

## Stable

```bash
haxelib install deepnightLibs
```

## Latest Git version (mostly stable)

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

## Use global imports

To import libs in every HX files, just add a "global" ``import.hx`` to the root of our ``src`` folder:

```
dn.*;
dn.Color as C;
```

 - The first line imports all classes in ``dn`` package,

 - The second one import ``Color`` as an alias "C",

 - Feel free to add your own convenient imports there.

# Noteworthy classes

## dn.M

My Math class re-implementation, with high-performances in mind:

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

