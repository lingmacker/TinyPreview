import SwiftUI

struct ImageContentView: View {
    let preview: ImagePreview

    var body: some View {
        ZoomableImageView(preview: preview)
            .overlay(alignment: .bottomTrailing) {
                if preview.firstFrameOnly {
                    Label("仅显示首帧", systemImage: "pause.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.yellow)
                        .padding(8)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
    }
}
