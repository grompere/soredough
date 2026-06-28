import SwiftUI

struct TagEditorView: View {
    @Binding var tags: [String]
    @State private var isJittering = false
    @State private var newTagText = ""
    @State private var isAddingTag = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if tags.isEmpty && !isAddingTag {
                    ContentUnavailableView {
                        Label("No Tags", systemImage: "tag")
                    } description: {
                        Text("Tap + to add your first tag.")
                    }
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            tagChip(tag)
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.default, value: tags)
                }

                if isAddingTag {
                    addTagField
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isAddingTag {
                            commitNewTag()
                        } else {
                            isAddingTag = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused = true
                            }
                        }
                    } label: {
                        Image(systemName: isAddingTag ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        isJittering = false
                        isAddingTag = false
                    }
                }
            }
            .onTapGesture {
                if isJittering {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isJittering = false
                    }
                }
            }
        }
    }

    // MARK: - Tag Chip

    private func tagChip(_ tag: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(tagColor(for: tag), in: RoundedRectangle(cornerRadius: 8))
                .rotationEffect(isJittering ? .degrees(1.5) : .zero)
                .animation(
                    isJittering
                        ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                        : .default,
                    value: isJittering
                )
                .onLongPressGesture {
                    withAnimation {
                        isJittering = true
                    }
                }

            if isJittering {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        tags.removeAll { $0 == tag }
                        if tags.isEmpty {
                            isJittering = false
                        }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .offset(x: 6, y: -6)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Add Tag Field

    private var addTagField: some View {
        HStack(spacing: 8) {
            TextField("Tag name", text: $newTagText)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                .focused($isTextFieldFocused)
                .onSubmit {
                    commitNewTag()
                }

            Button {
                isAddingTag = false
                newTagText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            withAnimation(.spring(response: 0.3)) {
                tags.append(trimmed)
            }
        }
        newTagText = ""
        isAddingTag = false
    }
}

#Preview {
    @Previewable @State var tags = ["Office", "Push Day"]
    TagEditorView(tags: $tags)
}
