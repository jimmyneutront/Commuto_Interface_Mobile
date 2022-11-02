package com.commuto.interfacemobile.android.ui.settlement

import android.util.Log
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.commuto.interfacemobile.android.settlement.SettlementMethod
import com.commuto.interfacemobile.android.settlement.SettlementMethodService
import com.commuto.interfacemobile.android.settlement.privatedata.PrivateData
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The Settlement Method View Mode, the single source of truth for all settlement-method-related data. It is observed by
 * settlement-method related views, which include those for adding/editing/deleting the user's settlement methods, as
 * well as those for creating/editing/taking offers.
 *
 * @property logTag The tag passed to [Log] calls.
 * @property settlementMethods A [SnapshotStateList] containing all of the user's [SettlementMethod]s, each with
 * corresponding private data.
 * @property settlementMethodService A [SettlementMethodService] responsible for performing validating, adding, editing,
 * and removing operations on the user's settlement methods, both in persistent storage and in [settlementMethods].
 */
@Singleton
class SettlementMethodViewModel
@Inject constructor(private val settlementMethodService: SettlementMethodService):
    ViewModel(), UISettlementMethodTruthSource {

    init {
        settlementMethodService.setSettlementMethodTruthSource(this)
    }

    private val logTag = "SettlementMethodViewModel"

    override var settlementMethods = SnapshotStateList<SettlementMethod>().also { snapshotStateList ->
        SettlementMethod.sampleSettlementMethodsEmptyPrices.map {
            snapshotStateList.add(it)
        }
    }

    /**
     * Sets the value of [stateToSet] equal to [state] on the main coroutine dispatcher.
     */
    private suspend fun setAddingSettlementMethodState(
        state: AddingSettlementMethodState,
        stateToSet: MutableState<AddingSettlementMethodState>
    ) {
        withContext(Dispatchers.Main) {
            stateToSet.value = state
        }
    }

    /**
     * Adds a given [SettlementMethod] with corresponding [PrivateData] to the collection of the user's settlement
     * methods, by passing them to [SettlementMethodService.addSettlementMethod]. This also passes several closures to
     * [SettlementMethodService.addSettlementMethod] which will call [setAddingSettlementMethodState] with the current
     * state of the settlement-method-adding process.
     *
     * @param settlementMethod The new [SettlementMethod] that the user wants added to their collection of settlement
     * methods.
     * @param newPrivateData Some [PrivateData] corresponding to [settlementMethod], supplied by the user.
     * @param stateOfAdding A [MutableState] wrapped around an [AddingSettlementMethodState] value, describing the
     * current state of the settlement-method-adding process.
     * @param addSettlementMethodException A [MutableState] around an optional [Exception], the wrapped value of which
     * this will set equal to the exception that occurs in the settlement-method-adding process, if any.
     */
    override fun addSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        stateOfAdding: MutableState<AddingSettlementMethodState>,
        addSettlementMethodException: MutableState<Exception?>
    ) {
        viewModelScope.launch {
            try {
                setAddingSettlementMethodState(
                    state = AddingSettlementMethodState.SERIALIZING,
                    stateToSet = stateOfAdding,
                )
                settlementMethodService.addSettlementMethod(
                    settlementMethod = settlementMethod,
                    newPrivateData = newPrivateData,
                    afterSerialization = {
                        setAddingSettlementMethodState(
                            state = AddingSettlementMethodState.STORING,
                            stateToSet = stateOfAdding
                        )
                    },
                    afterPersistentStorage = {
                        setAddingSettlementMethodState(
                            state = AddingSettlementMethodState.ADDING,
                            stateToSet = stateOfAdding
                        )
                    }
                )
                Log.i(logTag, "addSettlementMethod: added settlement method ${settlementMethod.currency} via " +
                        settlementMethod.method
                )
                setAddingSettlementMethodState(
                    state = AddingSettlementMethodState.COMPLETED,
                    stateToSet = stateOfAdding
                )
            } catch (exception: Exception) {
                Log.e(logTag, "addSettlementMethod: got exception during addSettlementMethod call for " +
                        "${settlementMethod.currency} via ${settlementMethod.method}", exception)
                withContext(Dispatchers.Main) {
                    addSettlementMethodException.value = exception
                }
                setAddingSettlementMethodState(
                    state = AddingSettlementMethodState.EXCEPTION,
                    stateToSet = stateOfAdding
                )
            }
        }
    }

}