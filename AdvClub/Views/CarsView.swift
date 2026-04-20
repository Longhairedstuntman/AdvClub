//
//  CarsView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct CarsView: View {
    var body: some View {
        ZStack{
            VStack(){
                Text("Cars View")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.appBackgroundColor)
        .foregroundStyle(.white)
    }
}

#Preview {
    NavigationStack {
        CarsView()
    }
}
