import SwiftUI

/// Language selection picker with search and grouping by region
struct LanguagePickerView: View {
    @Binding var selectedLanguage: Language
    @State private var searchText = ""
    @State private var showingPopover = false
    
    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedLanguage.displayName)
                        .font(.body)
                    Text("Code: \(selectedLanguage.code)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
            LanguageListView(
                selectedLanguage: $selectedLanguage,
                searchText: $searchText,
                onSelection: { _ in showingPopover = false }
            )
            .frame(width: 300, height: 400)
        }
    }
}

/// List view for language selection with search
struct LanguageListView: View {
    @Binding var selectedLanguage: Language
    @Binding var searchText: String
    let onSelection: (Language) -> Void
    
    private var groupedLanguages: [(region: String, languages: [Language])] {
        let filtered = Language.allCases.filter { language in
            searchText.isEmpty ||
            language.displayName.localizedCaseInsensitiveContains(searchText) ||
            language.code.localizedCaseInsensitiveContains(searchText)
        }
        
        // Group languages by region
        let groups = Dictionary(grouping: filtered) { language in
            regionForLanguage(language)
        }
        
        return groups.sorted { $0.key < $1.key }.map { (region: $0.key, languages: $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search languages...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Language list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedLanguages, id: \.region) { group in
                            // Region header
                            Text(group.region)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor))
                            
                            // Languages in region
                            ForEach(group.languages, id: \.self) { language in
                                LanguageRow(
                                    language: language,
                                    isSelected: language == selectedLanguage,
                                    action: {
                                        selectedLanguage = language
                                        onSelection(language)
                                    }
                                )
                                .id(language)
                            }
                        }
                    }
                }
                .onAppear {
                    // Scroll to selected language
                    proxy.scrollTo(selectedLanguage, anchor: .center)
                }
            }
        }
    }
    
    private func regionForLanguage(_ language: Language) -> String {
        switch language {
        case .english, .french, .german, .italian, .spanish, .portuguese, .dutch:
            return "European Languages"
        case .chinese, .japanese, .korean, .vietnamese, .thai, .indonesian, .malay, .tagalog:
            return "Asian Languages"
        case .arabic, .hebrew, .turkish:
            return "Middle Eastern Languages"
        case .russian, .polish, .czech, .ukrainian, .romanian, .hungarian:
            return "Eastern European Languages"
        case .swedish, .norwegian, .danish, .finnish:
            return "Nordic Languages"
        case .greek:
            return "Mediterranean Languages"
        case .hindi:
            return "South Asian Languages"
        }
    }
}

/// Individual language row
struct LanguageRow: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(language.code.uppercased())
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovering {
            return Color(NSColor.controlBackgroundColor)
        } else {
            return Color.clear
        }
    }
}

/// Compact language picker for inline use
struct CompactLanguagePicker: View {
    @Binding var selectedLanguage: Language
    
    var body: some View {
        Menu {
            ForEach(Language.allCases, id: \.self) { language in
                Button(action: { selectedLanguage = language }) {
                    HStack {
                        Text(language.displayName)
                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text(selectedLanguage.displayName)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - Preview

struct LanguagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Full picker
            LanguagePickerView(selectedLanguage: .constant(.english))
                .frame(width: 300)
            
            // Compact picker
            CompactLanguagePicker(selectedLanguage: .constant(.english))
            
            // Language list preview
            LanguageListView(
                selectedLanguage: .constant(.english),
                searchText: .constant(""),
                onSelection: { _ in }
            )
            .frame(width: 300, height: 400)
        }
        .padding()
    }
}