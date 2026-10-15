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
    'Aim Assist','Pulls your crosshair towards other players',
    'Auto Clicker','autoclicker','AutoClicker','auto_clicker','Clicks for you when holding down left-click',
    'Backtrack','backtrack','Uses lag to make players easier to hit',
    'Hit Select','hitselect','hit_select','Perfectly times your hits',
    'Knockback Delay','knockbackdelay','knockback_delay','Delays your knockback in certain scenarios',
    'Lag Range','lagrange','lag_range','Uses lag to stay out of target range',
    'Reach','reach','Increases your melee range',
    'Timer Range','timerrange','timer_range','Abuses timer lag to teleport you',
    'Weapons','weapons','Configure which items are considered weapons',
    'Auto Block','autoblock','auto_block','Blocks your sword for you in combat',
    'Auto Weapon','autoweapon','auto_weapon','Selects your weapon when aiming on players',
    'Criticals','criticals','crits','Increases chance of landing critical hits',
    'Hitboxes','hitboxes','Expands hitboxes of other players',
    'Knockback Displace','knockbackdisplace','Allows dealing knockback at a different angle',
    'Piercing','piercing','Allows hitting entities through obstructions',
    'Sprint Reset','sprintreset','sprint_reset','Resets your sprint state to deal more knockback',
    'Velocity','velocity','Reduces the amount of knockback you take',
    'Fast Accel','fastaccel','Speeds up acceleration',
    'Inv Walk','invwalk','inv_walk','Allows moving in inventory',
    'No Jump Delay','nojumpdelay','Removes cooldown when holding jump key',
    'Null Move','nullmove','Makes it easier to switch move direction instantly',
    'Sprint','sprint','Automatically sprints for you',
    'Instant Stop','instantstop','Instantly stops moving when move keys are released',
    'Keep Sprint','keepsprint','Keeps your sprint speed when attacking players',
    'No Slow','noslow','no_slow','Removes slowdown while using items',
    'Safe Walk','safewalk','safe_walk','Prevents you from walking off ledges',
    'Strafe','strafe','Allows faster strafing',
    'Anti Debuff','antidebuff','Removes negative visual effects',
    'Chams','chams','Renders players behind blocks',
    'Free Look','freelook','free_look','Freely move the camera around',
    'Indicators','indicators','Points to incoming projectiles',
    'Mod Overlay','modoverlay','Displays a list of all active mods',
    'No Hurt Cam','nohurtcam','Removes camera shake when taking damage',
    'Player ESP','playeresp','player_esp','Highlights other players',
    'Trajectories','trajectories','Predicts the trajectory of the item in your hand',
    'Block ESP','blockesp','block_esp','Highlights blocks',
    'Chest ESP','chestesp','chest_esp','Highlights chests',
    'GUI','Graphical interface for the cheat',
    'Item ESP','itemesp','item_esp','Highlights dropped items',
    'Name Tags','nametags','name_tags','Makes player name tags easier to see',
    'Notifications','notifications','Informs you when certain actions are performed',
    'Pointers','pointers','Points to other players',
    'Auto Tool','autotool','Selects the best tool when digging',
    'Bridge Assist','bridgeassist','Sneaks and unsneaks for you while bridging',
    'Fast Mine','fastmine','Increases block mining speed',
    'Ghost Hand','ghosthand','Allows interacting with blocks through entities',
    'Block In','blockin','Places blocks around you',
    'Clutch','clutch','Clutches for you when falling',
    'Fast Place','fastplace','Allows placing blocks faster',
    'Anti Bot','antibot','anti_bot','Ignores NPCs for specific modules',
    'Auto Rod','autorod','Throws your fishing rod for you',
    'Blink','blink','Simulates teleporting using lag',
    'Fake Lag','fakelag','fake_lag','Adds an artificial delay to your packets',
    'Inv Manager','invmanager','inv_manager','Organises your inventory for you',
    'No Hit Delay','nohitdelay','Removes 1.8 swing delay',
    'No Use Delay','nousedelay','Removes vanilla delay when consuming items',
    'Refill','refill','Automatically moves items into your hotbar',
    'Timer','timer','Modifies the speed the game runs at',
    'Auto Pot','autopot','Uses healing potions for you',
    'Auto Soup','autosoup','Uses soups for you',
    'Debug','debug','Prints debug information in chat',
    'Friends','friends','Lets you mark other players as friendly',
    'Item Use Fix','itemusefix','Allows using items while breaking blocks',
    'No Item Release','noitemrelease','Hides item release from server',
    'Ping Fix','pingfix','Shows your real ping while using lag mods',
    'Teams','teams','Ignores teammates for specific modules',
    'Combat','Profiles','Unload'
)
$tb = foreach ($t in $targets) { [Text.Encoding]::ASCII.GetBytes($t); [Text.Encoding]::UTF8.GetBytes($t) | Out-Null }
$tb = foreach ($t in $targets) { [Text.Encoding]::ASCII.GetBytes($t) }
# also build UTF-16LE (Java/JVM strings live wide half the time)
$tb16 = foreach ($t in $targets) { [Text.Encoding]::Unicode.GetBytes($t) }
$p = Get-Javaw
if (-not $p) { Write-Host 'javaw.exe not running.'; exit 1 }
$h = [Mem]::OpenProcess(0x1F0FFF, $false, $p.Id)
if ($h -eq [IntPtr]::Zero) { Write-Host 'OpenProcess failed. Run as admin.'; exit 1 }
$wiped = 0; $regions = 0
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
    if ($mbi.State -eq 0x1000 -and $mbi.Type -eq 0x20000 -and $rsize -lt 256MB) {
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
Write-Host "wiped $wiped hits in $regions regions."
