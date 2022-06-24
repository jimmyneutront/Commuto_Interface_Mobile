import SwiftUI
import Swinject

/**
 The entrypoint for the iOS Commuto Interface SwiftUI App.
 */
@main
struct iOSApp: App {
    
    /**
     The Swinject `Container` for dependency injection.
     */
    let container: Container
    
    /**
     Configures `container` and begins necessary background activities.
     */
    init() {
        container = Container()
        /*
        container.register(OfferService.self) { _ in OfferService() }
            .inObjectScope(.container)
         */
        /*
        container.register(BlockchainService.self) {r in
            BlockchainService(offerService: r.resolve(OfferService.self)!)
        }
            .inObjectScope(.container)
         */
        /*
        container.register(OffersViewModel.self) { r in
            OffersViewModel(offerService: r.resolve(OfferService.self)!)
            
        }
            .inObjectScope(.container)
            .initCompleted { r, viewModel in
                r.resolve(OfferService.self)!.offerTruthSource = viewModel
            }
         */
        //container.resolve(BlockchainService.self)!.listen()
        
        container.register(OffersViewModel.self) { _ in OffersViewModel() }
    }
    
	var body: some Scene {
		WindowGroup {
            OffersView(offersViewModel: container.resolve(OffersViewModel.self)!)
        }
	}
}
