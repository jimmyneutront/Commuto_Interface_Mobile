import SwiftUI

@main
struct iOSApp: App {
	var body: some Scene {
		WindowGroup {
            OffersView(offers: Offer.sampleOffers)
		}
	}
}
