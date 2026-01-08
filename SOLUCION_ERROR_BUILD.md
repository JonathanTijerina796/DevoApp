# 🔧 Solución para Error "Multiple commands produce"

## ⚠️ Problema
El error "Multiple commands produce" ocurre cuando Xcode intenta compilar el mismo archivo dos veces, generalmente debido a:
- DerivedData corrupto
- Referencias duplicadas en Build Phases
- Archivos movidos pero Xcode mantiene referencias antiguas

## ✅ Solución Paso a Paso

### Paso 1: Cerrar Xcode
**IMPORTANTE**: Debes cerrar Xcode completamente antes de continuar.
- Presiona `⌘Q` para salir de Xcode
- Verifica que no haya procesos de Xcode ejecutándose

### Paso 2: Limpiar DerivedData
Ejecuta este comando en la terminal:

```bash
cd /Users/jtijerina/Documents/DevoApp
rm -rf ~/Library/Developer/Xcode/DerivedData/DevoApp-*
```

O ejecuta el script:
```bash
./fix_build_issues.sh
```

### Paso 3: Abrir Xcode
1. Abre Xcode nuevamente
2. Abre el proyecto `DevoApp.xcodeproj`

### Paso 4: Limpiar Build Folder
1. En Xcode, ve a: **Product → Clean Build Folder** (o presiona `⇧⌘K`)
2. Espera a que termine la limpieza

### Paso 5: Verificar Build Phases (si el error persiste)
1. Selecciona el proyecto "DevoApp" en el navegador izquierdo
2. Selecciona el target "DevoApp"
3. Ve a la pestaña **"Build Phases"**
4. Expande **"Compile Sources"**
5. Busca archivos duplicados (mismo nombre apareciendo dos veces)
6. Si encuentras duplicados:
   - Selecciona la referencia duplicada
   - Presiona `Delete` o haz clic en el botón `-`
   - **NO** elimines el archivo del sistema, solo la referencia

### Paso 6: Reconstruir
1. **Product → Build** (o presiona `⌘B`)
2. El proyecto debería compilar correctamente

## 📝 Notas Importantes

- El proyecto usa `fileSystemSynchronizedGroups`, lo que significa que Xcode sincroniza automáticamente los archivos del sistema de archivos
- No necesitas agregar archivos manualmente al proyecto
- Si el error persiste después de estos pasos, puede ser necesario verificar que no haya archivos duplicados en el sistema de archivos

## 🔍 Verificación

Para verificar que no hay archivos duplicados en el sistema de archivos:

```bash
cd /Users/jtijerina/Documents/DevoApp/DevoApp
find . -name "*.swift" -type f | sort | uniq -d
```

Si este comando no devuelve nada, no hay archivos duplicados.

