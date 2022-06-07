import SwiftUI
import Swinject

@main
struct iOSApp: App {
    
    let container: Container
    
    init() {
        container = Container()
        container.register(OfferService.self) { _ in OfferService() }
            .inObjectScope(.container)
        /*
        container.register(BlockchainService.self) {r in
            BlockchainService(offerService: r.resolve(OfferService.self)!)
        }
            .inObjectScope(.container)
         */
        container.register(OffersViewModel.self) { r in
            OffersViewModel(offerService: r.resolve(OfferService.self)!)
            
        }
            .inObjectScope(.container)
            .initCompleted { r, viewModel in
                r.resolve(OfferService.self)!.viewModel = viewModel
            }
        //container.resolve(BlockchainService.self)!.listen()
    }
    
	var body: some Scene {
		WindowGroup {
            OffersView(offersViewModel: container.resolve(OffersViewModel.self)!)
        }
	}
}
