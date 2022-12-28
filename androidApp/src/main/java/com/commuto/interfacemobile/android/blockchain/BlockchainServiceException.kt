package com.commuto.interfacemobile.android.blockchain

/**
 * An [Exception] thrown by [BlockchainService] methods.
 */
class BlockchainServiceException(override val message: String): Exception(message)