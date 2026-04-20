import SwiftUI

struct AppHeaderModifier: ViewModifier {
    let title: String
    let subtitle: String
    let logoAssetName: String

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 14) {
                    Image(logoAssetName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.82))

                        Text(subtitle)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(Color.appBackgroundColor)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    func appHeader(
        title: String = "Adventure Club",
        subtitle: String = "Member App",
        logoAssetName: String = "AdvClub"
    ) -> some View {
        modifier(
            AppHeaderModifier(
                title: title,
                subtitle: subtitle,
                logoAssetName: logoAssetName
            )
        )
    }
}
