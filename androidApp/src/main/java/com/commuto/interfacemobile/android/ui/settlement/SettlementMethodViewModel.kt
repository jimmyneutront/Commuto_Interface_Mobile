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
     * Sets the value of [stateToSet] equal to [state] on the main coroutine dispatcher.
     */
    private suspend fun setEditingSettlementMethodState(
        state: EditingSettlementMethodState,
        stateToSet: MutableState<EditingSettlementMethodState>
    ) {
        withContext(Dispatchers.Main) {
            stateToSet.value = state
        }
    }

    /**
     * Sets the value of [stateToSet] equal to [state] on the main coroutine dispatcher.
     */
    private suspend fun setDeletingSettlementMethodState(
        state: DeletingSettlementMethodState,
        stateToSet: MutableState<DeletingSettlementMethodState>
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
                Log.i(logTag, "addSettlementMethod: added ${settlementMethod.id}")
                setAddingSettlementMethodState(
                    state = AddingSettlementMethodState.COMPLETED,
                    stateToSet = stateOfAdding
                )
            } catch (exception: Exception) {
                Log.e(logTag, "addSettlementMethod: got exception during addSettlementMethod call for " +
                        "${settlementMethod.id}", exception)
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

    /**
     * Edits a given [SettlementMethod], replacing its current private data with the supplied [PrivateData] in the
     * collection of the user's settlement methods, via a call to [SettlementMethodService.editSettlementMethod]. This
     * also passes several lambdas to [SettlementMethodService.editSettlementMethod] which will call
     * [setEditingSettlementMethodState] with the current state of the settlement-method-editing process.
     *
     * @param settlementMethod The user's [SettlementMethod] that they want to edit.
     * @param newPrivateData Some [PrivateData], with which the current private data of the given settlement method will
     * be replaced.
     * @param stateOfEditing A [MutableState] wrapped around an [EditingSettlementMethodState] value, describing the
     * current state of the settlement-method-editing process.
     * @param editSettlementMethodException A [MutableState] around an optional [Exception], the wrapped value of which
     * this will set equal to the exception that occurs in the settlement-method-editing process, if any.
     * @param privateDataMutableState A [MutableState] around an optional [PrivateData], with which this will update
     * with [newPrivateData] once the settlement-method-editing process is complete.
     */
    override fun editSettlementMethod(
        settlementMethod: SettlementMethod,
        newPrivateData: PrivateData,
        stateOfEditing: MutableState<EditingSettlementMethodState>,
        editSettlementMethodException: MutableState<Exception?>,
        privateDataMutableState: MutableState<PrivateData?>
    ) {
        viewModelScope.launch {
            try {
                setEditingSettlementMethodState(
                    state = EditingSettlementMethodState.SERIALIZING,
                    stateToSet = stateOfEditing,
                )
                settlementMethodService.editSettlementMethod(
                    settlementMethod = settlementMethod,
                    newPrivateData = newPrivateData,
                    afterSerialization = {
                        setEditingSettlementMethodState(
                            state = EditingSettlementMethodState.STORING,
                            stateToSet = stateOfEditing
                        )
                    },
                    afterPersistentStorage = {
                        setEditingSettlementMethodState(
                            state = EditingSettlementMethodState.EDITING,
                            stateToSet = stateOfEditing
                        )
                    }
                )
                privateDataMutableState.value = newPrivateData
                Log.i(logTag, "editSettlementMethod: edited ${settlementMethod.id}")
                setEditingSettlementMethodState(
                    state = EditingSettlementMethodState.COMPLETED,
                    stateToSet = stateOfEditing
                )
            } catch (exception: Exception) {
                Log.e(logTag, "editSettlementMethod: got exception during editSettlementMethod call for " +
                        "${settlementMethod.id}")
                withContext(Dispatchers.Main) {
                    editSettlementMethodException.value = exception
                }
                setEditingSettlementMethodState(
                    state = EditingSettlementMethodState.EXCEPTION,
                    stateToSet = stateOfEditing
                )
            }
        }
    }

    /**
     * Deletes a given [SettlementMethod] via a call to [SettlementMethodService.deleteSettlementMethod].
     *
     * @param settlementMethod The user's [SettlementMethod] that they want to delete.
     * @param stateOfDeleting A [MutableState] wrapped around a [DeletingSettlementMethodState] value, describing the
     * current state of the settlement-method-deleting process.
     * @param deleteSettlementMethodException A [MutableState] around an optional [Exception], the wrapped value of
     * which this will set equal to the exception that occurs in the settlement-method-deleting process, if any.
     */
    override fun deleteSettlementMethod(
        settlementMethod: SettlementMethod,
        stateOfDeleting: MutableState<DeletingSettlementMethodState>,
        deleteSettlementMethodException: MutableState<Exception?>,
    ) {
        viewModelScope.launch {
            try {
                setDeletingSettlementMethodState(
                    state = DeletingSettlementMethodState.DELETING,
                    stateToSet = stateOfDeleting
                )
                settlementMethodService.deleteSettlementMethod(
                    settlementMethod = settlementMethod
                )
                Log.i(logTag, "deleteSettlementMethod: deleted ${settlementMethod.id}")
                setDeletingSettlementMethodState(
                    state = DeletingSettlementMethodState.COMPLETED,
                    stateToSet = stateOfDeleting
                )
            } catch (exception: Exception) {
                Log.e(logTag, "deleteSettlementMethod: got exception during deleteSettlementMethod call for " +
                        "${settlementMethod.id}")
                deleteSettlementMethodException.value = exception
            }
        }
    }

}