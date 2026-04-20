//
//  AccountUsageHistoryView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct AccountUsageHistoryView: View {
    let quarterlyAllowance: Int
    let usageEntries: [MemberDayUsage]

    private var totalDaysUsed: Int {
        usageEntries.reduce(0) { $0 + $1.daysUsed }
    }

    private var remainingDays: Int {
        max(quarterlyAllowance - totalDaysUsed, 0)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summarySection
                usageHistorySection
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .navigationTitle("Usage History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quarter Summary")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                summaryChip(title: "Allowance", value: "\(quarterlyAllowance)")
                summaryChip(title: "Used", value: "\(totalDaysUsed)")
                summaryChip(title: "Left", value: "\(remainingDays)")
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var usageHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Days Used")
                .font(.title2)
                .fontWeight(.semibold)

            if usageEntries.isEmpty {
                Text("No days have been used this quarter.")
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(usageEntries.sorted(by: { $0.startDate > $1.startDate })) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(.headline)

                                Text(entry.usedFor)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.72))

                                Text("\(dateFormatter.string(from: entry.startDate)) – \(dateFormatter.string(from: entry.endDate))")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Text("\(entry.daysUsed) day\(entry.daysUsed == 1 ? "" : "s")")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 8)

                    if entry.id != usageEntries.sorted(by: { $0.startDate > $1.startDate }).last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        AccountUsageHistoryView(
            quarterlyAllowance: 30,
            usageEntries: [
                MemberDayUsage(
                    id: UUID(),
                    title: "Moab Weekend",
                    usedFor: "Club reservation",
                    startDate: Date(),
                    endDate: Date(),
                    daysUsed: 3
                )
            ]
        )
    }
}
