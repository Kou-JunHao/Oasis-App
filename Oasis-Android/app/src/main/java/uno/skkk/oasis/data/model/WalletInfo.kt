package uno.skkk.oasis.data.model

/**
 * 钱包信息数据类
 * 从设备列表中提取的钱包信息
 */
data class WalletInfo(
    val id: String,           // 钱包ID (ep.id)
    val name: String,         // 钱包名称 (ep.name)
    val deviceCount: Int = 1, // 使用此钱包的设备数量
    val balance: Double = 0.0 // 钱包余额
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as WalletInfo
        return id == other.id
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }
}