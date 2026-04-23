//
//  ContentView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/6/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var resourceManager: ResourceManager
    @EnvironmentObject private var reservationManager: ReservationManager

    var body: some View {
        Group {
            if sessionManager.isAuthenticated {
                TabView {
                    tabRoot {
                        HomeView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                    tabRoot {
                        CarsView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Vehicles", systemImage: "car")
                    }

                    tabRoot {
                        HowToView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("How To", systemImage: "doc.text")
                    }

                    tabRoot {
                        CalendarView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }

                    tabRoot {
                        AccountView()
                            .appHeader()
                    }
                    .tabItem {
                        Label("Account", systemImage: "person.crop.circle")
                    }

                    if sessionManager.isAdmin {
                        tabRoot {
                            AdminView()
                                .appHeader()
                        }
                        .tabItem {
                            Label("Admin", systemImage: "lock.shield")
                        }
                    }
                }
                .tint(.white)

            } else {
                LoginView()
            }
        }
    }

    private func tabRoot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
        }
    }
}


private enum MemberReservationType: String, CaseIterable, Identifiable {
    case resource

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resource:
            return "Reserve"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionManager())
        .environmentObject(ResourceManager())
        .environmentObject(ReservationManager())
}
