import SwiftUI
import SwiftData

/// 日历页：月视图网格 + 选中日详情（对齐 Android CalendarViewModel）
struct CalendarView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()

    private var aggregates: [String: DayAggregate] {
        aggregateDay(logs: logEntities.map { $0.toModel() },
                     emotions: emotionEntities.map { $0.toModel() })
    }

    private var weeks: [[Date]] { CalendarGrid.weeks(containing: displayedMonth) }
    private var selectedKey: String { DateFormatting.dayString(selectedDate) }

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("上一月")
                Text(monthTitle)
                    .font(.headline)
                    .frame(minWidth: 140)
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("下一月")
                Spacer()
                Button("回到今天") {
                    displayedMonth = Date()
                    selectedDate = Date()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // 星期表头
            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            // 月网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                      spacing: 4) {
                ForEach(weeks.flatMap { $0 }, id: \.self) { date in
                    dayCell(date)
                }
            }
            .padding(.horizontal, 16)

            Divider().padding(.vertical, 8)

            // 选中日详情
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(selectedKey) 详情")
                        .font(.headline)
                    if let aggregate = aggregates[selectedKey] {
                        if aggregate.emotions.isEmpty && aggregate.logs.isEmpty {
                            Text("这一天没有记录").foregroundStyle(.secondary)
                        }
                        ForEach(aggregate.emotions) { emotion in
                            Label("\(emotion.level.emoji) \(emotion.level.displayName)",
                                  systemImage: "face.smiling")
                                .font(.callout)
                        }
                        ForEach(aggregate.logs) { log in
                            LogCardView(log: log)
                        }
                    } else {
                        Text("这一天没有记录").foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: displayedMonth)
    }

    private func shiftMonth(_ delta: Int) {
        let calendar = Calendar(identifier: .gregorian)
        displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth)!
    }

    private func dayCell(_ date: Date) -> some View {
        let key = DateFormatting.dayString(date)
        let inMonth = CalendarGrid.monthString(date) == CalendarGrid.monthString(displayedMonth)
        let isToday = key == DateFormatting.today()
        let isSelected = key == selectedKey
        let aggregate = aggregates[key]

        return Button {
            selectedDate = date
            // 选中溢出天时跟随切换月份（对齐 Android selectDate）
            if !inMonth { displayedMonth = date }
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar(identifier: .gregorian).component(.day, from: date))")
                    .font(.callout)
                    .foregroundStyle(inMonth ? Color.primary : Color.secondary.opacity(0.5))
                HStack(spacing: 3) {
                    if let count = aggregate?.logs.count, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(Color(nsColor: .controlAccentColor))
                    }
                    if let emoji = aggregate?.emotions.first?.level.emoji {
                        Text(emoji).font(.caption2)
                    }
                }
                .frame(height: 14)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor)
                                   : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .controlAccentColor), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key)
    }
}
