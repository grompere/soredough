import SwiftUI

struct ExportFormatListView: View {
    @ObservedObject private var store = ExportFormatStore.shared
    @State private var showEditor = false

    var body: some View {
        List {
            if store.formats.isEmpty {
                ContentUnavailableView {
                    Label("No Cookie Cutters", systemImage: "rectangle.3.group")
                } description: {
                    Text("Add a custom export format to shape your workout data.")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(store.formats) { format in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(format.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(format.columns, id: \.self) { col in
                                    Text(col)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Color(.systemGray5),
                                            in: Capsule()
                                        )
                                }
                            }
                        }

                        Text("Separator: \(format.separator == "|" ? "pipe |" : "comma ,")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    store.delete(at: offsets)
                }
            }
        }
        .navigationTitle("Cookie Cutters 🍪")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ExportFormatEditorView(store: store)
        }
    }
}

#Preview {
    NavigationStack {
        ExportFormatListView()
    }
}
