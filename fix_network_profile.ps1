$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevando permisos a Administrador..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "--------------------------------------------------------"
Write-Host " SOLUCIONANDO PROBLEMA DE RED PARA MEAL.IA (FIREWALL)  "
Write-Host "--------------------------------------------------------"
Write-Host "Detectando tu conexión Wi-Fi actual..."

$interfaces = Get-NetConnectionProfile
foreach ($interface in $interfaces) {
    Write-Host "Red encontrada: $($interface.Name) - Categoría: $($interface.NetworkCategory)"
    
    if ($interface.NetworkCategory -eq "Public") {
        Write-Host "-> Cambiando la red '$($interface.Name)' de Pública a Privada para permitir que el celular se conecte..." -ForegroundColor Yellow
        Set-NetConnectionProfile -InterfaceIndex $interface.InterfaceIndex -NetworkCategory Private
        Write-Host "-> ¡Cambiado con éxito a Privada!" -ForegroundColor Green
    } else {
        Write-Host "-> Esta red ya es Privada. Está bien configurada." -ForegroundColor Green
    }
}

Write-Host "`nAsegurando que el Firewall no bloquee Python ni FastAPI..."
# Eliminar posibles reglas de bloqueo previas a Python
Remove-NetFirewallRule -DisplayName "MealIA Backend" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "MealIA Backend" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow -Profile Any | Out-Null

Write-Host "--------------------------------------------------------"
Write-Host " ¡Todo Listo! " -ForegroundColor Green
Write-Host "--------------------------------------------------------"
Write-Host "Tu PC originada ahora aceptará las conexiones de tu celular."
Write-Host "Por favor, CIERRA tu servidor backend actual si estaba abierto."
Write-Host "Y vuelve a iniciarlo usando .\backend\run_backend.bat"
Write-Host ""
Read-Host "Presiona Enter para cerrar esta ventana..."
