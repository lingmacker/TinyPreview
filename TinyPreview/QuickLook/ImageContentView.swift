import SwiftUI

struct ImageContentView: View {
    let preview: ImagePreview

    var body: some View {
        ZoomableImageView(preview: preview)
            .overlay(alignment: .bottomTrailing) {
                if preview.firstFrameOnly || preview.isDownsampled {
                    VStack(alignment: .trailing, spacing: 6) {
                        if preview.firstFrameOnly { badge("仅显示首帧", systemImage: "pause.circle") }
                        if preview.isDownsampled { badge("已缩小显示", systemImage: "arrow.down.right.and.arrow.up.left") }
                    }
                    .padding(12)
                    .allowsHitTesting(false)
                }
            }
    }

    private func badge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.yellow)
            .padding(8)
            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
    }
}
