import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var container: AppContainer

    private enum Mode: String {
        case signIn, signUp, recovery
    }

    @State private var mode: Mode = .signIn
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 13) {
                    BrandMark()
                    Text("GESTOR OFICIAL DE ACTAS")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(FFPSJColor.blue)
                    Text(title).font(.largeTitle.weight(.bold)).foregroundStyle(FFPSJColor.ink)
                    Text(subtitle).foregroundStyle(FFPSJColor.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SectionCard {
                    VStack(spacing: 16) {
                        if mode == .signUp {
                            TextField("Nombre completo", text: $fullName)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .ffpsjField()
                        }
                        TextField("Correo electrónico", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .ffpsjField()
                        if mode != .recovery {
                            SecureField("Contraseña (mín. 8 caracteres)", text: $password)
                                .textContentType(mode == .signUp ? .newPassword : .password)
                                .ffpsjField()
                        }
                        if let message {
                            Label(message, systemImage: "checkmark.shield")
                                .font(.footnote)
                                .foregroundStyle(FFPSJColor.success)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button(actionLabel) { Task { await submit() } }
                            .buttonStyle(.borderedProminent)
                            .tint(FFPSJColor.blue)
                            .frame(maxWidth: .infinity)
                            .disabled(isSubmitting)
                    }
                }

                HStack(spacing: 8) {
                    if mode == .signIn {
                        Button("¿Olvidaste tu contraseña?") { mode = .recovery }
                        Text("·").foregroundStyle(FFPSJColor.muted)
                        Button("Crear una cuenta") { mode = .signUp }
                    } else {
                        Button("Volver al inicio de sesión") { mode = .signIn; message = nil }
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FFPSJColor.blue)

                Label("Acceso protegido y auditado con Supabase", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(FFPSJColor.muted)
            }
            .padding(24)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .ffpsjPageBackground()
    }

    private var title: String {
        switch mode {
        case .signIn: "Bienvenido de nuevo"
        case .signUp: "Crea tu acceso"
        case .recovery: "Recupera tu cuenta"
        }
    }

    private var subtitle: String {
        switch mode {
        case .signIn: 
            return "Ingresa para gestionar partidos y actas oficiales."
        case .signUp:
            return "Solicita acceso al sistema oficial de actas."
        case .recovery:
            return "Te enviaremos un enlace seguro para continuar."
        }
    }

    private var actionLabel: String {
        if isSubmitting { return "Procesando…" }
        switch mode {
        case .signIn: return "Iniciar sesión"
        case .signUp: return "Solicitar acceso"
        case .recovery: return "Enviar enlace"
        }
    }

    private func submit() async {
        guard email.contains("@") else {
            container.presentedError = UserFacingError(title: "Correo no válido", message: "Ingresa un correo electrónico válido.")
            return
        }
        if mode != .recovery, password.count < 8 {
            container.presentedError = UserFacingError(title: "Contraseña insuficiente", message: "La contraseña debe tener al menos 8 caracteres.")
            return
        }
        if mode == .signUp, fullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            container.presentedError = UserFacingError(title: "Nombre requerido", message: "Indica nombre y apellido.")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch mode {
            case .signIn:
                await container.signIn(email: email, password: password)
            case .signUp:
                try await container.requestAccount(fullName: fullName, email: email, password: password)
                message = "Cuenta creada. Confirma tu correo; un administrador debe habilitarla."
            case .recovery:
                try await container.recoverPassword(email: email)
                message = "Revisa tu correo para continuar con el restablecimiento."
            }
        } catch {
            container.presentedError = UserFacingError(error)
        }
    }
}

private extension View {
    func ffpsjField() -> some View {
        padding(12)
            .background(FFPSJColor.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(FFPSJColor.border, lineWidth: 1))
    }
}
