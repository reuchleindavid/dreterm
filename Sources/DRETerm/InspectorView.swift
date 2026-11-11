import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if let id = store.selectedID, let s = store.binding(for: id) {
            let rt = store.runtime[id] ?? SessionRuntime()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        header("Sitzung")
                        TextField("Name", text: s.name)
                            .textFieldStyle(.roundedBorder)
                        colorGrid(s.color)
                        iconGrid(s.icon)
                        Toggle("Angeheftet", isOn: s.pinned)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        header("Notizen")
                        TextEditor(text: s.notes)
                            .font(.system(size: 12))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .frame(minHeight: 160)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        header("Details")
                        info("Ordner", s.wrappedValue.directory.abbreviatingHome)
                        info("Prozess", rt.isShellIdle ? "Shell (bereit)" : rt.process)
                        info("Größe", "\(rt.cols) × \(rt.rows)")
                        if !rt.title.isEmpty { info("Titel", rt.title) }
                        info("Erstellt", s.wrappedValue.createdAt.formatted(date: .abbreviated, time: .shortened))
                        HStack {
                            Button("Im Finder") { store.revealInFinder(id) }
                            Button("Pfad kopieren") { store.copyPath(id) }
                        }
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }
                .padding(16)
            }
        } else {
            Text("Keine Sitzung").foregroundStyle(.secondary)
        }
    }

    private func header(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    private func info(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Text(v).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
        }
        .font(.system(size: 12))
    }

    private func colorGrid(_ sel: Binding<TabColor>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 8), count: 8), alignment: .leading, spacing: 8) {
            ForEach(TabColor.allCases) { c in
                Circle()
                    .fill(c == .none ? Color.clear : c.color)
                    .overlay(Circle().strokeBorder(c == .none ? Color.secondary : .clear, style: StrokeStyle(lineWidth: 1, dash: [2])))
                    .overlay(Circle().strokeBorder(.white, lineWidth: sel.wrappedValue == c ? 2 : 0))
                    .frame(width: 18, height: 18)
                    .onTapGesture { sel.wrappedValue = c }
                    .help(c.label)
            }
        }
    }

    private func iconGrid(_ sel: Binding<String>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 4), count: 8), alignment: .leading, spacing: 4) {
            ForEach(SessionIcons.all, id: \.self) { name in
                Image(systemName: name)
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(sel.wrappedValue == name ? store.theme.accentColor.opacity(0.3) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onTapGesture { sel.wrappedValue = name }
            }
        }
    }
}
