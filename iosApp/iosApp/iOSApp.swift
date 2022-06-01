import SwiftUI

@main
struct iOSApp: App {
    
    let offersViewModel = OffersViewModel()
    
	var body: some Scene {
		WindowGroup {
            OffersView(offersViewModel: offersViewModel)
		}
	}
}
