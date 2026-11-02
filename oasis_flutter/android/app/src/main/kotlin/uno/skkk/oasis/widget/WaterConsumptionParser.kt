package uno.skkk.oasis.widget

import org.json.JSONObject

/**
 * 一次接水的消费结果。
 *
 * 服务端不直接给水量，只给花费的积分（单位「厘」，1000 = 1 元），
 * 所以水量是「积分 → 金额 → 按换算比例折算」推出来的。
 */
data class WaterConsumption(
    val billId: String,
    val scoreEquivalent: Int,
    val deviceId: String,
    val deviceName: String,
    val completedAt: Long,
) {
    /** 花费金额（元） */
    val money: Double get() = scoreEquivalent / 1000.0

    fun moneyText(): String = "¥" + String.format(java.util.Locale.CHINA, "%.2f", money)

    /**
     * 结果通知文案。
     *
     * 例：
     *   本次消费 ¥0.31 · 水量约 970 ml
     *   本次消费 ¥0.31              （关闭了水量估算）
     *   本次未产生费用
     */
    fun completionText(millilitresPerYuan: Double, estimateVisible: Boolean): String {
        if (scoreEquivalent <= 0) return "本次未产生费用"
        if (!estimateVisible) return "本次消费 ${moneyText()}"
        val millilitres = scoreEquivalent / 1000.0 * millilitresPerYuan
        return "本次消费 ${moneyText()} · 水量约 ${waterText(millilitres)}"
    }

    companion object {
        /** 与 Dart 侧 WaterEstimate.waterTextForYuan 保持一致的格式化。 */
        fun waterText(millilitres: Double): String {
            if (millilitres <= 0) return "--"
            if (millilitres >= 1000) {
                return String.format(java.util.Locale.CHINA, "%.1f L", millilitres / 1000.0)
            }
            val rounded = Math.floor(millilitres / 10.0) * 10
            return String.format(java.util.Locale.CHINA, "%.0f ml", rounded)
        }
    }
}

/**
 * 从服务端响应里解析接水消费。
 *
 * 两个数据源：
 *   1. 账单 `bill/lst-owner` + `bill/view-full`：接水账单 `type == 91 && status == 3`，
 *      但直饮水账单的 `payment` 恒为 0（费用从钱包/积分扣），所以账单里拿不到金额。
 *   2. 积分流水 `acc/score/score-lst`：真正的扣费记录在这里，`type == 105`（用户消费积分）
 *      或 `type == 107`，`data.spend` / `data.score` 是花费积分。
 *
 * life798 只认 107，但实测 Oasis 账号的消费记录是 105，所以这里两种都收。
 */
object WaterConsumptionParser {
    /** 消费类积分记录的 type 集合。 */
    private val CONSUMPTION_TYPES = setOf(105, 107)

    /** 账单里可能表示花费的字段名（服务端字段名不稳定，依次尝试）。 */
    private val SPEND_KEYS =
        listOf("spend", "score", "changeScore", "change_score", "amount", "value", "num", "points")

    /** 判断一条积分流水是否属于消费。 */
    fun isConsumption(record: JSONObject): Boolean {
        val type = record.optInt("type", record.optInt("src", 0))
        return type in CONSUMPTION_TYPES
    }

    /** 读取一条记录里花费的积分（取绝对值），读不到返回 0。 */
    fun readSpentScore(record: JSONObject): Int {
        val holders = listOfNotNull(
            record.optJSONObject("data"),
            record,
        )
        for (holder in holders) {
            for (key in SPEND_KEYS) {
                if (!holder.has(key)) continue
                val raw = holder.opt(key).toString().trim()
                val value = raw.toDoubleOrNull() ?: continue
                val rounded = Math.abs(value).toInt()
                if (rounded > 0) return rounded
            }
        }
        return 0
    }

    /** 读取记录时间（毫秒）。服务端有的字段是秒，需要归一化。 */
    fun readTimestamp(record: JSONObject): Long {
        val raw = record.optLong("ctime", 0L).takeIf { it > 0 }
            ?: record.optLong("utime", 0L)
        if (raw <= 0) return 0
        return if (raw < 10_000_000_000L) raw * 1000 else raw
    }

    /**
     * 从积分流水里挑出「本次接水」对应的消费记录。
     *
     * 做法与 life798 一致：排除开始时记下的 baseline，取第一条在开始时间之后、
     * 且不是历史记录的最新消费。
     */
    fun newestConsumption(
        records: List<JSONObject>,
        baselineKeys: Set<String>,
        startedAt: Long,
    ): JSONObject? {
        var best: JSONObject? = null
        var bestTime = 0L
        for (record in records) {
            if (!isConsumption(record)) continue
            val key = recordKey(record)
            if (key.isNotEmpty() && baselineKeys.contains(key)) continue
            val time = readTimestamp(record)
            if (time in 1 until startedAt) continue
            if (readSpentScore(record) <= 0) continue
            if (time >= bestTime) {
                best = record
                bestTime = time
            }
        }
        return best
    }

    /** 记录的唯一标识：优先 sn，退回 adId+ctime。 */
    fun recordKey(record: JSONObject): String {
        val data = record.optJSONObject("data")
        val sn = data?.optString("sn", "")?.trim().orEmpty()
        if (sn.isNotEmpty()) return "sn:$sn"
        val adId = data?.optString("adId", "")?.trim().orEmpty()
        val time = readTimestamp(record)
        if (adId.isEmpty() && time <= 0) return ""
        return "ad:$adId@$time"
    }

    /** 组装消费结果。 */
    fun toConsumption(record: JSONObject, fallbackDeviceId: String): WaterConsumption {
        val data = record.optJSONObject("data")
        val sn = data?.optString("sn", "")?.trim().orEmpty()
        val adId = data?.optString("adId", "")?.trim().orEmpty()
        val deviceId = fallbackDeviceId.ifEmpty { adId }
        val name = record.optString("adName", "").trim().ifEmpty { "接水消费" }
        return WaterConsumption(
            billId = sn.ifEmpty { adId },
            scoreEquivalent = readSpentScore(record),
            deviceId = deviceId,
            deviceName = name,
            completedAt = readTimestamp(record),
        )
    }
}
