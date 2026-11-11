import Foundation
import Supabase

public struct SupabaseConfiguration: Sendable {
    public let url: URL
    public let publishableKey: String

    public init(url: URL, publishableKey: String) {
        self.url = url
        self.publishableKey = publishableKey
    }

    /// Lee una clave pública del bundle. Nunca acepta service_role ni secretos de servidor.
    public static func load(bundle: Bundle = .main) throws -> SupabaseConfiguration {
        guard let file = bundle.url(forResource: "SupabaseConfig", withExtension: "plist"),
              let values = NSDictionary(contentsOf: file) as? [String: String],
              let urlString = values["SupabaseURL"],
              let url = URL(string: urlString),
              let key = values["SupabasePublishableKey"],
              !key.isEmpty,
              !key.contains("service_role") else {
            throw ConfigurationError.missingSupabaseConfiguration
        }
        return SupabaseConfiguration(url: url, publishableKey: key)
    }

    public func makeClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
    }
}

public enum ConfigurationError: LocalizedError, Sendable {
    case missingSupabaseConfiguration

    public var errorDescription: String? {
        "Falta Resources/SupabaseConfig.plist. Copia el ejemplo y configura solo la URL y la clave pública de Supabase."
    }
}
