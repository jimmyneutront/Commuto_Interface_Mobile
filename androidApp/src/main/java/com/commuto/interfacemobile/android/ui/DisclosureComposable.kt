package com.commuto.interfacemobile.android.ui

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate

/**
 * A [Composable] that always displays [header], and can expand to display [content] or contract and hide [content] when
 * tapped.
 *
 * @param header A [Composable] that will always be displayed regardless of whether [DisclosureComposable] is expanded
 * or not.
 * @param content A [Composable] that will be displayed below [header] when this is expanded.
 */
@Composable
fun DisclosureComposable(header: @Composable () -> Unit, content: @Composable () -> Unit) {
    var isDisclosureExpanded by remember { mutableStateOf(false) }
    val arrowRotationState by animateFloatAsState(if (isDisclosureExpanded) 180f else 0f)
    Column(
        modifier = Modifier
            .animateContentSize(
                animationSpec = tween(
                    durationMillis = 200,
                    easing = LinearEasing,
                )
            )
            .clickable {
                isDisclosureExpanded = !isDisclosureExpanded
            }
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            header()
            IconButton(
                modifier = Modifier.rotate(arrowRotationState),
                onClick = {
                    isDisclosureExpanded = !isDisclosureExpanded
                }
            ) {
                Icon(
                    imageVector = Icons.Default.KeyboardArrowDown,
                    contentDescription = "Drop Down Arrow"
                )
            }
        }
        if (isDisclosureExpanded) {
            content()
        }
    }
}