# Test HTTP verso RetroWave (stesso WiFi del PC). Uso:
#   .\pc_test.ps1 -Ip 192.168.1.45
# L'IP NON e' fisso: leggilo dal monitor seriale (COM CH343) dopo "WiFi: connesso, IP LAN:"

param(
    [Parameter(Mandatory = $true)]
    [string] $Ip
)

$ErrorActionPreference = 'Stop'
$base = "http://$Ip"

Write-Host "Base: $base" -ForegroundColor Cyan

Write-Host "`nControllo porta 80 su $Ip ..." -ForegroundColor DarkGray
try {
    $tn = Test-NetConnection -ComputerName $Ip -Port 80 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if (-not $tn.TcpTestSucceeded) {
        Write-Host @"

NON raggiungibile la porta 80 su $Ip.

Cose da verificare:
  1) IP sbagliato — 192.168.1.45 era solo un ESEMPIO. Apri il monitor seriale:
       cd ..\..
       pio device monitor -p COM12 -b 115200
     Cerca la riga:  WiFi: connesso, IP LAN: x.x.x.x
  2) PC e ESP sulla STESSA rete WiFi (no "ospite" / VLAN isolata sul telefono; il PC deve essere sulla LAN normale).
  3) ESP acceso e connesso al WiFi (se e' in AP di setup, l'IP e' 192.168.4.1 e il PC deve essere connesso a RetroWave-...-Setup).
  4) Firewall sul PC raro in uscita verso LAN; antivirus a volte blocca.

"@ -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Test-NetConnection fallito: $_" -ForegroundColor Yellow
}

function Get-Text([string]$path) {
    try {
        return (Invoke-WebRequest -Uri "$base$path" -UseBasicParsing -TimeoutSec 8).Content
    } catch {
        Write-Host "Errore HTTP ${path}: $_" -ForegroundColor Red
        throw
    }
}

try {
    Write-Host "`n--- /ping ---" -ForegroundColor Yellow
    Get-Text '/ping' | Write-Host

    Write-Host "`n--- /status ---" -ForegroundColor Yellow
    Get-Text '/status' | Write-Host

    Write-Host "`n--- /diag (prime 800 char) ---" -ForegroundColor Yellow
    $d = Get-Text '/diag'
    if ($d.Length -gt 800) { $d = $d.Substring(0, 800) + '...' }
    Write-Host $d

    Write-Host "`nOK. Apri nel browser: $base/ per la console HTML." -ForegroundColor Green
} catch {
    exit 1
}
