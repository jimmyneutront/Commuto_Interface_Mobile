import SwiftUI
import Swinject

@main
struct iOSApp: App {
    
    let container: Container
    
    init() {
        container = Container()
        container.register(OffersViewModel.self) {_ in OffersViewModel() }
            .inObjectScope(.container)
    }
    
	var body: some Scene {
		WindowGroup {
            OffersView(offersViewModel: container.resolve(OffersViewModel.self)!)
		}
	}
}
