//
//  HowToView.swift
//  AdvClub
//
//  Created by Chase Smith on 4/9/26.
//

import SwiftUI

struct HowToView: View {
    var body: some View {
        ZStack{
            VStack(){
                Text("How To View")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.appBackgroundColor)
        .foregroundStyle(.white)
    }
}


#Preview {
    NavigationStack {
        HowToView()
    }
}
