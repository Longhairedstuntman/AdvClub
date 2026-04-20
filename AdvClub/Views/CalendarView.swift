//
//  CalendarView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct CalendarView: View {
    @State private var selectedScope: CalendarScope = .month
    @State private var selectedFilter: CalendarFilter = .all
    @State private var selectedDisplayStyle: CalendarDisplayStyle = .dots
    @State private var selectedMonthIndex: Int = 0
    @State private var selectedDay: CalendarDay?
    @State private var isPresentingReservationForm = false
    @State private var isPresentingAdminEntryForm = false
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var resourceManager: ResourceManager
    @EnvironmentObject private var reservationManager: ReservationManager
    @EnvironmentObject private var calendarEntryManager: CalendarEntryManager

    private let months: [CalendarMonth] = [
        CalendarMonth.makeMonth(offsetFromCurrent: 0),
        CalendarMonth.makeMonth(offsetFromCurrent: 1)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                scopePickerSection
                displayStyleSection

                if selectedScope == .month {
                    calendarCardSection
                } else {
                    agendaSection
                }

                filterSection
                legendSection
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Color.appBackgroundColor)
        .task {
            calendarEntryManager.startListeningPublishedEntries()
            reservationManager.startListeningForCurrentUserReservations()
        }
        .toolbar {
            if sessionManager.isMember || sessionManager.isAdmin {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if sessionManager.isAdmin {
                            isPresentingAdminEntryForm = true
                        } else {
                            isPresentingReservationForm = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .sheet(item: $selectedDay) { day in
            CalendarDayDetailSheet(
                day: day,
                monthTitle: currentMonth.title,
                visibleItems: filteredItems(for: mergedItems(for: day, month: currentMonth)),
                isAdmin: sessionManager.isAdmin,
                isMember: sessionManager.isMember
            )
        }
        .sheet(isPresented: $isPresentingReservationForm) {
            CalendarReservationFormSheet(
                prefilledDateTitle: defaultSelectedDateTitle,
                initialDate: defaultSelectedDate
            )
        }
        .sheet(isPresented: $isPresentingAdminEntryForm) {
            AdminCalendarEntrySheet(
                prefilledDateTitle: defaultSelectedDateTitle,
                initialDate: defaultSelectedDate
            )
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Calendar")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Track your reserved days, upcoming club events, and shared availability for club vehicles or group resources.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            if sessionManager.isMember || sessionManager.isAdmin {
                Button {
                    if sessionManager.isAdmin {
                        isPresentingAdminEntryForm = true
                    } else {
                        isPresentingReservationForm = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scopePickerSection: some View {
        Picker("Calendar Scope", selection: $selectedScope) {
            ForEach(CalendarScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var displayStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar Display")
                .font(.title3)
                .fontWeight(.semibold)

            Picker("Calendar Display Style", selection: $selectedDisplayStyle) {
                ForEach(CalendarDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var calendarCardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentMonth.title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Swipe horizontally to move between months")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 10) {
                    calendarChevronButton(systemImage: "chevron.left", direction: -1)
                    calendarChevronButton(systemImage: "chevron.right", direction: 1)
                }
            }

            TabView(selection: $selectedMonthIndex) {
                ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                    monthGrid(for: month)
                        .tag(index)
                }
            }
            .frame(height: 360)
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func monthGrid(for month: CalendarMonth) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }

            ForEach(month.days) { day in
                calendarDayCell(day, month: month)
            }
        }
    }

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentMonth.title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Agenda view for the currently selected month")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 10) {
                    calendarChevronButton(systemImage: "chevron.left", direction: -1)
                    calendarChevronButton(systemImage: "chevron.right", direction: 1)
                }
            }

            if filteredAgendaItems.isEmpty {
                Text("No matching items for this month.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ForEach(filteredAgendaItems) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(item.category.color)
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)

                            Text(item.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))

                            Text(item.dateText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)

                    if item.id != filteredAgendaItems.last?.id {
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

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to Show")
                .font(.title3)
                .fontWeight(.semibold)

            Picker("Calendar Filter", selection: $selectedFilter) {
                ForEach(CalendarFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Legend")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                legendRow(title: "Your Reservation", subtitle: "Days reserved by you", color: CalendarItemCategory.myReservation.color)
                legendRow(title: "Club Event", subtitle: "Visible to all members", color: CalendarItemCategory.event.color)
                legendRow(title: "Reserved", subtitle: "Something is reserved, but member identity stays private", color: CalendarItemCategory.groupReservation.color)
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

    private var currentMonth: CalendarMonth {
        months[selectedMonthIndex]
    }
    
    private var defaultSelectedDateTitle: String {
        if let selectedDay, let dayNumber = selectedDay.number {
            let monthName = currentMonth.title.split(separator: " ").first.map(String.init) ?? currentMonth.title
            return "\(monthName) \(dayNumber)"
        }

        if let today = currentMonth.days.first(where: { $0.isToday }), let dayNumber = today.number {
            let monthName = currentMonth.title.split(separator: " ").first.map(String.init) ?? currentMonth.title
            return "\(monthName) \(dayNumber)"
        }

        return currentMonth.title
    }
    
    private var defaultSelectedDate: Date {
        if let selectedDay, let dayNumber = selectedDay.number {
            let parts = currentMonth.title.split(separator: " ")
            if parts.count >= 2 {
                let monthName = String(parts[0])
                let yearString = String(parts[1])
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "MMMM d yyyy"
                return formatter.date(from: "\(monthName) \(dayNumber) \(yearString)") ?? Date()
            }
        }

        if let today = currentMonth.days.first(where: { $0.isToday }), let dayNumber = today.number {
            let parts = currentMonth.title.split(separator: " ")
            if parts.count >= 2 {
                let monthName = String(parts[0])
                let yearString = String(parts[1])
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "MMMM d yyyy"
                return formatter.date(from: "\(monthName) \(dayNumber) \(yearString)") ?? Date()
            }
        }

        return Date()
    }

    private var filteredAgendaItems: [CalendarListItem] {
        let staticItems = currentMonth.days.flatMap { $0.items }
        let dynamicCalendarEntries = firebaseItems(for: currentMonth)
        let memberReservationItems = reservationItems(for: currentMonth)
        return filteredItems(for: staticItems + dynamicCalendarEntries + memberReservationItems)
    }

    private func firebaseItems(for month: CalendarMonth) -> [CalendarListItem] {
        calendarEntryManager.entries.compactMap { entry in
            guard entryBelongsToMonth(entry, month: month) else { return nil }
            return makeCalendarListItem(from: entry)
        }
    }

    private func reservationItems(for month: CalendarMonth) -> [CalendarListItem] {
        reservationManager.reservations.compactMap { reservation in
            guard reservationBelongsToMonth(reservation, month: month) else { return nil }
            return makeCalendarListItem(from: reservation)
        }
    }

    private func reservationItems(forDayNumber dayNumber: Int?, month: CalendarMonth) -> [CalendarListItem] {
        guard let dayNumber else { return [] }

        return reservationManager.reservations.compactMap { reservation in
            guard reservationContainsDay(reservation, dayNumber: dayNumber, month: month) else { return nil }
            return makeCalendarListItem(from: reservation)
        }
    }

    private func mergedItems(for day: CalendarDay, month: CalendarMonth) -> [CalendarListItem] {
        day.items
        + firebaseItems(forDayNumber: day.number, month: month)
        + reservationItems(forDayNumber: day.number, month: month)
    }

    private func firebaseItems(forDayNumber dayNumber: Int?, month: CalendarMonth) -> [CalendarListItem] {
        guard let dayNumber else { return [] }

        return calendarEntryManager.entries.compactMap { entry in
            guard entryContainsDay(entry, dayNumber: dayNumber, month: month) else { return nil }
            return makeCalendarListItem(from: entry)
        }
    }

    private func effectiveCategories(for day: CalendarDay, month: CalendarMonth) -> [CalendarItemCategory] {
        let firebaseCategories = firebaseItems(forDayNumber: day.number, month: month).map(\.category)
        let reservationCategories = reservationItems(forDayNumber: day.number, month: month).map(\.category)
        return Array((day.categories + firebaseCategories + reservationCategories).prefix(3))
    }

    private func entryBelongsToMonth(_ entry: CalendarEntryRecord, month: CalendarMonth) -> Bool {
        let parts = month.title.split(separator: " ")
        guard parts.count >= 2,
              let monthIndex = monthNumber(from: String(parts[0])),
              let year = Int(parts[1]) else {
            return false
        }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month], from: entry.startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: entry.endDate)

        let startYear = startComponents.year ?? 0
        let startMonth = startComponents.month ?? 0
        let endYear = endComponents.year ?? 0
        let endMonth = endComponents.month ?? 0

        if startYear == year && startMonth == monthIndex { return true }
        if endYear == year && endMonth == monthIndex { return true }

        if let monthStart = calendar.date(from: DateComponents(year: year, month: monthIndex, day: 1)),
           let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) {
            return entry.startDate <= monthEnd && entry.endDate >= monthStart
        }

        return false
    }

    private func entryContainsDay(_ entry: CalendarEntryRecord, dayNumber: Int, month: CalendarMonth) -> Bool {
        let parts = month.title.split(separator: " ")
        guard parts.count >= 2,
              let monthIndex = monthNumber(from: String(parts[0])),
              let year = Int(parts[1]),
              let date = Calendar.current.date(from: DateComponents(year: year, month: monthIndex, day: dayNumber)) else {
            return false
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            return false
        }

        return entry.startDate <= endOfDay && entry.endDate >= startOfDay
    }

    private func reservationBelongsToMonth(_ reservation: ReservationRecord, month: CalendarMonth) -> Bool {
        let parts = month.title.split(separator: " ")
        guard parts.count >= 2,
              let monthIndex = monthNumber(from: String(parts[0])),
              let year = Int(parts[1]) else {
            return false
        }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month], from: reservation.startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: reservation.endDate)

        let startYear = startComponents.year ?? 0
        let startMonth = startComponents.month ?? 0
        let endYear = endComponents.year ?? 0
        let endMonth = endComponents.month ?? 0

        if startYear == year && startMonth == monthIndex { return true }
        if endYear == year && endMonth == monthIndex { return true }

        if let monthStart = calendar.date(from: DateComponents(year: year, month: monthIndex, day: 1)),
           let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) {
            return reservation.startDate <= monthEnd && reservation.endDate >= monthStart
        }

        return false
    }

    private func reservationContainsDay(_ reservation: ReservationRecord, dayNumber: Int, month: CalendarMonth) -> Bool {
        let parts = month.title.split(separator: " ")
        guard parts.count >= 2,
              let monthIndex = monthNumber(from: String(parts[0])),
              let year = Int(parts[1]),
              let date = Calendar.current.date(from: DateComponents(year: year, month: monthIndex, day: dayNumber)) else {
            return false
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            return false
        }

        return reservation.startDate <= endOfDay && reservation.endDate >= startOfDay
    }

    private func monthNumber(from monthName: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        guard let date = formatter.date(from: monthName) else { return nil }
        return Calendar.current.component(.month, from: date)
    }

    private func makeCalendarListItem(from entry: CalendarEntryRecord) -> CalendarListItem {
        let category: CalendarItemCategory
        switch entry.entryType {
        case .event:
            category = .event
        case .reservation, .block:
            category = .groupReservation
        }

        let subtitle: String
        switch entry.entryType {
        case .event:
            subtitle = "Club event"
        case .reservation:
            if let resourceName = entry.resourceName, resourceName.isEmpty == false {
                subtitle = "Reserved • \(resourceName)"
            } else {
                subtitle = "Reserved"
            }
        case .block:
            if let resourceName = entry.resourceName, resourceName.isEmpty == false {
                subtitle = "Blocked • \(resourceName)"
            } else {
                subtitle = "Blocked"
            }
        }

        let dateText: String
        if entry.isAllDay {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: entry.startDate)
            let end = formatter.string(from: entry.endDate)
            dateText = start == end ? start : "\(start) – \(end)"
        } else {
            if let startTimeText = entry.startTimeText, let endTimeText = entry.endTimeText {
                dateText = "\(startTimeText) – \(endTimeText)"
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "MMM d"
                dateText = formatter.string(from: entry.startDate)
            }
        }

        return CalendarListItem(
            title: entry.title,
            subtitle: subtitle,
            dateText: dateText,
            category: category
        )
    }

    private func makeCalendarListItem(from reservation: ReservationRecord) -> CalendarListItem {
        let dateText: String
        if reservation.isAllDay {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: reservation.startDate)
            let end = formatter.string(from: reservation.endDate)
            dateText = start == end ? start : "\(start) – \(end)"
        } else {
            if let startTimeText = reservation.startTimeText, let endTimeText = reservation.endTimeText {
                dateText = "\(startTimeText) – \(endTimeText)"
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "MMM d"
                dateText = formatter.string(from: reservation.startDate)
            }
        }

        return CalendarListItem(
            title: reservation.title,
            subtitle: "My reservation • \(reservation.resourceName)",
            dateText: dateText,
            category: .myReservation
        )
    }

    private func filteredItems(for items: [CalendarListItem]) -> [CalendarListItem] {
        switch selectedFilter {
        case .all:
            return items
        case .myReservations:
            return items.filter { $0.category == .myReservation }
        case .events:
            return items.filter { $0.category == .event }
        case .groupReservations:
            return items.filter { $0.category == .groupReservation }
        }
    }

    private func calendarChevronButton(systemImage: String, direction: Int) -> some View {
        Button {
            let newIndex = selectedMonthIndex + direction
            guard months.indices.contains(newIndex) else { return }
            selectedMonthIndex = newIndex
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func calendarDayCell(_ day: CalendarDay, month: CalendarMonth) -> some View {
        let categories = effectiveCategories(for: day, month: month)

        return Button {
            guard day.number != nil else { return }
            selectedDay = day
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(day.isToday ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                    .frame(height: 56)

                if selectedDisplayStyle == .highlight, categories.isEmpty == false {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(categories.first?.color.opacity(0.22) ?? Color.clear)
                        .frame(height: 56)
                }

                if let number = day.number {
                    Text("\(number)")
                        .font(.subheadline.weight(day.isToday ? .bold : .medium))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }

                if selectedDisplayStyle == .dots {
                    HStack(spacing: 4) {
                        ForEach(Array(categories.prefix(3).enumerated()), id: \.offset) { _, category in
                            Circle()
                                .fill(category.color)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }

                if selectedDisplayStyle == .bars {
                    VStack(spacing: 4) {
                        ForEach(Array(categories.prefix(3).enumerated()), id: \.offset) { _, category in
                            Capsule()
                                .fill(category.color)
                                .frame(width: 24, height: 4)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(day.number == nil)
    }

    private func legendRow(title: String, subtitle: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }
}

private struct CalendarDayDetailSheet: View {
    let day: CalendarDay
    let monthTitle: String
    let visibleItems: [CalendarListItem]
    let isAdmin: Bool
    let isMember: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingAddEventForm = false
    @State private var isPresentingReservationForm = false

    private var formattedDateTitle: String {
        guard let dayNumber = day.number else {
            return monthTitle
        }

        let monthName = monthTitle.split(separator: " ").first.map(String.init) ?? monthTitle
        return "\(monthName) \(dayNumber)"
    }

    private var initialDate: Date {
        guard let dayNumber = day.number else {
            return Date()
        }

        let parts = monthTitle.split(separator: " ")
        guard parts.count >= 2 else {
            return Date()
        }

        let monthName = String(parts[0])
        let yearString = String(parts[1])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d yyyy"

        return formatter.date(from: "\(monthName) \(dayNumber) \(yearString)") ?? Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(formattedDateTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    if isAdmin {
                        Button {
                            isPresentingAddEventForm = true
                        } label: {
                            Text("Add Entry")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    } else if isMember {
                        Button {
                            isPresentingReservationForm = true
                        } label: {
                            Text("Reserve")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    if visibleItems.isEmpty {
                        Text("No visible events or reservations for this day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleItems) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(item.category.color)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title)
                                        .font(.headline)

                                    Text(item.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text(item.dateText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.black)
                }
            }
            .sheet(isPresented: $isPresentingAddEventForm) {
                AdminCalendarEntrySheet(
                    prefilledDateTitle: formattedDateTitle,
                    initialDate: initialDate
                )
            }
            .sheet(isPresented: $isPresentingReservationForm) {
                CalendarReservationFormSheet(
                    prefilledDateTitle: formattedDateTitle,
                    initialDate: initialDate
                )
            }
        }
    }
}

private struct AdminCalendarEntrySheet: View {
    let prefilledDateTitle: String
    let initialDate: Date

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var resourceManager: ResourceManager
    @EnvironmentObject private var calendarEntryManager: CalendarEntryManager

    @State private var title = ""
    @State private var entryType: AdminCalendarEntryType = .event
    @State private var selectedResourceID: String = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = true
    @State private var startTime = "9:00 AM"
    @State private var endTime = "11:00 AM"
    @State private var notes = ""
    @State private var isPublished = true
    @State private var isSaving = false
    @State private var message: String?

    private var selectedResource: ReservableResourceItem? {
        enabledResources.first(where: { $0.id == selectedResourceID })
    }

    private var calendarEntryType: CalendarEntryType {
        switch entryType {
        case .event:
            return .event
        case .reservation:
            return .reservation
        case .block:
            return .block
        }
    }

    init(prefilledDateTitle: String, initialDate: Date) {
        self.prefilledDateTitle = prefilledDateTitle
        self.initialDate = initialDate
        _startDate = State(initialValue: initialDate)
        _endDate = State(initialValue: initialDate)
    }

    private var enabledResources: [ReservableResourceItem] {
        resourceManager.enabledResources
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendar Entry")
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        Text(prefilledDateTitle)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entry Type")
                            .font(.subheadline.weight(.semibold))

                        Picker("Entry Type", selection: $entryType) {
                            ForEach(AdminCalendarEntryType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.black)
                        .colorScheme(.dark)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline.weight(.semibold))

                        TextField("Enter title", text: $title)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if entryType != .event {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resource")
                                .font(.subheadline.weight(.semibold))

                            if enabledResources.isEmpty {
                                Text("No reservable resources are currently available.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                Picker("Resource", selection: $selectedResourceID) {
                                    ForEach(enabledResources) { resource in
                                        Text(resource.name).tag(resource.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Date")
                            .font(.subheadline.weight(.semibold))

                        DatePicker(
                            "Start Date",
                            selection: $startDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Date")
                            .font(.subheadline.weight(.semibold))

                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Toggle("All Day", isOn: $isAllDay)
                        .tint(.black)

                    if isAllDay == false {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Time")
                                    .font(.subheadline.weight(.semibold))

                                TextField("Start time", text: $startTime)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Time")
                                    .font(.subheadline.weight(.semibold))

                                TextField("End time", text: $endTime)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline.weight(.semibold))

                        TextEditor(text: $notes)
                            .foregroundStyle(.black)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Toggle("Publish immediately", isOn: $isPublished)
                        .tint(.black)

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await saveEntry()
                            }
                        } label: {
                            Text(isSaving ? "Saving..." : "Save Entry")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.black)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(isSaving || (entryType != .event && selectedResource == nil))

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if let message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(24)
            }
            .navigationTitle("Calendar Entry")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if selectedResourceID.isEmpty {
                    selectedResourceID = enabledResources.first?.id ?? ""
                }
            }
            .onChange(of: enabledResources) { _, newResources in
                if newResources.contains(where: { $0.id == selectedResourceID }) == false {
                    selectedResourceID = newResources.first?.id ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await saveEntry()
                        }
                    } label: {
                        Text(isSaving ? "Saving..." : "Save")
                    }
                    .disabled(isSaving || (entryType != .event && selectedResource == nil))
                    .foregroundStyle(.black)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.black)
                }
            }
        }
    }

    private func saveEntry() async {
        isSaving = true
        defer { isSaving = false }

        let result = await calendarEntryManager.createEntry(
            title: title,
            entryType: calendarEntryType,
            resourceID: entryType == .event ? nil : selectedResource?.id,
            resourceName: entryType == .event ? nil : selectedResource?.name,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            startTimeText: isAllDay ? nil : startTime,
            endTimeText: isAllDay ? nil : endTime,
            notes: notes,
            isPublished: isPublished
        )

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

private struct CalendarReservationFormSheet: View {
    let prefilledDateTitle: String
    let initialDate: Date

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var resourceManager: ResourceManager
    @EnvironmentObject private var reservationManager: ReservationManager
    @EnvironmentObject private var calendarEntryManager: CalendarEntryManager

    @State private var showingConflictAlert = false
    @State private var conflictMessage = ""
    @State private var reservationTitle = ""
    @State private var selectedResourceID: String = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = true
    @State private var startTime = "9:00 AM"
    @State private var endTime = "5:00 PM"
    @State private var notes = ""
    @State private var isSaving = false
    @State private var message: String?

    init(prefilledDateTitle: String, initialDate: Date) {
        self.prefilledDateTitle = prefilledDateTitle
        self.initialDate = initialDate
        _startDate = State(initialValue: initialDate)
        _endDate = State(initialValue: initialDate)
    }

    private var enabledResources: [ReservableResourceItem] {
        resourceManager.enabledResources
    }

    private var selectedResource: ReservableResourceItem? {
        enabledResources.first(where: { $0.id == selectedResourceID })
    }

    private var selectedReservationMode: ReservationMode {
        guard let selectedResource else { return .daily }
        return selectedResource.name == "Golf Simulator" ? .hourly : .daily
    }

    private var countsTowardQuarterlyDays: Bool {
        guard let selectedResource else { return false }

        let normalizedName = selectedResource.name.lowercased()
        return normalizedName == "car"
            || normalizedName == "cars"
            || normalizedName == "boat"
            || normalizedName == "boats"
            || normalizedName == "side by side"
            || normalizedName == "side-by-side"
            || normalizedName == "side by sides"
            || normalizedName == "side-by-sides"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                reservationFormContent
                    .padding(24)
            }
            .navigationTitle("Add Reservation")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if selectedResourceID.isEmpty {
                    selectedResourceID = enabledResources.first?.id ?? ""
                }
            }
            .onChange(of: enabledResources) { _, newResources in
                if newResources.contains(where: { $0.id == selectedResourceID }) == false {
                    selectedResourceID = newResources.first?.id ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await saveReservation()
                        }
                    } label: {
                        Text(isSaving ? "Saving..." : "Reserve")
                    }
                    .disabled(isSaving || selectedResource == nil)
                    .foregroundStyle(.black)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.black)
                }
            }
        }
        .alert("Reservation Issue", isPresented: $showingConflictAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(conflictMessage)
        }
    }

    private var reservationFormContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Reservation")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(prefilledDateTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reservation Title")
                    .font(.subheadline.weight(.semibold))

                TextField("Enter reservation title", text: $reservationTitle)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What would you like to reserve?")
                    .font(.subheadline.weight(.semibold))

                if enabledResources.isEmpty {
                    Text("No reservable resources are currently available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Picker("Resource", selection: $selectedResourceID) {
                        ForEach(enabledResources) { resource in
                            Text(resource.name).tag(resource.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .tint(.black)
            .colorScheme(.light)

            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date")
                    .font(.subheadline.weight(.semibold))

                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("End Date")
                    .font(.subheadline.weight(.semibold))

                DatePicker(
                    "End Date",
                    selection: $endDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Toggle("All Day", isOn: $isAllDay)
                .tint(.black)

            if isAllDay == false {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Time")
                            .font(.subheadline.weight(.semibold))

                        TextField("Start time", text: $startTime)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Time")
                            .font(.subheadline.weight(.semibold))

                        TextField("End time", text: $endTime)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.subheadline.weight(.semibold))

                TextEditor(text: $notes)
                    .foregroundStyle(.black)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        await saveReservation()
                    }
                } label: {
                    Text(isSaving ? "Saving..." : "Save Reservation")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isSaving || selectedResource == nil)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }
    
    private func hasReservationConflict(for resource: ReservableResourceItem) -> Bool {
        let entryConflict = calendarEntryManager.entries.contains { entry in
            guard entry.entryType == .reservation || entry.entryType == .block else { return false }
            guard entry.resourceID == resource.id else { return false }
            return dateRangesOverlap(startDate, endDate, entry.startDate, entry.endDate)
        }

        if entryConflict {
            return true
        }

        let reservationConflict = reservationManager.reservations.contains { reservation in
            guard reservation.resourceID == resource.id else { return false }
            guard reservation.status != .denied && reservation.status != .cancelled else { return false }
            return dateRangesOverlap(startDate, endDate, reservation.startDate, reservation.endDate)
        }

        return reservationConflict
    }

    private func dateRangesOverlap(_ lhsStart: Date, _ lhsEnd: Date, _ rhsStart: Date, _ rhsEnd: Date) -> Bool {
        let calendar = Calendar.current
        let leftStart = calendar.startOfDay(for: lhsStart)
        let leftEnd = calendar.startOfDay(for: lhsEnd)
        let rightStart = calendar.startOfDay(for: rhsStart)
        let rightEnd = calendar.startOfDay(for: rhsEnd)

        return leftStart <= rightEnd && rightStart <= leftEnd
    }

    private func saveReservation() async {
        guard let selectedResource else {
            message = "Select a resource before saving the reservation."
            return
        }
        
        if hasReservationConflict(for: selectedResource) {
            conflictMessage = "That option is already reserved for the selected day or date range. Please choose a different date or resource."
            showingConflictAlert = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        let result = await reservationManager.createReservation(
            title: reservationTitle,
            resourceID: selectedResource.id,
            resourceName: selectedResource.name,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            startTimeText: isAllDay ? nil : startTime,
            endTimeText: isAllDay ? nil : endTime,
            notes: notes,
            reservationMode: selectedReservationMode,
            countsTowardQuarterlyDays: countsTowardQuarterlyDays
        )

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}
private enum CalendarAdminEventType: String, CaseIterable, Identifiable {
    case clubEvent
    case reservationWindow
    case blackout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clubEvent:
            return "Event"
        case .reservationWindow:
            return "Reserve"
        case .blackout:
            return "Block"
        }
    }
}

private enum CalendarScope: String, CaseIterable, Identifiable {
    case month
    case agenda

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month:
            return "Month"
        case .agenda:
            return "Agenda"
        }
    }
}

private enum CalendarFilter: String, CaseIterable, Identifiable {
    case all
    case myReservations
    case events
    case groupReservations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .myReservations:
            return "Mine"
        case .events:
            return "Events"
        case .groupReservations:
            return "Reserved"
        }
    }
}

private enum CalendarDisplayStyle: String, CaseIterable, Identifiable {
    case dots
    case bars
    case highlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dots:
            return "Dots"
        case .bars:
            return "Bars"
        case .highlight:
            return "Fill"
        }
    }
}

private enum CalendarItemCategory: Equatable {
    case myReservation
    case event
    case groupReservation

    var color: Color {
        switch self {
        case .myReservation:
            return .white
        case .event:
            return .blue
        case .groupReservation:
            return .orange
        }
    }
}

private struct CalendarListItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let dateText: String
    let category: CalendarItemCategory
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let number: Int?
    let categories: [CalendarItemCategory]
    let isToday: Bool
    let items: [CalendarListItem]
}

private struct CalendarMonth: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let days: [CalendarDay]
}

private extension CalendarMonth {
    static func makeMonth(offsetFromCurrent offset: Int) -> CalendarMonth {
        let calendar = Calendar.current
        let baseDate = Date()
        guard let targetDate = calendar.date(byAdding: .month, value: offset, to: baseDate) else {
            return CalendarMonth(title: "", subtitle: "Shared club calendar", days: [])
        }

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMMM yyyy"
        let title = monthFormatter.string(from: targetDate)

        let components = calendar.dateComponents([.year, .month], from: targetDate)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return CalendarMonth(title: title, subtitle: "Shared club calendar", days: [])
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = max(firstWeekday - 1, 0)

        var days: [CalendarDay] = Array(
            repeating: CalendarDay(number: nil, categories: [], isToday: false, items: []),
            count: leadingEmptyDays
        )

        for dayNumber in range {
            guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) else { continue }
            days.append(
                CalendarDay(
                    number: dayNumber,
                    categories: [],
                    isToday: calendar.isDateInToday(date),
                    items: []
                )
            )
        }

        return CalendarMonth(
            title: title,
            subtitle: "Shared club calendar",
            days: days
        )
    }
}

#Preview {
    NavigationStack {
        CalendarView()
            .environmentObject(SessionManager())
            .environmentObject(ResourceManager())
            .environmentObject(ReservationManager())
            .environmentObject(CalendarEntryManager())
    }
}

private enum AdminCalendarEntryType: String, CaseIterable, Identifiable {
    case event
    case reservation
    case block

    var id: String { rawValue }

    var title: String {
        switch self {
        case .event:
            return "Event"
        case .reservation:
            return "Reserve"
        case .block:
            return "Block"
        }
    }
}
