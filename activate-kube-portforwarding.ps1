# Konfiguracja
$Port = 30080          # NodePort w klastrze
$ListenAddress = "0.0.0.0"   # nasłuch na wszystkich IP Windowsa
$DistroName = ""       # opcjonalnie: nazwa distro, np. "Ubuntu-22.04"; puste = domyślne distro
$InterfaceName = "eth1"      # na podstawie ip addr show -> inet 192.168.8.188/24 na eth1

Write-Host "=== Detect WSL2/Docker Desktop IP (interface: $InterfaceName) ==="

function Get-WslIp {
    param(
        [string]$Distro,
        [string]$IfName
    )

    if ([string]::IsNullOrWhiteSpace($Distro)) {
        $ipOutput = wsl ip addr show $IfName 2>$null
    } else {
        $ipOutput = wsl -d $Distro ip addr show $IfName 2>$null
    }

    if (-not $ipOutput) {
        return $null
    }

    foreach ($line in $ipOutput -split "`n") {
        $trim = $line.Trim()
        if ($trim -like "inet *") {
            # np. "inet 192.168.8.188/24 brd 192.168.8.255 scope global noprefixroute eth1"
            $parts = $trim.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
            $ipCidr = $parts[1]       # "192.168.8.188/24"
            $ip = $ipCidr.Split("/")[0]
            return $ip
        }
    }

    return $null
}

$wslIp = Get-WslIp -Distro $DistroName -IfName $InterfaceName

if (-not $wslIp) {
    Write-Error "Can't detect WSL2 IP on interface $InterfaceName."
    exit 1
}

Write-Host "WSL2 IP: $wslIp"

Write-Host "=== Removing old portproxy rule (if exists) ==="
netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=$ListenAddress | Out-Null

Write-Host "=== Adding new portproxy rule ==="
netsh interface portproxy add v4tov4 `
    listenport=$Port listenaddress=$ListenAddress `
    connectport=$Port connectaddress=$wslIp

Write-Host "=== Current portproxy rules ==="
netsh interface portproxy show all
Write-Host ""
Write-Host "Done. From Windows open: http://localhost:$Port"