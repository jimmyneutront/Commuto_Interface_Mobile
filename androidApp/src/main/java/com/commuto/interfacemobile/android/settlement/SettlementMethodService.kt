package com.commuto.interfacemobile.android.settlement

import android.util.Log
import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.settlement.privatedata.PrivateData
import com.commuto.interfacemobile.android.settlement.privatedata.PrivateSEPAData
import com.commuto.interfacemobile.android.settlement.privatedata.PrivateSWIFTData
import com.commuto.interfacemobile.android.ui.settlement.UISettlementMethodTruthSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The main Settlement Method Service. It is responsible for validating, adding, editing, and removing the user's
 * settlement methods and their corresponding private data, both in persistent storage and in a
 * [UISettlementMethodTruthSource].
 *
 * @property logTag The tag passed to [Log] calls.
 * @property databaseService The [DatabaseService] used for persistent storage.
 */
@Singleton
class SettlementMethodService @Inject constructor(
    private val databaseService: DatabaseService
) {

    private val logTag = "SettlementMethodService"

    private lateinit var settlementMethodTruthSource: UISettlementMethodTruthSource

    /**
     * Used to set the [settlementMethodTruthSource] property. This can only be called once.
     *
     * @param newTruthSource The new value of the [settlementMethodTruthSource] property, which cannot be null.
     */
    fun setSettlementMethodTruthSource(newTruthSource: UISettlementMethodTruthSource) {
        check(!::settlementMethodTruthSource.isInitialized) {
            "settlementMethodTruthSource is already initialized"
        }
        settlementMethodTruthSource = newTruthSource
    }

    /**
     * Attempts to add a [SettlementMethod] with corresponding [PrivateData] to the list of the user's settlement
     * methods.
     *
     * On the IO coroutine dispatcher, this ensures that the supplied private data corresponds to the type of settlement
     * method that the user is adding. Then this serializes the supplied [PrivateData] accordingly, and associates it
     * with the supplied [SettlementMethod]. Then this securely stores the new [SettlementMethod] and associated
     * serialized private data in persistent storage, via [databaseService]. Finally, on the main coroutine dispatcher,
     * this appends the new [SettlementMethod] to the list of settlement methods in [settlementMethodTruthSource].
     *
     * @param settlementMethod The [SettlementMethod] to be added.
     * @param newPrivateData The [PrivateData] for the new settlement method.
     * @param afterSerialization A closure that will be executed after [newPrivateData] has been serialized.
     * @param afterPersistentStorage A closure that will be executed after [settlementMethod] is saved in persistent
     * storage.
     *
     * @throws SettlementMethodServiceException if [settlementMethod] is of an unknown type.
     */
    suspend fun addSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        afterSerialization: (suspend () -> Unit)? = null,
        afterPersistentStorage: (suspend () -> Unit)? = null
    ) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "addSettlementMethod: adding ${settlementMethod.currency} via " +
                    settlementMethod.method
            )
            try {
                try {
                    when (settlementMethod.method) {
                        "SEPA" -> {
                            settlementMethod.privateData = Json.encodeToString(newPrivateData as PrivateSEPAData)
                        }
                        "SWIFT" -> {
                            settlementMethod.privateData = Json.encodeToString(newPrivateData as PrivateSWIFTData)
                        }
                        else -> {
                            throw SettlementMethodServiceException("Did not recognize settlement method")
                        }
                    }
                    afterSerialization?.invoke()
                } catch (exception: Exception) {
                    Log.e(logTag, "addSettlementMethod: got exception while adding ${settlementMethod.currency} via " +
                            settlementMethod.method, exception)
                    throw exception
                }
                Log.i(logTag, "addSettlementMethod: persistently storing settlement method " +
                        settlementMethod.currency
                )
                // TODO: get the actual ID of the settlement method here
                databaseService.storeUserSettlementMethod(
                    id = UUID.randomUUID().toString(),
                    settlementMethod = Json.encodeToString(settlementMethod),
                    privateData = settlementMethod.privateData
                )
                afterPersistentStorage?.invoke()
                Log.i(logTag, "addSettlementMethod: adding ${settlementMethod.currency} via " +
                        "${settlementMethod.method} to settlementMethodTruthSource")
                withContext(Dispatchers.Main) {
                    settlementMethodTruthSource.settlementMethods.add(settlementMethod)
                }
            } catch (exception: Exception) {
                Log.e(logTag, "addSettlementMethod: encountered exception", exception)
                throw exception
            }
        }
    }

}