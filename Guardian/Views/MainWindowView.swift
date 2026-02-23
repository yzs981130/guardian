import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var store: ProcessStore
    @State private var selectedID: UUID?
    @State private var showAddSheet = false

    private var selectedConfig: ProcessConfig? {
        store.processes.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            ProcessListView(selectedID: $selectedID, showAddSheet: $showAddSheet)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let config = selectedConfig {
                ProcessDetailView(config: config)
                    .id(config.id) // Force recreation when selection changes
            } else {
                emptyState
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.refreshAllStatuses() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button { showAddSheet = true } label: {
                    Label("Add Process", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .navigation) {
                NavigationLink {
                    SettingsView()
                        .environmentObject(store)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditProcessView(mode: .add)
                .environmentObject(store)
        }
        .task {
            await store.onAppLaunch()
        }
        // Show banner for store errors
        .overlay(alignment: .bottom) {
            if let msg = store.errorMessage {
                errorBanner(msg)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Process Selected", systemImage: "shield")
        } description: {
            Text("Select a process from the sidebar, or add a new one.")
        } actions: {
            Button("Add Process") { showAddSheet = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button("Dismiss") { store.errorMessage = nil }
                .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
