import SwiftUI
import UIKit

/// A SwiftUI wrapper around UIActivityViewController to present share sheets.
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        // For iPad support, though we're mostly iPhone focused
        controller.popoverPresentationController?.sourceView = UIView()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
