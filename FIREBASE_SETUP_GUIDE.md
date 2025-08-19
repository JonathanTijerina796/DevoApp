# 🔥 Guía de Configuración Firebase para DevoApp

## Paso 1: Configurar proyecto en Firebase Console

1. **Ir a Firebase Console**: https://console.firebase.google.com/
2. **Crear proyecto o seleccionar existente**
3. **Agregar app iOS**:
   - Bundle ID: `com.devoapp.DevoApp` (o el que prefieras)
   - App Nickname: `DevoApp`
   - Descargar `GoogleService-Info.plist`

## Paso 2: Habilitar Authentication

1. En Firebase Console, ir a **Authentication**
2. Ir a **Sign-in method**
3. Habilitar estos proveedores:
   - ✅ **Email/Password** (Enable)
   - ✅ **Google** (Enable)
   - ✅ **Facebook** (Enable - necesitarás App ID y App Secret)

## Paso 3: Configurar proveedores sociales

### Facebook:
1. Ir a https://developers.facebook.com/
2. Crear app o usar existente
3. Copiar App ID y App Secret
4. En Firebase Console > Authentication > Sign-in method > Facebook:
   - Pegar App ID y App Secret
   - Copiar la URL de redirección OAuth
5. En Facebook Developer Console:
   - Agregar la URL de redirección OAuth
   - Agregar Bundle ID en configuración iOS

### Google:
1. Se configura automáticamente con Firebase
2. Copiar el Client ID desde GoogleService-Info.plist

## Paso 4: Archivos necesarios

- ✅ `GoogleService-Info.plist` (descargar de Firebase)
- ✅ Configurar Bundle ID en Xcode
- ✅ Agregar Firebase SDK (Swift Package Manager)

## URLs de Firebase SDK:
- **Firebase iOS SDK**: https://github.com/firebase/firebase-ios-sdk
- **Productos necesarios**:
  - FirebaseAuth
  - FirebaseCore
  - GoogleSignIn (para Google Auth)
  - FacebookCore y FacebookLogin (para Facebook Auth)

## Próximos pasos:
1. Seguir esta guía
2. Compartir GoogleService-Info.plist
3. Configurar Bundle ID
4. Implementar la lógica de autenticación
