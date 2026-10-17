import SwiftUI

struct ImageContentView: View {
    let preview: ImagePreview

    var body: some View {
        ZoomableImageView(preview: preview)
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(preview.formatName)
                        if preview.pixelWidth > 0 {
                            Text("·")
                            Text("\(preview.pixelWidth) × \(preview.pixelHeight)")
                        }
                    }
                    Text(ByteCountFormatter.string(fromByteCount: Int64(preview.data.count), countStyle: .file)
                         + " · " + (preview.hasAlpha.map { $0 ? "含透明通道" : "无透明通道" } ?? "矢量图像"))
                    if preview.firstFrameOnly {
                        Label("仅显示首帧", systemImage: "pause.circle").foregroundStyle(.yellow)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("image-metadata")
                .padding(12)
                .allowsHitTesting(false)
            }
    }
}
