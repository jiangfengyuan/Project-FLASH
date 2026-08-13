import SwiftUI

/// 日志卡片（Home/LogFlow/Explore/Calendar 复用）。内容层：纯色卡片，无玻璃（spec §10.3）。
struct LogCardView: View {
    let log: LogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(BrandColors.tagColor(log.colorTag))
                    .frame(width: 8, height: 8)
                Text(log.colorTag.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if log.importance > 0 {
                    Text(String(repeating: "!", count: log.importance))
                        .font(.caption).bold()
                        .foregroundStyle(BrandColors.tagColor(.urgent))
                }
                Spacer()
                Text(log.recordDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(log.content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
