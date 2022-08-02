package com.commuto.interfacemobile.android.offer

/**
 * Describes the state of an [Offer] according to the
 * [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 * The order in which the cases of this `enum` are defined is the order in which an offer should move through the states
 * that they represent.
 * @property OPENING Indicates that [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer)
 * has not yet been called for the corresponding offer.
 * @property OPEN_OFFER_TRANSACTION_BROADCAST Indicates that the transaction to open the corresponding offer has been
 * broadcast.
 * @property AWAITING_PUBLIC_KEY_ANNOUNCEMENT Indicates that the
 * [OfferOpened event](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) for the corresponding
 * offer has been detected, so, if the offer's maker is the user of the interface, the public key should now be
 * announced; otherwise this means that we are waiting for the maker to announce their public key.
 * @property OFFER_OPENED Indicates that the corresponding offer has been opened on chain and the maker's public key has
 * been announced.
 * @property indexNumber An [Int] corresponding to this state's position in a list of possible offer states organized
 * according to the order in which an offer should move through them, with the earliest state at the beginning
 * (corresponding to the integer 0) and the latest state at the end (corresponding to the integer 3).
 * @property asString A [String] corresponding to a particular case of [OfferState].
 */
enum class OfferState {
    OPENING,
    OPEN_OFFER_TRANSACTION_BROADCAST,
    AWAITING_PUBLIC_KEY_ANNOUNCEMENT,
    OFFER_OPENED;

    val indexNumber: Int
        get() = when (this) {
            OPENING -> 0
            OPEN_OFFER_TRANSACTION_BROADCAST -> 1
            AWAITING_PUBLIC_KEY_ANNOUNCEMENT -> 2
            OFFER_OPENED -> 3
        }

    val asString: String
        get() = when (this) {
            OPENING -> "opening"
            OPEN_OFFER_TRANSACTION_BROADCAST -> "openOfferTxPublished"
            AWAITING_PUBLIC_KEY_ANNOUNCEMENT -> "awaitingPKAnnouncement"
            OFFER_OPENED -> "offerOpened"
        }

    companion object {
        /**
         * Attempts to create an [OfferState] corresponding to the given [String], or returns `null` if no case
         * corresponds to the given [String].
         *
         * @param string The [String] from which this attempts to create a corresponding [OfferState].
         *
         * @return An [OfferState] corresponding to [string], or `null` if no such [OfferState] exists.
         */
        fun fromString(string: String?): OfferState? {
            when (string) {
                null -> {
                    return null
                }
                "opening" -> {
                    return OPENING
                }
                "openOfferTxPublished" -> {
                    return OPEN_OFFER_TRANSACTION_BROADCAST
                }
                "awaitingPKAnnouncement" -> {
                    return AWAITING_PUBLIC_KEY_ANNOUNCEMENT
                }
                "offerOpened" -> {
                    return OFFER_OPENED
                }
                else -> {
                    return null
                }
            }
        }
    }

}