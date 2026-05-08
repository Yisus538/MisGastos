// =============================================================================
// MainTabView.swift — Navegación principal por pestañas de la app
// =============================================================================
// Rol en la app:
//   Es el contenedor de navegación principal de la app autenticada. Presenta
//   5 tabs (Inicio, Historial, Estadísticas, Comparar, Perfil) con un
//   `NavigationStack` independiente en cada tab. También dispara la
//   sincronización con Supabase al aparecer (post-login).
//
// Equivalente Android:
//   `BottomNavigationView` (View system) o `NavigationBar` en Compose con
//   `NavController` y múltiples destinos. En arquitectura moderna:
//   ```kotlin
//   Scaffold(
//       bottomBar = {
//           NavigationBar {
//               NavigationBarItem(icon = ..., label = ..., selected = ..., onClick = ...)
//           }
//       }
//   ) { NavigationHost(navController) }
//   ```
//
// TabView en SwiftUI:
//   `TabView(selection: $selectedTab)` controla qué tab está activa.
//   Cada tab tiene:
//   - `NavigationStack { Content }` — pila de navegación independiente por tab.
//     Sin esto, navegar en un tab afectaría el stack de los demás.
//   - `.tag(n)` — identificador numérico de la tab.
//   - `.tabItem { Label(...) }` — ícono y texto en la barra inferior.
//
// NavigationStack independiente por tab:
//   iOS recomienda un `NavigationStack` por tab para que cada tab tenga su
//   propio historial de navegación. Así, hacer pop en el tab de Perfil no
//   afecta la pila del tab de Inicio.
//   Equivalente Android: un `NavGraph` por destino de bottom nav, o
//   `NavController.navigateUp()` con múltiples back stacks habilitados
//   (propiedad `saveState`/`restoreState`).
//
// Sincronización post-login:
//   `.task { }` en SwiftUI ejecuta una operación asíncrona cuando la vista aparece.
//   Se hace sync aquí (además de en SplashView) para cubrir el caso donde:
//   - El usuario inició sesión manualmente (SplashView corrió sin sesión).
//   - La sesión se restauró desde el Keychain pero el token había expirado.
// =============================================================================

import SwiftUI
import SwiftData

/// Contenedor de navegación principal con 5 tabs.
///
/// Equivalente Android: `BottomNavigationView` con `NavController` o
/// `NavigationBar` + `NavHost` en Jetpack Compose.
struct MainTabView: View {

    // MARK: - Dependencias

    /// Contexto de SwiftData para pasarlo a `SyncService` al sincronizar.
    @Environment(\.modelContext) private var modelContext

    // MARK: - Estado de navegación

    /// Tab actualmente seleccionada (0=Inicio, 1=Historial, 2=Estadísticas, 3=Comparar, 4=Perfil).
    @State private var selectedTab = 0

    // MARK: - Vista

    var body: some View {
        TabView(selection: $selectedTab) {

            // Tab 0: Inicio — resumen mensual, compras recientes, presupuesto
            NavigationStack { HomeView() }
                .tag(0)
                .tabItem { Label("Inicio", systemImage: "house.fill") }

            // Tab 1: Historial — lista completa de compras con filtros y exportación
            NavigationStack { HistorialView() }
                .tag(1)
                .tabItem { Label("Historial", systemImage: "clock.fill") }

            // Tab 2: Estadísticas — Swift Charts (barras, líneas, donut, ranking)
            NavigationStack { EstadisticasView() }
                .tag(2)
                .tabItem { Label("Estadísticas", systemImage: "chart.bar.fill") }

            // Tab 3: Comparativa — precios del mismo producto en distintos supermercados
            NavigationStack { ComparativaView() }
                .tag(3)
                .tabItem { Label("Comparar", systemImage: "scalemass.fill") }

            // Tab 4: Perfil — datos del usuario, configuración, avatar, membresía
            NavigationStack { PerfilView() }
                .tag(4)
                .tabItem { Label("Perfil", systemImage: "person.fill") }
        }
        // Color de acento de la tab bar — verde de la marca
        // Equivalente Android: `app:itemActiveIndicatorColor` en BottomNavigationView
        .tint(Color.saGreen)
        // Sincronizar datos al aparecer la pantalla autenticada
        .task {
            // Sync bidireccional con Supabase:
            // 1. Push: subir compras locales con isSynced=false (creadas offline)
            // 2. Pull: bajar compras de la nube que no están en local (nuevo login)
            //
            // Se hace aquí además de SplashView para cubrir el caso de login manual:
            // SplashView corre antes de la autenticación y no tiene sesión activa aún.
            await SyncService.shared.sincronizarPendientes(context: modelContext)
            await SyncService.shared.pullDesdeSupabase(context: modelContext)
        }
    }
}
