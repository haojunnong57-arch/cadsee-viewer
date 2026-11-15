import SwiftUI

struct FileRow: View {
    let record: FileRecord

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [record.kind.tint.opacity(0.95), record.kind.tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: record.kind.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(record.kind.displayName) · \(record.sizeText) · \(record.dateText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
