param([string]$Script="playthrough", [string]$Extra="", [string]$Scene="")
$G="C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$proj="C:\Users\hanwd\OneDrive\Desktop\past-future"
$common=@("--path",$proj,"--resolution","960x540","--borderless","--always-on-top")
$h=$common+@("--position","0,0")
$c=$common+@("--position","960,0")
$u=@("--","--ap-script=$Script")
if($Extra){ $u += $Extra.Split(" ") }
$hp=Start-Process $G -ArgumentList ($h+$u+@("--ap-role=host")) -PassThru -RedirectStandardOutput "$proj\docs\internal\gameplay_recording\logs\host.out" -RedirectStandardError "$proj\docs\internal\gameplay_recording\logs\host.err"
Start-Sleep 1
$cp=Start-Process $G -ArgumentList ($c+$u+@("--ap-role=client")) -PassThru -RedirectStandardOutput "$proj\docs\internal\gameplay_recording\logs\client.out" -RedirectStandardError "$proj\docs\internal\gameplay_recording\logs\client.err"
"$($hp.Id) $($cp.Id)" | Set-Content "$proj\docs\internal\gameplay_recording\logs\pids.txt"
$hp.WaitForExit(); $cp.WaitForExit()
