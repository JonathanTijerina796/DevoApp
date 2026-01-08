# 📁 Estructura del Proyecto DevoApp

## 🗂️ Organización de Archivos

```
DevoApp/
├── Core/                          # Archivos principales de la aplicación
│   ├── DevoAppApp.swift          # Punto de entrada de la app
│   └── ContentView.swift         # Vista principal de navegación
│
├── Models/                        # Modelos de datos
│   └── Team.swift                # Modelo de equipo
│
├── Managers/                      # Gestores de lógica de negocio
│   ├── AuthenticationManager.swift  # Gestión de autenticación
│   └── TeamManager.swift         # Gestión de equipos
│
├── Views/                         # Vistas de la interfaz
│   ├── Auth/                     # Vistas de autenticación
│   │   ├── Login.swift           # Vista de login/registro
│   │   └── SplashView.swift      # Pantalla de inicio
│   │
│   ├── Team/                     # Vistas relacionadas con equipos
│   │   ├── TeamSelectionView.swift  # Selección de equipo (líder/miembro)
│   │   └── MainTeamView.swift    # Vista principal del equipo
│   │
│   └── Main/                     # Vistas principales de la app
│       ├── MainTabView.swift     # TabBar de navegación
│       ├── HomeView.swift        # Vista de inicio
│       └── ProfileView.swift     # Vista de perfil
│
└── Resources/                     # Recursos de la aplicación
    ├── Assets.xcassets/          # Imágenes y assets
    ├── en.lproj/                 # Localización en inglés
    ├── es.lproj/                 # Localización en español
    ├── GoogleService-Info.plist  # Configuración de Firebase
    └── Info.plist                # Configuración de la app
```

## 📋 Descripción de Carpetas

### Core/
Contiene los archivos fundamentales de la aplicación:
- **DevoAppApp.swift**: Configuración inicial, punto de entrada
- **ContentView.swift**: Coordinador principal de navegación

### Models/
Modelos de datos puros:
- **Team.swift**: Estructura de datos para equipos

### Managers/
Clases que gestionan la lógica de negocio y comunicación con servicios:
- **AuthenticationManager.swift**: Maneja autenticación (Firebase Auth)
- **TeamManager.swift**: Maneja operaciones de equipos (Firestore)

### Views/
Todas las vistas de la interfaz de usuario, organizadas por funcionalidad:

#### Auth/
Vistas relacionadas con autenticación:
- **Login.swift**: Pantalla de login y registro
- **SplashView.swift**: Pantalla de bienvenida inicial

#### Team/
Vistas relacionadas con equipos:
- **TeamSelectionView.swift**: Selección entre ser líder o miembro
- **MainTeamView.swift**: Vista de administración del equipo

#### Main/
Vistas principales de la aplicación:
- **MainTabView.swift**: TabBar con navegación entre Home y Perfil
- **HomeView.swift**: Pantalla de inicio con información del equipo
- **ProfileView.swift**: Perfil del usuario

### Resources/
Recursos estáticos de la aplicación:
- **Assets.xcassets/**: Imágenes, iconos, colores
- **en.lproj/**, **es.lproj/**: Archivos de localización
- **GoogleService-Info.plist**: Configuración de Firebase
- **Info.plist**: Configuración de la app iOS

## 🔄 Flujo de Navegación

```
DevoAppApp
  └── ContentView
      ├── SplashView (inicial)
      ├── LoginView (si no autenticado)
      ├── TeamSelectionView (si autenticado sin equipo)
      └── MainTabView (si autenticado con equipo)
          ├── HomeTabView
          └── ProfileTabView
```

## ✅ Ventajas de esta Estructura

1. **Organización clara**: Fácil encontrar archivos por funcionalidad
2. **Escalabilidad**: Fácil agregar nuevas features en carpetas específicas
3. **Mantenibilidad**: Separación clara de responsabilidades
4. **Navegación intuitiva**: Estructura lógica y predecible

## 📝 Notas

- Todos los archivos Swift mantienen sus imports y referencias originales
- La estructura es compatible con el sistema de archivos sincronizado de Xcode
- No se modificó ningún código, solo se reorganizaron los archivos

