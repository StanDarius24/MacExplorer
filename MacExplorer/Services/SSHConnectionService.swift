import Foundation
import Citadel
import Crypto
import NIO

/// Centralizes SSH/SFTP connectivity for the remote browsing pane. Wraps a
/// single `Citadel.SSHClient` + `SFTPClient` pair and exposes a simple
/// directory-listing API consumed by `RemotePaneViewModel`.
///
/// - Important: Host key validation currently uses `.acceptAnything()`, which
///   is **insecure** (no protection against MITM attacks). This is a known
///   limitation for v1; a future pass should offer trust-on-first-use or
///   known_hosts-based validation.
actor SSHConnectionService {
    enum AuthMethod {
        case password(String)
        /// `privateKeyText` is the raw contents of a PEM/OpenSSH private key file.
        case privateKey(privateKeyText: String, passphrase: String?)
    }

    struct Credentials {
        var host: String
        var port: Int = 22
        var username: String
        var authMethod: AuthMethod
    }

    enum ConnectionError: LocalizedError {
        case unsupportedKeyType(String)
        case invalidPrivateKey

        var errorDescription: String? {
            switch self {
            case .unsupportedKeyType(let type):
                return "Unsupported private key type: \(type). Only RSA and Ed25519 keys are supported."
            case .invalidPrivateKey:
                return "The private key could not be parsed. Check the key contents and passphrase."
            }
        }
    }

    private var client: SSHClient?
    private var sftp: SFTPClient?

    /// Opens an SSH connection and the associated SFTP subsystem.
    func connect(with credentials: Credentials) async throws {
        let authenticationMethod = try Self.makeAuthenticationMethod(
            username: credentials.username,
            method: credentials.authMethod
        )

        let sshClient = try await SSHClient.connect(
            host: credentials.host,
            port: credentials.port,
            authenticationMethod: authenticationMethod,
            hostKeyValidator: .acceptAnything(), // ⚠️ Insecure: see type documentation.
            reconnect: .never
        )

        let sftpClient = try await sshClient.openSFTP()

        self.client = sshClient
        self.sftp = sftpClient
    }

    /// Lists the contents of a remote directory, returning entries sorted
    /// directories-first then alphabetically (mirroring the local pane).
    func listDirectory(atPath path: String) async throws -> [RemoteFileItem] {
        guard let sftp else { throw SFTPError.connectionClosed }

        let normalizedPath = path.isEmpty ? "." : path
        let components = try await sftp.listDirectory(atPath: normalizedPath)

        let items = components
            .flatMap(\.components)
            .filter { $0.filename != "." && $0.filename != ".." }
            .map { RemoteFileItem(component: $0, parentPath: path) }

        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Resolves the server's canonical home/working directory, used as the
    /// initial path shown after connecting.
    func resolveHomeDirectory() async throws -> String {
        guard let sftp else { throw SFTPError.connectionClosed }
        return try await sftp.getRealPath(atPath: ".")
    }

    func disconnect() async {
        try? await sftp?.close()
        try? await client?.close()
        sftp = nil
        client = nil
    }

    var isConnected: Bool {
        client?.isConnected ?? false
    }

    private static func makeAuthenticationMethod(
        username: String,
        method: AuthMethod
    ) throws -> SSHAuthenticationMethod {
        switch method {
        case .password(let password):
            return .passwordBased(username: username, password: password)

        case .privateKey(let privateKeyText, let passphrase):
            let decryptionKey = passphrase?.data(using: .utf8)
            let keyType: SSHKeyType
            do {
                keyType = try SSHKeyDetection.detectPrivateKeyType(from: privateKeyText)
            } catch {
                throw ConnectionError.invalidPrivateKey
            }

            switch keyType {
            case .ed25519:
                let privateKey = try Curve25519.Signing.PrivateKey(
                    sshEd25519: privateKeyText,
                    decryptionKey: decryptionKey
                )
                return .ed25519(username: username, privateKey: privateKey)

            case .rsa:
                let privateKey = try Insecure.RSA.PrivateKey(
                    sshRsa: privateKeyText,
                    decryptionKey: decryptionKey
                )
                return .rsa(username: username, privateKey: privateKey)

            default:
                throw ConnectionError.unsupportedKeyType(keyType.description)
            }
        }
    }
}
