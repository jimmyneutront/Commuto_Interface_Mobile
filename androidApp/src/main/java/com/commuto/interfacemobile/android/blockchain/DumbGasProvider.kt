package com.commuto.interfacemobile.android.blockchain

import org.web3j.tx.gas.ContractGasProvider
import java.math.BigInteger

class DumbGasProvider : ContractGasProvider {
    override fun getGasPrice(contractFunc: String?): BigInteger {
        return BigInteger.valueOf(875000000)
    }
    override fun getGasPrice(): BigInteger {
        return BigInteger.valueOf(875000000)
    }
    override fun getGasLimit(contractFunc: String?): BigInteger {
        return BigInteger.valueOf(30000000)
    }
    override fun getGasLimit(): BigInteger {
        return BigInteger.valueOf(30000000)
    }
}