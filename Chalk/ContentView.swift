//
//  ContentView.swift
//  Chalk
//
//  Created by Blair Myers on 10/13/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TodayView()
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer())
        .preferredColorScheme(.dark)
}
#endif
