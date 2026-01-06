# 🏗️ Clean Architecture + SOLID Principles

## 📁 Estructura del Proyecto

```
DevoApp/
├── Domain/                          # Capa de Dominio (Lógica de Negocio)
│   ├── Entities/                    # Entidades puras del dominio
│   │   ├── TeamEntity.swift
│   │   └── UserEntity.swift
│   ├── Repositories/                # Protocolos (Interfaces)
│   │   ├── TeamRepositoryProtocol.swift
│   │   └── UserRepositoryProtocol.swift
│   └── UseCases/                   # Casos de uso (Lógica de negocio)
│       ├── CreateTeamUseCase.swift
│       ├── JoinTeamUseCase.swift
│       └── GetUserTeamUseCase.swift
│
├── Data/                           # Capa de Datos (Implementaciones)
│   ├── Models/                     # Modelos de datos (Firestore)
│   │   └── TeamDataModel.swift
│   └── Repositories/               # Implementaciones concretas
│       ├── TeamRepository.swift
│       └── UserRepository.swift
│
└── Presentation/                   # Capa de Presentación (UI)
    ├── ViewModels/                 # ViewModels (Estado de UI)
    │   └── TeamViewModel.swift
    ├── DependencyInjection/        # Inyección de dependencias
    │   └── DependencyContainer.swift
    └── Views/                      # Vistas SwiftUI
        └── TeamSelectionView.swift (actualizado)
```

## 🎯 Principios SOLID Aplicados

### 1. **Single Responsibility Principle (SRP)**
- ✅ Cada clase tiene una sola responsabilidad:
  - `CreateTeamUseCase`: Solo crear equipos
  - `JoinTeamUseCase`: Solo unirse a equipos
  - `TeamRepository`: Solo acceso a datos de equipos
  - `TeamViewModel`: Solo coordinar UI y casos de uso

### 2. **Open/Closed Principle (OCP)**
- ✅ Abierto para extensión, cerrado para modificación:
  - Nuevos casos de uso se agregan sin modificar existentes
  - Nuevos repositorios implementan protocolos sin cambiar código existente

### 3. **Liskov Substitution Principle (LSP)**
- ✅ Las implementaciones pueden sustituirse:
  - Cualquier implementación de `TeamRepositoryProtocol` funciona igual
  - Puedes cambiar Firestore por otra base de datos sin afectar el dominio

### 4. **Interface Segregation Principle (ISP)**
- ✅ Interfaces específicas y pequeñas:
  - `TeamRepositoryProtocol`: Solo métodos relacionados con equipos
  - `UserRepositoryProtocol`: Solo métodos relacionados con usuarios
  - Cada protocolo tiene solo lo necesario

### 5. **Dependency Inversion Principle (DIP)**
- ✅ Dependemos de abstracciones, no de implementaciones:
  - ViewModels dependen de protocolos (`TeamRepositoryProtocol`)
  - Use Cases dependen de protocolos, no de implementaciones concretas
  - `DependencyContainer` inyecta las dependencias

## 🏛️ Clean Architecture

### Capas y Dependencias

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│  (Views, ViewModels)                │
│  ↓ depende de                      │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│        Domain Layer                 │
│  (Entities, UseCases, Protocols)   │
│  ↓ depende de                      │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│         Data Layer                  │
│  (Repositories, DataModels)         │
│  ↓ depende de                      │
└─────────────────────────────────────┘
      Firebase/Firestore
```

### Reglas de Dependencia

1. **Domain** no depende de nada (independiente)
2. **Data** depende solo de **Domain**
3. **Presentation** depende solo de **Domain**
4. Las dependencias van hacia adentro (hacia Domain)

## 🔄 Flujo de Datos

### Ejemplo: Crear un Equipo

```
1. View (TeamSelectionView)
   ↓ llama a
2. ViewModel (TeamViewModel)
   ↓ ejecuta
3. Use Case (CreateTeamUseCase)
   ↓ usa
4. Repository Protocol (TeamRepositoryProtocol)
   ↓ implementado por
5. Repository (TeamRepository)
   ↓ accede a
6. Firestore
   ↓ retorna
7. Data Model (TeamDataModel)
   ↓ convierte a
8. Domain Entity (TeamEntity)
   ↓ retorna a través de las capas
9. ViewModel actualiza @Published
10. View se actualiza automáticamente
```

## 🧪 Testabilidad

### Ventajas para Testing

1. **Domain Layer**: Testeable sin Firebase
   - Mock de repositorios
   - Tests unitarios puros

2. **Use Cases**: Testeables independientemente
   - Inyectar mocks de repositorios
   - Verificar lógica de negocio

3. **ViewModels**: Testeables con mocks
   - Mock de Use Cases
   - Verificar estado de UI

## 📦 Dependency Injection

### DependencyContainer

Centraliza la creación de dependencias:

```swift
// Singleton que crea todas las dependencias
let container = DependencyContainer.shared

// Crear ViewModel con todas sus dependencias inyectadas
let viewModel = container.makeTeamViewModel()
```

### Beneficios

- ✅ Fácil cambiar implementaciones
- ✅ Fácil crear mocks para testing
- ✅ Control centralizado de dependencias

## 🔄 Migración desde Código Anterior

### Antes (Acoplamiento)
```swift
class TeamManager {
    private let db = Firestore.firestore()  // ❌ Dependencia directa
    // Lógica mezclada con acceso a datos
}
```

### Después (Desacoplado)
```swift
// Domain: Protocolo
protocol TeamRepositoryProtocol { ... }

// Data: Implementación
class TeamRepository: TeamRepositoryProtocol { ... }

// Presentation: ViewModel usa protocolo
class TeamViewModel {
    init(repository: TeamRepositoryProtocol) { ... }  // ✅ Dependencia inyectada
}
```

## 🚀 Próximos Pasos

1. **Agregar más Use Cases**:
   - RemoveMemberUseCase
   - UpdateTeamUseCase
   - GetTeamMembersUseCase

2. **Agregar Tests**:
   - Unit tests para Use Cases
   - Integration tests para Repositories
   - UI tests para ViewModels

3. **Mejorar Error Handling**:
   - Result types en lugar de throws
   - Error mapping entre capas

4. **Agregar Caching**:
   - Repository con cache local
   - Reducir llamadas a Firestore

## 📚 Referencias

- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)

