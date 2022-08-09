package com.commuto.interfacemobile.android.ui

import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview

/**
 * A button that lies at the bottom of the screen, capable of setting the current tab.
 *
 * @param label The [String] that will be displayed as this button's label.
 * @param onClick The action that will be performed when this button is clicked.
 */
@Composable
fun TabButton(label: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        content = {
            Text(
                text = label,
                style = MaterialTheme.typography.h5,
                fontWeight = FontWeight.Bold,
            )
        },
        colors = ButtonDefaults.buttonColors(
            backgroundColor =  Color.Transparent,
            contentColor = Color.Black,
        ),
        elevation = null,
    )
}

/**
 * Displays a preview of [TabButton].
 */
@Preview(
    showBackground = true,
)
@Composable
fun PreviewTabButton() {
    TabButton(
        label = "Preview",
        onClick = {},
    )
}