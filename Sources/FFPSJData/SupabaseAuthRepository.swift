import FFPSJDomain
import Foundation
import Supabase

public actor SupabaseAuthRepository: AuthRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func restoreSession() async throws -> UUID? {
        guard let session = try? await client.auth.session else { return nil }
        return session.user.id
    }

    public func signIn(email: String, password: String) async throws -> UUID {
        let response = try await client.auth.signIn(email: email, password: password)
        return response.user.id
    }

    public func signUp(fullName: String, email: String, password: String) async throws {
        _ = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
    }

    public func signOut() async throws {
        try await client.auth.signOut(scope: .local)
    }

    public func recoverPassword(email: String, redirectURL: URL) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: redirectURL)
    }

    public func currentUser(id: UUID) async throws -> AppUser {
        try await client
            .from("users")
            .select("id,email,role,status,deactivated_at,profile:profiles(full_name,avatar_url)")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }
}
