# 🐍 Guía Rápida: Entorno Virtual Python

## ✅ Configuración Actual

- **Ubicación:** `.venv/` (en la raíz del proyecto)
- **Python:** 3.12.10
- **Auto-activación:** ✅ Habilitada en VS Code

## 🚀 Cómo Funciona

### Primera Vez (Configuración Inicial)

```powershell
# 1. Crear el entorno virtual (desde la raíz del proyecto)
python -m venv .venv

# 2. Activar (solo si VS Code no lo hace automáticamente)
.\.venv\Scripts\activate

# 3. Instalar dependencias
pip install -r requirements.txt
```

### Día a Día (Uso Normal)

**VS Code lo hace automáticamente:**
- Abre una **nueva terminal** en VS Code
- El entorno `.venv` se activa solo
- Verás `(.venv)` al inicio del prompt

**Si no se activa automáticamente:**
```powershell
# Activar manualmente
.\.venv\Scripts\activate
```

**Ejecutar el backend:**
```powershell
cd backend; & C:\Users\mihn\.vscode\MealIA-Proyect_fork\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

## 🔧 Comandos Útiles

```powershell
# Ver qué Python estás usando
where python

# Ver paquetes instalados
pip list

# Actualizar un paquete
pip install --upgrade nombre-paquete

# Reinstalar todas las dependencias
pip install -r requirements.txt --force-reinstall
```

## ❓ Solución de Problemas

### "El entorno no se activó automáticamente"

1. **Abre una nueva terminal** (cierra la actual y abre otra)
2. Si persiste, verifica el intérprete:
   - `Ctrl+Shift+P` → "Python: Select Interpreter"
   - Elige `.venv` de la lista

### "No encuentro .venv"

```powershell
# Créalo desde la raíz del proyecto
python -m venv .venv
pip install -r requirements.txt
```

### "Error de ejecución de scripts en PowerShell"

```powershell
# Permitir scripts locales (ejecutar UNA SOLA VEZ)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Después, cierra la terminal actual y abre una NUEVA terminal
# La nueva terminal activará .venv automáticamente
```

### "Tengo (.venv) pero requests no está instalado"

El ambiente se "mezcló". Solución:

```powershell
# 1. Cierra TODAS las terminales de VS Code
# 2. Abre una nueva terminal (debe mostrar (.venv) al inicio)
# 3. Verifica que estés usando el Python correcto:
python -c "import sys; print(sys.executable)"
# Debe mostrar: C:\Users\...\MealIA-Proyect_fork\.venv\Scripts\python.exe

# 4. Si es correcto pero falta requests:
pip install requests
```

## 📝 Recordatorio

- **`.venv`** = entorno virtual (local, no se sube a Git)
- **`requirements.txt`** = lista de paquetes a instalar
- **VS Code** = activa automáticamente `.venv` en nuevas terminales
- **Ubicación actual:** siempre verifica que estés en la raíz del proyecto cuando actives `.venv`

## 🎯 En Resumen

1. Abre VS Code en el proyecto
2. Abre una nueva terminal
3. Debería ver `(.venv)` automáticamente
4. Si no, ejecuta: `.\.venv\Scripts\activate`
5. Listo para trabajar 🚀
