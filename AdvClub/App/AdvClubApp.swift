//
//  AdvClubApp.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import SwiftUI
import SwiftData
import FirebaseCore



@main
struct AdvClubApp: App {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var clubContentManager = ClubContentManager()
    @StateObject private var resourceManager = ResourceManager()
    @StateObject private var reservationManager = ReservationManager()
    @StateObject private var calendarEntryManager = CalendarEntryManager()
    @StateObject private var howToManager = HowToManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(clubContentManager)
                .environmentObject(resourceManager)
                .environmentObject(reservationManager)
                .environmentObject(calendarEntryManager)
                .environmentObject(howToManager)
                .preferredColorScheme(.light)
        }
    }
}
