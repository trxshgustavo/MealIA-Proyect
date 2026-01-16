$port = 8000
$ruleName = "MealIA Backend"

Write-Host "Verificando permisos de administrador..."
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Se requieren permisos de administrador. Reiniciando como Admin..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
    exit
}

Write-Host "Abriendo puerto $port en el Firewall de Windows..."

# Eliminar regla existente si hay
netsh advfirewall firewall delete rule name="$ruleName" protocol=TCP localport=$port

# Crear nueva regla
netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=$port

Write-Host "¡Listo! El puerto $port está abierto para conexiones desde tu celular."
Write-Host "Ahora puedes ejecutar el backend y probar la app."
Read-Host -Prompt "Presiona Enter para salir"
