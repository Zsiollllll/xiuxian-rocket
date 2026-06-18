## EventBus — 全局事件总线
## 用于解耦跨场景/跨节点的通信。
## 仅在真正跨系统的场景使用，避免成为垃圾场。
extends Node

# === 战斗事件 ===
## 敌人被击杀 [param enemy_name] 被击杀的敌人名称
signal enemy_died(enemy_name: String)

## 玩家受到伤害 [param damage] 伤害值 [param current_hp] 剩余血量
signal player_damaged(damage: float, current_hp: float)

## 玩家死亡
signal player_died

## 战斗中的通用事件 [param event_type] 事件类型 [param data] 附加数据
signal combat_event(event_type: String, data: Dictionary)

# === UI事件 ===
## 伤害数字显示 [param damage] 伤害值 [param position] 世界坐标 [param is_critical] 是否暴击
signal damage_number_request(damage: float, position: Vector2, is_critical: bool)

# === 游戏流程事件 ===
## 关卡完成
signal stage_completed(stars: int)

## 关卡失败
signal stage_failed
