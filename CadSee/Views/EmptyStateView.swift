import SwiftUI

struct EmptyStateView: View {
    @Binding var showImporter: Bool

    private let formatChips = ["STL", "OBJ", "PLY", "STEP", "IGES", "glTF", "3MF", "DXF", "PDF", "SVG", "图片"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.18), Color.indigo.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 62, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                VStack(spacing: 8) {
                    Text("还没有文件")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("导入 STL、STEP、DXF、PDF 等文件\n即可开始查看")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                FlowChips(items: formatChips)
                    .padding(.horizontal, 32)
                Button {
                    showImporter = true
                } label: {
                    Label("导入文件", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// 简单的自动换行标签流
struct FlowChips: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            ForEach(layoutRows(), id: \.self) { rowItems in
                HStack(spacing: 6) {
                    ForEach(rowItems, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }

    private func layoutRows() -> [[String]] {
        var rows: [[String]] = [[]]
        var width: CGFloat = 0
        let maxWidth: CGFloat = 320
        for item in items {
            let itemWidth = CGFloat(item.count) * 9 + 26
            if width + itemWidth > maxWidth {
                rows.append([])
                width = 0
            }
            rows[rows.count - 1].append(item)
            width += itemWidth + 6
        }
        return rows
    }
}
