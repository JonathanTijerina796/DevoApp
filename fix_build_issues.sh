#!/bin/bash

# Script para resolver errores de build "Multiple commands produce"

echo "🧹 Limpiando DerivedData de DevoApp..."

# Limpiar DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/DevoApp-*

echo "✅ DerivedData limpiado"
echo ""
echo "📋 Próximos pasos en Xcode:"
echo "1. Cierra Xcode completamente"
echo "2. Abre Xcode nuevamente"
echo "3. Product → Clean Build Folder (⇧⌘K)"
echo "4. Product → Build (⌘B)"
echo ""
echo "Si el problema persiste:"
echo "- Ve a Build Phases → Compile Sources"
echo "- Busca archivos duplicados y elimínalos"
echo "- Verifica que no haya referencias a archivos en ubicaciones antiguas"

