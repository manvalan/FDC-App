import SwiftUI
import Combine

struct AdminUserListView: View {
    @StateObject private var service = RailwayAIService.shared
    @State private var users: [AdminUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var showAddUser = false
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var isAdding = false
    
    // Auth Guidance
    @State private var showAuthError = false
    
    var body: some View {
        NavigationStack {
            List {
                if let error = errorMessage {
                    Section("error_status".localized) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        if error.contains("401") || error.contains("403") {
                            Text("auth_reset_suggestion".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                
                if users.isEmpty && !isLoading {
                    Text("no_users_found".localized)
                        .foregroundColor(.secondary)
                } else {
                    Section("system_users".localized) {
                        ForEach(users) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.username)
                                        .font(.headline)
                                    Text(user.is_active ? "active".localized : "inactive".localized)
                                        .font(.caption)
                                        .foregroundColor(user.is_active ? .green : .red)
                                }
                                Spacer()
                                
                                if user.username != "admin" {
                                    Button(role: .destructive) {
                                        deleteUser(user.username)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(.orange)
                                        .help("admin_protected".localized)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("user_management_title".localized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddUser = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        loadUsers()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("Errore", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showAddUser) {
                addUserSheet
            }
            .onAppear {
                loadUsers()
            }
        }
    }
    
    private var addUserSheet: some View {
        NavigationStack {
            Form {
                Section("new_user_credentials".localized) {
                    TextField("username".localized, text: $newUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("password".localized, text: $newPassword)
                }
            }
            .navigationTitle("add_user_title".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        showAddUser = false
                        resetAddForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        performAddUser()
                    }
                    .disabled(newUsername.isEmpty || newPassword.isEmpty || isAdding)
                }
            }
            .overlay {
                if isAdding {
                    ProgressView()
                }
            }
        }
    }
    
    private func loadUsers() {
        isLoading = true
        service.listUsers()
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { users in
                self.users = users
            }
            .store(in: &cancellables)
    }
    
    private func performAddUser() {
        isAdding = true
        service.addUser(username: newUsername, password: newPassword)
            .sink { completion in
                isAdding = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    showAddUser = false
                    resetAddForm()
                    loadUsers()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    private func deleteUser(_ username: String) {
        isLoading = true
        service.removeUser(username: username)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    loadUsers()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    private func resetAddForm() {
        newUsername = ""
        newPassword = ""
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}
