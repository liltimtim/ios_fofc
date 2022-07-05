//
//  FOCF_Widget.swift
//  FOCF Widget
//
//  Created by Timothy Dillman on 6/28/22.
//

import WidgetKit
import SwiftUI
import Intents
import CoreImage
import UIKit

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
}

struct FOCF_WidgetEntryView : View {
    @StateObject var viewModel: ViewModel = .init()
    var entry: Provider.Entry
    var body: some View {
        VStack {
            if viewModel.code != nil {
                Image(uiImage: viewModel.code!)
                    .resizable()
                    .background(Color.blue)
            } else {
                Text("No code available.")
            }
            Text(viewModel.strCode)
        }
    }
    

}

class ViewModel: ObservableObject {
    @Published var code: UIImage?
    var strCode: String { UserDefaults(suiteName: "group.mobilefirst.focf")?.string(forKey: "code") ?? ""}
    init() {
        if let str = UserDefaults(suiteName: "group.mobilefirst.focf")?.string(forKey: "code") , let data = generate(with: str)  {
            code = UIImage(data: data)
        }
    }
    
    @MainActor
    func generateImage() async {
        Task {
            guard let code = UserDefaults(suiteName: "group.mobilefirst.focf")?.string(forKey: "code") else { return }
            guard let data = await generateBarcode(from: code) else { return }
            self.code = UIImage(data: data)
        }
    }
    
    func generateBarcode(from string: String) async -> Data? {
        return await withCheckedContinuation({ cont in
            let data = string.data(using: String.Encoding.ascii)

            if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
                filter.setValue(data, forKey: "inputMessage")
                let transform = CGAffineTransform(scaleX: 1.5, y: 1.5)

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
    
    func generate(with string: String) -> Data? {
        let data = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 1.5, y: 1.5)

            if let output = filter.outputImage?.transformed(by: transform) {
                guard let tinted = output.tinted(using: .black) else {
                    return nil
                }
                return UIImage(ciImage: tinted).pngData()
            }
        }

        return nil
    }
}

@main
struct FOCF_Widget: Widget {
    let kind: String = "FOCF_Widget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            FOCF_WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Barcode Widget")
        .description("Provides a barcode view on your home screen")
    }
    

}

struct FOCF_Widget_Previews: PreviewProvider {
    static var previews: some View {
        FOCF_WidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
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
