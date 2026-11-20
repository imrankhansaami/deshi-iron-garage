$dir = "C:\Users\imran\Documents\computer graphics\DESHI IRON GARAGE\scripts\procedural"
# Only the decals that lie on a HORIZONTAL surface move to disc_flat(); gauge
# faces, lamp lenses and axle flanges keep the edge-on disc.
$map = @{
	"props_mech.gd"  = @('"OilStain"')
	"props_elec.gd"  = @('"Paste"')
	"props_daily.gd" = @('"Foam"', '"TeaRing"')
	"props_proto.gd" = @('"GlassTop"', '"EmitterPlate"')
	"garage_structure.gd" = @()
}
foreach ($file in $map.Keys) {
	$path = Join-Path $dir $file
	if (-not (Test-Path $path)) { $path = Join-Path (Split-Path $dir -Parent) "garage\$file" }
	if (-not (Test-Path $path)) { Write-Output ("missing {0}" -f $file); continue }
	$text = [System.IO.File]::ReadAllText($path)
	$count = 0
	foreach ($name in $map[$file]) {
		$pattern = 'ShapeKit\.disc\(([^;]*?),\s*' + [regex]::Escape($name) + ')'
		$replacement = 'ShapeKit.disc_flat($1, ' + $name + ')'
		$new = [regex]::Replace($text, $pattern, $replacement)
		if ($new -ne $text) { $count++; $text = $new }
	}
	if ($count -gt 0) {
		[System.IO.File]::WriteAllText($path, $text)
		Write-Output ("{0}: patched {1} call sites" -f $file, $count)
	} else {
		Write-Output ("{0}: no change" -f $file)
	}
}
# puddles and the emitter lens live in the structure and proto passes
$extra = @(
	@{ f = "$dir\..\garage\garage_structure.gd"; pat = 'ShapeKit\.disc\((1\.4|0\.9), 0\.004, ML\.water\(\), "(Puddle2?)"\)'; rep = 'ShapeKit.disc_flat($1, 0.004, ML.water(), $2)' },
	@{ f = "$dir\props_proto.gd"; pat = 'ShapeKit\.disc\((0\.04|radius \* 0\.32), ([0-9.]+), ([^,]+), "(PodLens%02d|CoreFace)"\)'; rep = 'ShapeKit.disc($1, $2, $3, $4)' }
)
foreach ($e in $extra) {
	if (-not (Test-Path $e.f)) { continue }
	$t = [System.IO.File]::ReadAllText($e.f)
	$n = [regex]::Replace($t, $e.pat, $e.rep)
	if ($n -ne $t) { [System.IO.File]::WriteAllText($e.f, $n); Write-Output ("patched {0}" -f (Split-Path $e.f -Leaf)) }
}
