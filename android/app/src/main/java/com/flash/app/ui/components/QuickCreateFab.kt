package com.flash.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.flash.app.ui.theme.ModuleColors

/**
 * FAB 快速创建（PRD 09）：+ 展开四个模块选项（模块品牌色），
 * 展开时 + 旋转 45° 变为 ×。
 */
@Composable
fun QuickCreateFab(
    onCreateLog: () -> Unit,
    onCreateIdea: () -> Unit,
    onCreateEmotion: () -> Unit,
    onCreateCalendar: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }

    fun collapse(action: () -> Unit) {
        expanded = false
        action()
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.BottomEnd) {
        // 展开时的全屏半透明遮罩：位于内容层之上、FAB 列之下，点击收起菜单
        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn(tween(180)),
            exit = fadeOut(tween(150)),
        ) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.32f))
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { expanded = false },
            )
        }

        Column(horizontalAlignment = Alignment.End) {
        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn(tween(180)) + expandVertically(tween(220)),
            exit = fadeOut(tween(150)) + shrinkVertically(tween(180)),
        ) {
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                FabOption("情绪", Icons.Filled.Favorite, ModuleColors.Emotion) {
                    collapse(onCreateEmotion)
                }
                FabOption("灵感", Icons.Filled.Lightbulb, ModuleColors.Idea) {
                    collapse(onCreateIdea)
                }
                FabOption("日志", Icons.AutoMirrored.Filled.MenuBook, ModuleColors.Log) {
                    collapse(onCreateLog)
                }
                FabOption("日程", Icons.Filled.CalendarMonth, ModuleColors.Calendar) {
                    collapse(onCreateCalendar)
                }
            }
        }
        val rotation by animateFloatAsState(if (expanded) 45f else 0f, tween(200), label = "fabRot")
        FloatingActionButton(
            onClick = { expanded = !expanded },
            containerColor = MaterialTheme.colorScheme.primary,
        ) {
            Icon(
                Icons.Filled.Add,
                contentDescription = if (expanded) "收起" else "快速创建",
                modifier = Modifier.rotate(rotation),
            )
        }
        }
    }
}

@Composable
private fun FabOption(
    label: String,
    icon: ImageVector,
    color: Color,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.clickable(onClick = onClick),
    ) {
        // 标签加 pill 背景，压在页面卡片上也可读
        Text(
            label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier
                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(50))
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )
        Spacer(Modifier.width(10.dp))
        SmallFloatingActionButton(
            onClick = onClick,
            containerColor = color,
            contentColor = Color.White,
        ) {
            Icon(icon, contentDescription = label)
        }
    }
}
