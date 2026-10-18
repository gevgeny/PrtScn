import SwiftUI

// Action × key matrix. One action per key.
struct KeyMatrix: View {
    @State var assignment = Bindings.all

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text("Press a key once to capture")
                ForEach(TriggerKey.allCases) { Text($0.rawValue).gridColumnAlignment(.center) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            ForEach(Action.allCases, id: \.self) { action in
                GridRow {
                    Text(action.rawValue).padding(.trailing, 16)
                    ForEach(TriggerKey.allCases) { key in
                        let on = assignment[key] == action
                        Button { assignment[key] = on ? nil : action } label: {
                            Text(on ? key.glyph : "")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 26)
                                .background(on ? Color.accentColor : .clear, in: .rect(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? .clear : .secondary.opacity(0.5)))
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onChange(of: assignment) { _, new in
            print("[PrtScn] bindings -> \(new)")
            Bindings.all = new
        }
    }
}
