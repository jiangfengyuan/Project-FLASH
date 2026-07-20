package com.flash.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.flash.app.data.UiStyle
import com.flash.app.ui.theme.LocalUiStyle
import com.flash.app.ui.theme.glass.GlassCard

/**
 * 风格感知卡片：GLASS → 玻璃面（模糊+半透+描边），MD3 → 标准 Material 卡片。
 * LogCard / 统计卡 / 日历详情等共用。
 */
@Composable
fun StyleCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    if (LocalUiStyle.current == UiStyle.GLASS) {
        GlassCard(modifier = modifier, onClick = onClick, content = content)
    } else {
        Card(
            modifier = modifier,
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            onClick = { onClick?.invoke() },
            enabled = onClick != null,
        ) {
            Column(Modifier.padding(12.dp), content = content)
        }
    }
}
