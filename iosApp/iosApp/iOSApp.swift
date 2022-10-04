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
        // Create the Container for dependency injection
        container = Container()
        // Register the DatabaseService singleton
        container.register(DatabaseService.self) { _ in try! DatabaseService()  }
            .inObjectScope(.container)
        // Create necessary database tables
        try! container.resolve(DatabaseService.self)!.createTables()
        // Register the SettlementMethodService singleton
        container.register(SettlementMethodService<SettlementMethodViewModel>.self) { r in SettlementMethodService(databaseService: r.resolve(DatabaseService.self)!) }
            .inObjectScope(.container)
        // Register the KeyManagerService singleton
        container.register(KeyManagerService.self) { r in
            KeyManagerService(databaseService: r.resolve(DatabaseService.self)!)
            
        }
            .inObjectScope(.container)
        // Register the SwapService singleton
        container.register(SwapService.self) { resolver in
            SwapService(
                databaseService: resolver.resolve(DatabaseService.self)!,
                keyManagerService: resolver.resolve(KeyManagerService.self)!
            )
        }
            .inObjectScope(.container)
        // Register the OfferService singleton
        container.register(OfferService<OffersViewModel, SwapViewModel>.self) { r in
            OfferService(
                databaseService: r.resolve(DatabaseService.self)!,
                keyManagerService: r.resolve(KeyManagerService.self)!,
                swapService: r.resolve(SwapService.self)!
            )
            
        }
            .inObjectScope(.container)
        // Register the BlockchainService singleton
        container.register(BlockchainService.self) { r in
            BlockchainService(
                errorHandler: ErrorViewModel(),
                offerService: r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!,
                swapService: r.resolve(SwapService.self)!,
                web3Instance: web3(provider: Web3HttpProvider(URL(string: ProcessInfo.processInfo.environment["BLOCKCHAIN_NODE"]!)!)!),
                commutoSwapAddress: EthereumAddress("0x687F36336FCAB8747be1D41366A416b41E7E1a96")!
            )
        }
            .inObjectScope(.container)
        // Provide BlockchainService to OfferService
        container.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!.blockchainService = container.resolve(BlockchainService.self)!
        #warning("TODO: Provide BlockchainService to SwapService")
        // Register the P2PService singleton
        container.register(P2PService.self) { r in
            P2PService(
                errorHandler: ErrorViewModel(),
                offerService: r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!,
                swapService: r.resolve(SwapService.self)!,
                switrixClient: SwitrixClient(homeserver: "https://matrix.org", token: ProcessInfo.processInfo.environment["MXKY"]!),
                keyManagerService: r.resolve(KeyManagerService.self)!
            )
        }
            .inObjectScope(.container)
        // Provide P2PService to OfferService
        container.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!.p2pService = container.resolve(P2PService.self)!
        #warning("TODO: Provide P2PService to SwapService")
        // Register the OffersViewModel singleton
        container.register(OffersViewModel.self) { r in
            OffersViewModel(offerService: r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!)
            
        }
        // Register the SwapViewModel singleton
        container.register(SwapViewModel.self) { r in SwapViewModel(swapService: r.resolve(SwapService.self)!) }
            .inObjectScope(.container)
            .initCompleted { r, viewModel in
                // Provide OffersViewModel to OfferService as its offerTruthSource
                r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!.offerTruthSource = r.resolve(OffersViewModel.self)!
                // Provide SwapViewModel to OfferService as its swapTruthSource
                r.resolve(OfferService<OffersViewModel, SwapViewModel>.self)!.swapTruthSource = r.resolve(SwapViewModel.self)!
                #warning("TODO: Provide SwapViewModel to SwapService as its swapTruthSource")
            }
        // Register the SettlementMethodViewModel singleton
        container.register(SettlementMethodViewModel.self) { r in SettlementMethodViewModel(settlementMethodService: r.resolve(SettlementMethodService<SettlementMethodViewModel>.self)!) }
            .inObjectScope(.container)
        // Provide SettlementMethodService to SettlementMethodViewModel
        container.resolve(SettlementMethodService<SettlementMethodViewModel>.self)!.settlementMethodTruthSource = container.resolve(SettlementMethodViewModel.self)
        // Begin listening to the blockchain
        //container.resolve(BlockchainService.self)!.listen()
        // Begin listening to the peer-to-peer network
        //container.resolve(P2PService.self)!.listen()
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
                    SwapsView(swapTruthSource: container.resolve(SwapViewModel.self)!)
                        .frame(maxHeight: .infinity)
                case .settlementMethods:
                    SettlementMethodsView(settlementMethodViewModel: container.resolve(SettlementMethodViewModel.self)!)
                }
                Divider()
                HStack {
                    TabButton(label: "Offers", tab: .offers)
                    TabButton(label: "Swaps", tab: .swaps)
                    TabButton(label: "SM", tab: .settlementMethods)
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
