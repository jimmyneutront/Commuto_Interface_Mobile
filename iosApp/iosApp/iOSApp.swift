import SwiftUI
import Swinject
import web3swift

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
        container.register(DatabaseService.self) { _ in try! DatabaseService()  }
        container.register(OfferService.self) { r in
            OfferService(databaseService: r.resolve(DatabaseService.self)!)
            
        }
            .inObjectScope(.container)
        container.register(BlockchainService.self) {r in
            BlockchainService(
                errorHandler: ErrorViewModel(),
                offerService: r.resolve(OfferService.self)!,
                web3Instance: web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!),
                commutoSwapAddress: "0x687F36336FCAB8747be1D41366A416b41E7E1a96"
            )
        }
            .inObjectScope(.container)
        container.register(OffersViewModel.self) { r in
            OffersViewModel(offerService: r.resolve(OfferService.self)!)
            
        }
            .inObjectScope(.container)
            .initCompleted { r, viewModel in
                r.resolve(OfferService.self)!.offerTruthSource = viewModel
            }
        //container.resolve(BlockchainService.self)!.listen()
    }
    
	var body: some Scene {
		WindowGroup {
            OffersView(offersViewModel: container.resolve(OffersViewModel.self)!)
        }
	}
}
