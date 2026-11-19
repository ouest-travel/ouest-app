# Passport model pipeline

The passport book is generated, not hand-modelled, so it can be regenerated
whenever the dimensions or hierarchy change.

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
PKG=Packages/PassportContent
$B --factory-startup -b -P $PKG/Blender/make_passport.py -- \
    $PKG/Sources/PassportContent/PassportContent.rkassets/Models/Passport.usdc
usdzip Ouest/Resources/Models/Passport.usdz \
    $PKG/Sources/PassportContent/PassportContent.rkassets/Models/Passport.usdc
```

- `make_passport.py` builds the covers, page blocks and three turnable sheets
  with neutral materials and planar UVs, and exports Y-up USD.
- `preview.py` renders closed/open check frames with the Workbench engine:
  `$B --factory-startup -b -P preview.py -- <Passport.usdc> <out_dir>`.
- Open `Package.swift` in Reality Composer Pro to inspect the scene. The app
  loads the `.usdz` copy because `.rkassets` only compile for iOS 18+.

Everything per-user (cover colour, title, crest, stamps) is applied at
runtime in `PassportView`, keyed by prim name: `BackCover`, `RightBlock`,
`FrontCoverPivot/FrontCover`, `FrontCoverPivot/LeftBlock`, `Sheet1..3` with
`SheetNFront` / `SheetNBack`.
