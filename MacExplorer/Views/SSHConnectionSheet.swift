import SwiftUI
import UniformTypeIdentifiers

/// Modal sheet for entering SSH connection details, supporting both
/// password and private-key (RSA/Ed25519) authentication.
struct SSHConnectionSheet: View {
    enum AuthKind: String, CaseIterable, Identifiable {
        case password = "Password"
        case privateKey = "Private Key"
        var id: String { rawValue }
    }

    @Binding var isPresented: Bool
    let onConnect: (SSHConnectionService.Credentials) -> Void

    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var authKind: AuthKind = .password
    @State private var password: String = ""
    @State private var privateKeyText: String = ""
    @State private var passphrase: String = ""
    @State private var showFileImporter = false
    @State private var validationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect to SSH Server")
                .font(.headline)

            Form {
                TextField("Host", text: $host)
                TextField("Port", text: $port)
                TextField("Username", text: $username)

                Picker("Authentication", selection: $authKind) {
                    ForEach(AuthKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                switch authKind {
                case .password:
                    SecureField("Password", text: $password)

                case .privateKey:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Private Key")
                            Spacer()
                            Button("Choose File\u{2026}") { showFileImporter = true }
                        }
                        TextEditor(text: $privateKeyText)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 120)
                            .border(Color.secondary.opacity(0.3))
                        SecureField("Passphrase (optional)", text: $passphrase)
                    }
                }
            }

            if let validationError {
                Text(validationError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Connect") { attemptConnect() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                privateKeyText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }
        }
    }

    private func attemptConnect() {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Host is required."
            return
        }
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Username is required."
            return
        }
        guard let portNumber = Int(port), portNumber > 0 else {
            validationError = "Port must be a positive number."
            return
        }

        let authMethod: SSHConnectionService.AuthMethod
        switch authKind {
        case .password:
            guard !password.isEmpty else {
                validationError = "Password is required."
                return
            }
            authMethod = .password(password)

        case .privateKey:
            guard !privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                validationError = "Private key contents are required."
                return
            }
            authMethod = .privateKey(
                privateKeyText: privateKeyText,
                passphrase: passphrase.isEmpty ? nil : passphrase
            )
        }

        validationError = nil
        let credentials = SSHConnectionService.Credentials(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNumber,
            username: username.trimmingCharacters(in: .whitespaces),
            authMethod: authMethod
        )
        isPresented = false
        onConnect(credentials)
    }
}
