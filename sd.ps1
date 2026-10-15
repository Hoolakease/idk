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
function Get-Javaw { Get-Process javaw -ErrorAction SilentlyContinue | Select-Object -First 1 }
$targets = @(
    'slinky','Slinky','SLINKY','slink','Slink','SLINK',
    'dev.slinky','dev/slinky','slinkysemantic','SlinkyNative','Slinky-Native','slinky-na',
    'OpenSlinky','OpenSlinky-main','C:/Users/michi/Documents/OpenSlinky',
    'C:\Users\michi\Documents\OpenSlinky',
    'autoclicker','AutoClicker','Aim Assist','Backtrack','backtrack',
    'Hit Select','hitselect','Knockback Delay','Lag Range','lagrange',
    'Reach','reach','Timer Range','timerrange','Weapons','weapons',
    'Auto Block','autoblock','Auto Weapon','autoweapon','Criticals','criticals',
    'Hitboxes','hitboxes','Knockback Displace','Piercing','piercing',
    'Sprint Reset','sprintreset','Velocity','velocity',
    'Fast Accel','fastaccel','Inv Walk','invwalk','No Jump Delay',
    'Null Move','nullmove','Sprint','sprint','Instant Stop','instantstop',
    'Keep Sprint','keepsprint','No Slow','noslow','Safe Walk','safewalk',
    'Strafe','strafe','Anti Debuff','antidebuff','Chams','chams',
    'Free Look','freelook','Indicators','indicators','Mod Overlay','modoverlay',
    'No Hurt Cam','nohurtcam','Player ESP','playeresp','Trajectories','trajectories',
    'Block ESP','blockesp','Chest ESP','chestesp','GUI','Graphical interface for the cheat',
    'Item ESP','itemesp','Name Tags','nametags','Notifications','notifications',
    'Pointers','pointers','Auto Tool','autotool','Bridge Assist','bridgeassist',
    'Fast Mine','fastmine','Ghost Hand','ghosthand','Block In','blockin',
    'Clutch','clutch','Fast Place','fastplace','FastPlaceModule','BridgeAssistModule','AutoToolModule',
    'Anti Bot','antibot','Auto Rod','autorod','Blink','blink',
    'Fake Lag','fakelag','Inv Manager','invmanager','No Hit Delay','nohitdelay',
    'No Use Delay','nousedelay','Refill','refill','RefillModule','Timer','timer',
    'Auto Pot','autopot','Auto Soup','autosoup','AutoSoy','Debug','debug',
    'Friends','friends','Item Use Fix','No Item Release','Ping Fix','pingfix',
    'Teams','teams','Combat','Profiles','Unload',
    'dev.slinky.SlinkyMod','MethodNode','TypeAnnotationNode','InsnList',
    'dev.slinky.shaded.asm','dev.slinky.setting.Setting','dev.slinky.module'
)
$tb = foreach ($t in $targets) { [Text.Encoding]::ASCII.GetBytes($t) }
$tb16 = foreach ($t in $targets) { [Text.Encoding]::Unicode.GetBytes($t) }
$p = Get-Javaw
if (-not $p) { Write-Host 'javaw.exe not running.'; exit 1 }
$h = [Mem]::OpenProcess(0x1F0FFF, $false, $p.Id)
if ($h -eq [IntPtr]::Zero) { Write-Host 'OpenProcess failed. Run as admin.'; exit 1 }
$wiped = 0; $regions = 0; $scanned = 0
$mbi = New-Object Mem+MBI
$addr = [Int64]0
$max = [Int64]0x7FFFFFFFFFFF
$sz = [Runtime.InteropServices.Marshal]::SizeOf($mbi)
while ($addr -lt $max) {
    $r = [Mem]::VirtualQueryEx($h, [IntPtr]$addr, [ref]$mbi, [uint32]$sz)
    if ($r -eq 0) { break }
    $base = $mbi.BaseAddress.ToInt64()
    $rsize = $mbi.RegionSize.ToInt64()
    if ($rsize -le 0) { $addr = $base + 0x1000; continue }
    if ($mbi.State -eq 0x1000 -and $rsize -lt 256MB) {
        $scanned++
        $buf = New-Object byte[] $rsize
        [UIntPtr]$rd = [UIntPtr]::Zero
        if ([Mem]::ReadProcessMemory($h, $mbi.BaseAddress, $buf, [UIntPtr]$rsize, [ref]$rd)) {
            $n = $rd.ToUInt64()
            if ($n -gt 0) {
                $dirty = $false
                foreach ($pat in $tb) {
                    $L = $pat.Length
                    for ($i = 0; $i + $L -le $n; $i++) {
                        $hit = $true
                        for ($j = 0; $j -lt $L; $j++) { if ($buf[$i+$j] -ne $pat[$j]) { $hit = $false; break } }
                        if ($hit) { for ($j = 0; $j -lt $L; $j++) { $buf[$i+$j] = 0 }; $dirty = $true; $wiped++; $i += $L - 1 }
                    }
                }
                foreach ($pat in $tb16) {
                    $L = $pat.Length
                    for ($i = 0; $i + $L -le $n; $i++) {
                        $hit = $true
                        for ($j = 0; $j -lt $L; $j++) { if ($buf[$i+$j] -ne $pat[$j]) { $hit = $false; break } }
                        if ($hit) { for ($j = 0; $j -lt $L; $j++) { $buf[$i+$j] = 0 }; $dirty = $true; $wiped++; $i += $L - 1 }
                    }
                }
                if ($dirty) {
                    [uint32]$old = 0
                    [Mem]::VirtualProtectEx($h, $mbi.BaseAddress, [UIntPtr]$n, 4, [ref]$old) | Out-Null
                    [UIntPtr]$wr = [UIntPtr]::Zero
                    [Mem]::WriteProcessMemory($h, $mbi.BaseAddress, $buf, [UIntPtr]$n, [ref]$wr) | Out-Null
                    [Mem]::VirtualProtectEx($h, $mbi.BaseAddress, [UIntPtr]$n, $old, [ref]$old) | Out-Null
                    $regions++
                }
            }
        }
    }
    $addr = $base + $rsize
    if ($addr -le $base) { break }
}
[Mem]::CloseHandle($h) | Out-Null
Write-Host "scanned $scanned regions. wiped $wiped hits in $regions regions."
