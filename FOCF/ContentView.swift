//
//  ContentView.swift
//  FOCF
//
//  Created by Timothy Dillman on 6/28/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: ContentViewModel = .init()
    var body: some View {
        VStack {
            if viewModel.barcodeImage != nil {
                Image(uiImage: viewModel.barcodeImage!)
                    .resizable()
                    .frame(height: 200)
            } else {
                Text("Enter code to generate barcode")
            }
            TextField("Enter Code", text: $viewModel.publishedCode)
                .padding()
                .overlay {
                    Capsule()
                        .stroke(.blue, lineWidth: 1)
                }
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
