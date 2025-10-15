//
//  BarcodeScannerView.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import SwiftUI
import AVFoundation
#if canImport(VisionKit)
import VisionKit
#endif

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onScanned: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 16.0, *) {
                    ScannerContent(onScanned: handleScan)
                } else {
                    UnsupportedScannerView()
                }
            }
            .navigationTitle("Scan Barcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func handleScan(_ code: String) {
        dismiss()
        onScanned(code)
    }
}

// MARK: - iOS 16+ Scanner
@available(iOS 16.0, *)
private struct ScannerContent: View {
    var onScanned: (String) -> Void
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            if !DataScannerViewController.isSupported {
                UnsupportedScannerView(message: "Barcode scanning requires a device with the Neural Engine and iOS 16+.")
            } else if !DataScannerViewController.isAvailable {
                UnsupportedScannerView(message: "Camera is unavailable. Try closing other apps that are using the camera.")
            } else if permissionDenied {
                UnsupportedScannerView(message: "Camera access is required for scanning. Enable it in Settings > Privacy > Camera.")
            } else {
                VisionKitBarcodeScanner(onScanned: onScanned, permissionDenied: $permissionDenied)
                    .overlay(ScannerOverlay().ignoresSafeArea())
            }
        }
        .onAppear {
            Task {
                await requestCameraAccessIfNeeded()
            }
        }
    }

    private func requestCameraAccessIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionDenied = false
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
        default:
            permissionDenied = true
        }
    }
}

@available(iOS 16.0, *)
private struct VisionKitBarcodeScanner: UIViewControllerRepresentable {
    var onScanned: (String) -> Void
    @Binding var permissionDenied: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isPinchToZoomEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        context.coordinator.scanner = controller
        startScanning(controller)

        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        startScanning(uiViewController)
    }

    private func startScanning(_ controller: DataScannerViewController) {
        do {
            try controller.startScanning()
        } catch {
            permissionDenied = true
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScanned: (String) -> Void
        weak var scanner: DataScannerViewController?
        private var hasFired = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasFired else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue {
                    hasFired = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.async { [weak self] in
                        self?.onScanned(value)
                    }
                    dataScanner.stopScanning()
                    break
                }
            }
        }
    }
}

// MARK: - Unsupported View
private struct UnsupportedScannerView: View {
    var message: String = "Barcode scanning is not supported on this device."

    var body: some View {
        VStack(spacing: DesignSpacing.sm) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundColor(DesignPalette.secondaryText)
            Text(message)
                .font(DesignTypography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(DesignPalette.secondaryText)
        }
        .padding()
    }
}

@available(iOS 16.0, *)
private struct ScannerOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.65
            let height = min(width * 0.45, proxy.size.height * 0.4)
            let rect = CGRect(
                x: (proxy.size.width - width) / 2,
                y: (proxy.size.height - height) / 2,
                width: width,
                height: height
            )

            ZStack {
                CutoutShape(cutoutRect: rect)
                    .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()

                BarcodeFrameView()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                VStack(spacing: DesignSpacing.sm) {
                    Text("Align the barcode inside the box")
                        .font(DesignTypography.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, DesignSpacing.lg)

                    Spacer()

                    Text("Scanning happens automatically")
                        .font(DesignTypography.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, DesignSpacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DesignSpacing.lg)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct CutoutShape: Shape {
    let cutoutRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(in: cutoutRect, cornerSize: CGSize(width: 24, height: 24))
        return path
    }
}

@available(iOS 16.0, *)
private struct BarcodeFrameView: View {
    var body: some View {
        GeometryReader { proxy in
            let cornerRadius: CGFloat = 16
            let borderWidth: CGFloat = 2.5
            let stripeCount = 14

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: borderWidth)
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)

                HStripedBarcode(stripeCount: stripeCount)
                    .padding(.horizontal, proxy.size.width * 0.06)
                    .padding(.vertical, proxy.size.height * 0.22)

                CornerTicks()
            }
        }
    }
}

@available(iOS 16.0, *)
private struct HStripedBarcode: View {
    let stripeCount: Int

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = proxy.size.width / CGFloat(stripeCount * 2)
            let height = proxy.size.height

            Path { path in
                for index in 0..<stripeCount {
                    let x = CGFloat(index) * lineWidth * 2 + lineWidth / 2
                    let stripeHeight = index.isMultiple(of: 3) ? height : height * 0.85
                    let offsetY = (height - stripeHeight) / 2

                    path.addRect(CGRect(x: x, y: offsetY, width: lineWidth, height: stripeHeight))
                }
            }
            .fill(
                LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.55)],
                               startPoint: .top,
                               endPoint: .bottom)
            )
        }
    }
}

@available(iOS 16.0, *)
private struct CornerTicks: View {
    var body: some View {
        let tickLength: CGFloat = 18
        let lineWidth: CGFloat = 3

        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            Path { path in
                // top-left
                path.move(to: rect.origin)
                path.addLine(to: CGPoint(x: rect.origin.x + tickLength, y: rect.origin.y))
                path.move(to: rect.origin)
                path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + tickLength))

                // top-right
                let topRight = CGPoint(x: rect.maxX, y: rect.minY)
                path.move(to: topRight)
                path.addLine(to: CGPoint(x: rect.maxX - tickLength, y: rect.minY))
                path.move(to: topRight)
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + tickLength))

                // bottom-left
                let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
                path.move(to: bottomLeft)
                path.addLine(to: CGPoint(x: rect.minX + tickLength, y: rect.maxY))
                path.move(to: bottomLeft)
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - tickLength))

                // bottom-right
                let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
                path.move(to: bottomRight)
                path.addLine(to: CGPoint(x: rect.maxX - tickLength, y: rect.maxY))
                path.move(to: bottomRight)
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tickLength))
            }
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}
