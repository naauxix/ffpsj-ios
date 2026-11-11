import FFPSJDomain
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Group {
            switch container.phase {
            case let .configurationRequired(message):
                ConfigurationRequiredView(message: message)
            case .loading:
                ProgressView("Cargando sesión segura…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ffpsjPageBackground()
            case .signedOut:
                AuthenticationView()
            case .restricted:
                RestrictedAccessView()
            case .authenticated:
                MainTabView()
            }
        }
        .alert(item: $container.presentedError) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("Entendido")))
        }
    }
}

private struct ConfigurationRequiredView: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            BrandMark()
            Image(systemName: "gear.badge.xmark")
                .font(.system(size: 42))
                .foregroundStyle(FFPSJColor.warning)
            Text("Configuración pendiente").font(.title2.weight(.bold))
            Text(message).multilineTextAlignment(.center).foregroundStyle(FFPSJColor.muted)
            Text("No se han creado datos de demostración.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FFPSJColor.blue)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ffpsjPageBackground()
    }
}

private struct RestrictedAccessView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(spacing: 16) {
            BrandMark()
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(FFPSJColor.warning)
            Text(container.currentUser?.deactivatedAt == nil ? "Acceso pendiente de habilitación" : "Cuenta deshabilitada")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(container.currentUser?.deactivatedAt == nil
                 ? "Tu cuenta fue creada, pero un administrador debe habilitarla."
                 : "Un administrador deshabilitó tu cuenta. Contacta con la Federación si crees que es un error.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FFPSJColor.muted)
            Button("Volver al acceso") { Task { await container.signOut() } }
                .buttonStyle(.borderedProminent)
                .tint(FFPSJColor.blue)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ffpsjPageBackground()
    }
}
