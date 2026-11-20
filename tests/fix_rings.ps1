$dir = "C:\Users\imran\Documents\computer graphics\DESHI IRON GARAGE\scripts\procedural"
# Every line below is a ShapeKit.torus(...) that is being rotated PI/2 about X
# while encircling a VERTICAL cylinder. Godot's TorusMesh is already generated in
# the XZ plane, so that rotation turns collars, bands, races, ties and bezels into
# vertical hoops. Deleting the line restores the intended flat ring.
$targets = @{
	"exosuit_factory.gd" = @(165, 243, 335, 396, 437, 477, 591)
	"props_proto.gd"     = @(428, 447, 508, 545, 905, 908)
	"props_mech.gd"      = @(174, 371, 374, 463, 789, 1046)
	"props_daily.gd"     = @(92, 264, 507)
	"props_elec.gd"      = @(639, 1231)
	"prop_factory.gd"    = @(946)
}
foreach ($file in $targets.Keys) {
	$path = Join-Path $dir $file
	$lines = [System.IO.File]::ReadAllLines($path)
	$removed = 0
	# delete high-to-low so earlier indices stay valid
	foreach ($n in ($targets[$file] | Sort-Object -Descending)) {
		$idx = $n - 1
		if ($idx -lt 0 -or $idx -ge $lines.Count) { Write-Output ("SKIP {0} {1} out of range" -f $file, $n); continue }
		if ($lines[$idx] -notmatch '\.rotation = Vector3\(PI \* 0\.5, 0\.0, 0\.0\)') {
			Write-Output ("SKIP {0} {1} not a rotation line: {2}" -f $file, $n, $lines[$idx].Trim())
			continue
		}
		$list = New-Object System.Collections.Generic.List[string]
		$list.AddRange([string[]]$lines[0..($idx - 1)])
		if ($idx + 1 -lt $lines.Count) { $list.AddRange([string[]]$lines[($idx + 1)..($lines.Count - 1)]) }
		$lines = $list.ToArray()
		$removed++
	}
	[System.IO.File]::WriteAllLines($path, $lines)
	Write-Output "$file : removed $removed"
}
