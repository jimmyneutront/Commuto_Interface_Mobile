import SwiftUI
import Swinject
import web3swift
import Switrix

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
            .inObjectScope(.container)
        try! container.resolve(DatabaseService.self)!.createTables()
        container.register(KeyManagerService.self) { r in
            KeyManagerService(databaseService: r.resolve(DatabaseService.self)!)
            
        }
        container.register(OfferService<OffersViewModel, SwapViewModel>.self) { r in
            OfferService(databaseService: r.resolve(DatabaseService.self)!, keyManagerService: r.resolve(KeyManagerService.self)!)
            
        }
            .inObjectScope(.container)
        container.register(BlockchainService.self) { r in
            BlockchainService(
                errorHandler: ErrorViewModel(),
                offerService: r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!,
                web3Instance: web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!),
                commutoSwapAddress: EthereumAddress("0x687F36336FCAB8747be1D41366A416b41E7E1a96")!
            )
        }
            .inObjectScope(.container)
        container.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!.blockchainService = container.resolve(BlockchainService.self)!
        container.register(P2PService.self) { r in
            P2PService(errorHandler: ErrorViewModel(), offerService: r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!, switrixClient: SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!))
        }
            .inObjectScope(.container)
        container.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!.p2pService = container.resolve(P2PService.self)!
        container.register(OffersViewModel.self) { r in
            OffersViewModel(offerService: r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!)
            
        }
            .inObjectScope(.container)
            .initCompleted { r, viewModel in
                r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!.offerTruthSource = viewModel
            }
        //container.resolve(BlockchainService.self)!.listen()
    }
    
    /**
     Indicates the tab that should be displayed.
     */
    @State var currentTab: CurrentTab = .offers
    
	var body: some Scene {
		WindowGroup {
            VStack(spacing: 0) {
                switch currentTab {
                case .offers:
                    OffersView(offerTruthSource: container.resolve(OffersViewModel.self)!)
                case .swaps:
                    SwapsView()
                        .frame(maxHeight: .infinity)
                }
                Divider()
                HStack {
                    TabButton(label: "Offers", tab: .offers)
                    TabButton(label: "Swaps", tab: .swaps)
                }
                .padding([.top, .bottom], 15)
            }
        }
	}
    
    /**
     Returns a button that lies at the bottom of the screen capable of setting the current tab.
     
     - Parameters:
        - label: The `String` that will be displayed as this button's label.
        - tab: The value to which this button will set `currentTab` when pressed.
     */
    @ViewBuilder
    func TabButton(label: String, tab: CurrentTab) -> some View {
        Button(
            action: {
                currentTab = tab
            },
            label: {
                Text(label)
                    .frame(width: 60, height: 22)
                    .frame(maxWidth: .infinity)
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        )
    }
    
}
