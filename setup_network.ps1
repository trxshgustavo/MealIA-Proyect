$ErrorActionPreference = "Stop"

# 1. Check for Admin Privileges and Self-Elevate
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Solicitando permisos de Administrador para configurar el Firewall..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 2. Configure Firewall
$port = 8000
$ruleName = "MealIA Backend"

Write-Host "Configurando Firewall de Windows..." -ForegroundColor Cyan
try {
    # Delete old rule if exists to avoid duplicates
    netsh advfirewall firewall delete rule name="$ruleName" | Out-Null
    
    # Create new Allow rule for Private and Domain networks
    netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=$port profile=private,domain | Out-Null
    
    Write-Host "[OK] Regla de Firewall '$ruleName' creada para el puerto $port." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] No se pudo configurar el Firewall: $_" -ForegroundColor Red
}

# 3. Get Local IP
try {
    # Prioritize Wi-Fi
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "*Wi-Fi*" -ErrorAction SilentlyContinue).IPAddress
    
    # Fallback to any non-loopback
    if (!$ip) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.InterfaceAlias -notlike "*Loopback*" -and 
            $_.InterfaceAlias -notlike "*vEthernet*" 
        }).IPAddress | Select-Object -First 1
    }
} catch {
    $ip = "Unknown"
}

Write-Host "`n---------------------------------------------------"
Write-Host "CONFIGURACIÓN DE RED COMPLETADA" -ForegroundColor Green
Write-Host "---------------------------------------------------"
Write-Host "Tu IP Local es: $ip" -ForegroundColor Cyan
Write-Host "Backend URL:    http://$ip:$port" -ForegroundColor Cyan
Write-Host "---------------------------------------------------"

Write-Host "`nPresiona Enter para cerrar..."
Read-Host
