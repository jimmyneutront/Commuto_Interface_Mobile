package com.commuto.interfacemobile.android.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.Button
import androidx.compose.material.Text
import androidx.compose.runtime.*
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

/**
 * Presents a full-screen [Dialog] containing [content] when the value of [isPresented] is `true`.
 *
 * This is designed to be similar to SwiftUI's
 * [sheet](https://developer.apple.com/documentation/SwiftUI/View/sheet(isPresented:onDismiss:content:)) in appearance
 * and function.
 *
 * When the value of [isPresented] is set to `true`, this draws a [Dialog] on screen. As soon as this [Composable] is
 * created, it launches two coroutine jobs via [LaunchedEffect]. The first job delays for a specified amount of time to
 * allow the [Dialog] to appear and darken the background, and then sets the value of `showAnimatedContent` to true,
 * causing the content of the [AnimatedVisibility] within the [Dialog] to slide in from the bottom of the screen. The
 * second job waits for [Unit] to be emitted from `closeSheetFlow`. When this occurs, it sets `showAnimatedContent` to
 * false, causing the content of the [AnimatedVisibility] within the [Dialog] to slide out vertically. Then it delays
 * for a specified amount of time to allow the animation to complete, and then sets the value of [isPresented] to false,
 * causing the [Dialog] to disappear.
 *
 * The [AnimatedVisibility] passes a lambda to its content that can be called to close the sheet. When called, it enters
 * `coroutineScope` and emits [Unit] into `closeSheetFlow`.
 *
 * @param isPresented A [MutableState] wrapping a [Boolean] that controls whether this Sheet is visible. Note that if
 * the value of this is set to false, this [Composable] will immediately disappear without animation.
 * @param content The content of this sheet. The content must accept as a parameter a lambda which will close the sheet
 * with animation when called.
 */
@OptIn(ExperimentalComposeUiApi::class) // Required to use DialogProperties
@Composable
fun SheetComposable(isPresented: MutableState<Boolean>, content: @Composable ColumnScope.(() -> Unit) -> Unit) {
    if (isPresented.value) {

        val showAnimatedContent = remember { mutableStateOf(false) }

        val coroutineScope = rememberCoroutineScope()

        val closeSheetFlow = remember { MutableSharedFlow<Unit>() }

        val animationTime = 500L

        val dialogBuildTime = 200L

        LaunchedEffect(Unit) {
            launch {
                delay(dialogBuildTime)
                showAnimatedContent.value = true
            }
            launch {
                // We call asSharedFlow because we should never send anything to this flow.
                closeSheetFlow.asSharedFlow().collectLatest {
                    showAnimatedContent.value = false
                    delay(animationTime)
                    isPresented.value = false
                }
            }
        }

        Dialog(
            onDismissRequest = {},
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            AnimatedVisibility(
                visible = showAnimatedContent.value,
                enter = slideInVertically(
                    animationSpec = tween(animationTime.toInt()),
                    initialOffsetY = { fullHeight -> fullHeight }
                ),
                exit = slideOutVertically(
                    animationSpec = tween(animationTime.toInt()),
                    targetOffsetY = { fullHeight -> fullHeight }
                ),
                content = {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.White)
                    ) {
                        content { coroutineScope.launch { closeSheetFlow.emit(Unit) } }
                    }
                }
            )
        }
    }
}

/**
 * Displays a preview of [SheetComposable] containing a Button labeled "Content" that closes the sheet when pressed.
 */
@Preview
@Composable
fun PreviewSheetComposable() {
    SheetComposable(isPresented = remember { mutableStateOf(true)} ) { closeSheet ->
        Button(
            onClick = {
                closeSheet()
            },
            content = {
                Text("Content")
            }
        )
    }
}
