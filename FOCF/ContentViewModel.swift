//
//  ContentViewModel.swift
//  FOCF
//
//  Created by Timothy Dillman on 6/28/22.
//

import Foundation
import CoreImage
import UIKit
import SwiftUI
import Combine
class ContentViewModel: ObservableObject {
    @Published var barcodeImage: UIImage?
    @Published var publishedCode: String = ""
    @AppStorage("code", store: UserDefaults(suiteName: "group.mobilefirst.focf")) private var code: String = ""
    private var subscriptions: Set<AnyCancellable> = []
    
    init() {
        publishedCode = code
        $publishedCode
            .sink(receiveValue: { value in
                self.code = value
                Task {
                    await self.setImage(with: value)
                }
            })
            .store(in: &subscriptions)
    }
    
    @MainActor
    private func setImage(with value: String) async {
        guard let data = await generateBarcode(from: value) else { return }
        barcodeImage = UIImage(data: data)
    }
    
    func generateBarcode(from string: String) async -> Data? {
        return await withCheckedContinuation({ cont in
            let data = string.data(using: String.Encoding.ascii)

            if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
                filter.setValue(data, forKey: "inputMessage")
                let transform = CGAffineTransform(scaleX: 15, y: 15)

                if let output = filter.outputImage?.transformed(by: transform) {
                    guard let tinted = output.tinted(using: .black) else {
                        cont.resume(with: .success(nil))
                        return
                    }
                    cont.resume(with: .success(UIImage(ciImage: tinted).pngData()))
                    return
                }
            }

            cont.resume(with: .success(nil))
        })
    }
}

extension CIImage {
    /// Inverts the colors and creates a transparent image by converting the mask to alpha.
    /// Input image should be black and white.
    var transparent: CIImage? {
        return inverted?.blackTransparent
    }

    /// Inverts the colors.
    var inverted: CIImage? {
        guard let invertedColorFilter = CIFilter(name: "CIColorInvert") else { return nil }

        invertedColorFilter.setValue(self, forKey: "inputImage")
        return invertedColorFilter.outputImage
    }

    /// Converts all black to transparent.
    var blackTransparent: CIImage? {
        guard let blackTransparentFilter = CIFilter(name: "CIMaskToAlpha") else { return nil }
        blackTransparentFilter.setValue(self, forKey: "inputImage")
        return blackTransparentFilter.outputImage
    }

    /// Applies the given color as a tint color.
    func tinted(using color: UIColor) -> CIImage?
    {
        guard
            let transparentQRImage = transparent,
            let filter = CIFilter(name: "CIMultiplyCompositing"),
            let colorFilter = CIFilter(name: "CIConstantColorGenerator") else { return nil }

        let ciColor = CIColor(color: color)
        colorFilter.setValue(ciColor, forKey: kCIInputColorKey)
        let colorImage = colorFilter.outputImage

        filter.setValue(colorImage, forKey: kCIInputImageKey)
        filter.setValue(transparentQRImage, forKey: kCIInputBackgroundImageKey)

        return filter.outputImage!
    }
}
