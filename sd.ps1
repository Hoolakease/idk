$ErrorActionPreference = 'SilentlyContinue'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Mem {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool b, int c);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h, IntPtr b, out MBI m, uint l);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr b, byte[] buf, UIntPtr s, out UIntPtr r);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr b, byte[] buf, UIntPtr s, out UIntPtr w);
    [DllImport("kernel32.dll")] public static extern bool VirtualProtectEx(IntPtr h, IntPtr b, UIntPtr s, uint n, out uint o);
    [StructLayout(LayoutKind.Sequential)] public struct MBI {
        public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect;
        public IntPtr RegionSize; public uint State; public uint Protect; public uint Type;
    }
}
"@
$procs = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $procs) { Write-Host 'no javaw.'; exit 1 }
# short needles - catch mangled/obfuscated variants too
$needles = @(
    'slink','Slink','SLINK','slikny','sl1nky',
    'dev.slinky','dev/slinky','SlinkyMod','SlinkyNative','slinky-na','OpenSlinky',
    'autoclick','clicker','Aim Assist','aimassist','Backtrack','backtrack',
    'Hit Select','hitselect','Knockback','knockback','Lag Range','lagrange',
    'Reach','reach','Timer Range','timerrange','Weapons','weapons',
    'Auto Block','autoblock','Auto Weapon','autoweapon','Critical','critical','crits',
    'Hitbox','hitbox','Pierc','pierc','Sprint Reset','sprintreset',
    'Veloc','veloc','Fast Accel','fastaccel','Inv Walk','invwalk',
    'No Jump','nojump','Null Move','nullmove','Sprint','sprint',
    'Instant Stop','instantstop','Keep Sprint','keepsprint',
    'No Slow','noslow','Safe Walk','safewalk','Strafe','strafe',
    'Anti Debuff','antidebuff','Chams','chams','Free Look','freelook',
    'Indicator','indicator','Mod Overlay','modoverlay','No Hurt','nohurt',
    'Player ESP','playeresp','Trajector','trajector','Block ESP','blockesp',
    'Chest ESP','chestesp','Item ESP','itemesp','Name Tag','nametag',
    'Notificat','notificat','Pointer','pointer','Auto Tool','autotool',
    'Bridge Assist','bridgeassist','Fast Mine','fastmine','Ghost Hand','ghosthand',
    'Block In','blockin','Clutch','clutch','Fast Place','fastplace',
    'Anti Bot','antibot','Auto Rod','autorod','Blink','blink',
    'Fake Lag','fakelag','Inv Manager','invmanager','No Hit Delay','nohitdelay',
    'No Use Delay','nousedelay','Refill','refill','Timer','timer',
    'Auto Pot','autopot','Auto Soup','autosoup','Debug','debug',
    'Friends','friends','No Item Release','noitemrelease','Ping Fix','pingfix',
    'Teams','teams','Combat','Profiles','Unload','MethodNode','InsnList',
    'shaded.asm','setting.Setting','module.world','module.utility','module.combat',
    'FastPlaceModule','BridgeAssistModule','AutoToolModule','RefillModule'
)
$tb = foreach ($t in $needles) { [Text.Encoding]::ASCII.GetBytes($t) }
# lowercase-folded copies for case-insensitive hit
$tbl = foreach ($t in $needles) { [Text.Encoding]::ASCII.GetBytes($t.ToLower()) }
$tb16 = foreach ($t in $needles) { [Text.Encoding]::Unicode.GetBytes($t) }
$tb16l = foreach ($t in $needles) { [Text.Encoding]::Unicode.GetBytes($t.ToLower()) }
$totalWiped = 0; $totalRegions = 0
foreach ($p in $procs) {
    Write-Host ('pid ' + $p.Id + ' ...')
    $h = [Mem]::OpenProcess(0x1F0FFF, $false, $p.Id)
    if ($h -eq [IntPtr]::Zero) { Write-Host ' open failed (admin?)'; continue }
    $mbi = New-Object Mem+MBI
    $addr = [Int64]0
    $max = [Int64]0x7FFFFFFFFFFF
    $sz = [Runtime.InteropServices.Marshal]::SizeOf($mbi)
    $wiped = 0; $regions = 0; $scanned = 0
    while ($addr -lt $max) {
        $r = [Mem]::VirtualQueryEx($h, [IntPtr]$addr, [ref]$mbi, [uint32]$sz)
        if ($r -eq 0) { break }
        $base = $mbi.BaseAddress.ToInt64()
        $rsize = $mbi.RegionSize.ToInt64()
        if ($rsize -le 0 -or $rsize -gt 256MB) { $addr = $base + 0x10000; if ($addr -le $base) { break }; continue }
        if ($mbi.State -eq 0x1000) {
            $scanned++
            $n = [UInt64]$rsize
            $buf = New-Object byte[] $rsize
            [UIntPtr]$rd = [UIntPtr]::Zero
            $ok = $false
            try { $ok = [Mem]::ReadProcessMemory($h, $mbi.BaseAddress, $buf, [UIntPtr]$n, [ref]$rd) } catch {}
            $got = 0
            try { $got = [UInt64]$rd } catch { $got = 0 }
            if ($ok -and $got -gt 0) {
                # lowercase-fold buffer copy for insensitive pass
                $low = New-Object byte[] $got
                for ($k = 0; $k -lt $got; $k++) { $b = $buf[$k]; if ($b -ge 65 -and $b -le 90) { $low[$k] = $b + 32 } else { $low[$k] = $b } }
                $dirty = $false
                foreach ($pat in $tb) {
                    $L = $pat.Length; if ($L -lt 3) { continue }
                    for ($i = 0; $i + $L -le $got; $i++) {
                        if ($buf[$i] -ne $pat[0]) { continue }
                        $hit = $true
                        for ($j = 1; $j -lt $L; $j++) { if ($buf[$i+$j] -ne $pat[$j]) { $hit = $false; break } }
                        if ($hit) { for ($j = 0; $j -lt $L; $j++) { $buf[$i+$j] = 0 }; $dirty = $true; $wiped++ }
                    }
                }
                foreach ($pat in $tbl) {
                    $L = $pat.Length; if ($L -lt 3) { continue }
                    for ($i = 0; $i + $L -le $got; $i++) {
                        if ($low[$i] -ne $pat[0]) { continue }
                        $hit = $true
                        for ($j = 1; $j -lt $L; $j++) { if ($low[$i+$j] -ne $pat[$j]) { $hit = $false; break } }
                        if ($hit) { for ($j = 0; $j -lt $L; $j++) { $buf[$i+$j] = 0 }; $dirty = $true; $wiped++ }
                    }
                }
                if ($dirty) {
                    [uint32]$old = 0
                    try { [Mem]::VirtualProtectEx($h, $mbi.BaseAddress, [UIntPtr]$got, 4, [ref]$old) | Out-Null } catch {}
                    [UIntPtr]$wr = [UIntPtr]::Zero
                    try { [Mem]::WriteProcessMemory($h, $mbi.BaseAddress, $buf, [UIntPtr]$got, [ref]$wr) | Out-Null } catch {}
                    try { [Mem]::VirtualProtectEx($h, $mbi.BaseAddress, [UIntPtr]$got, $old, [ref]$old) | Out-Null } catch {}
                    $regions++
                }
            }
        }
        $addr = $base + $rsize
        if ($addr -le $base) { break }
    }
    [Mem]::CloseHandle($h) | Out-Null
    Write-Host (' pid ' + $p.Id + ': scanned ' + $scanned + ' wiped ' + $wiped + ' in ' + $regions)
    $totalWiped += $wiped; $totalRegions += $regions
}
Write-Host ('TOTAL wiped ' + $totalWiped + ' in ' + $totalRegions)
