package uno.skkk.oasis.data.model

import com.google.gson.annotations.SerializedName

/**
 * 通用API响应模型
 */
data class ApiResponse<T>(
    @SerializedName("code")
    val code: Int,
    
    @SerializedName("msg")
    val message: String? = null,
    
    @SerializedName("data")
    val data: T? = null
) {
    fun isSuccess(): Boolean = code == 0
}

/**
 * 登录响应数据模型
 */
data class LoginData(
    @SerializedName("al")
    val al: AuthLoginData,
    
    @SerializedName("ar")
    val ar: AuthRoleData,
    
    @SerializedName("showAd")
    val showAd: Int
)

/**
 * 认证登录数据
 */
data class AuthLoginData(
    @SerializedName("atype")
    val atype: Int,
    
    @SerializedName("dtype")
    val dtype: Int,
    
    @SerializedName("eid")
    val eid: String,
    
    @SerializedName("oid")
    val oid: String,
    
    @SerializedName("stype")
    val stype: Int,
    
    @SerializedName("token")
    val token: String,
    
    @SerializedName("uid")
    val uid: String
)

/**
 * 认证角色数据
 */
data class AuthRoleData(
    @SerializedName("rids")
    val rids: List<String>,
    
    @SerializedName("types")
    val types: List<String>
)

/**
 * 设备信息模型
 */
data class Device(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("status")
    val status: Int = 0, // 设备状态
    
    @SerializedName("btype")
    val btype: Int = 0, // 设备类型
    
    @SerializedName("ltime")
    val ltime: Long? = null, // 最后在线时间
    
    @SerializedName("owner")
    val owner: DeviceOwner? = null,
    
    @SerializedName("gene")
    val gene: DeviceGene? = null,
    
    @SerializedName("addr")
    val addr: DeviceAddress? = null,
    
    @SerializedName("ep")
    val ep: DeviceEndpoint? = null,
    
    @SerializedName("bm")
    val bm: DeviceBm? = null
) {
    fun isRunning(): Boolean = gene?.status != 99
    fun getStatusText(): String = if (isRunning()) "在线" else "离线"
}

/**
 * 设备所有者信息
 */
data class DeviceOwner(
    @SerializedName("id")
    val id: String
)

/**
 * 设备基因信息
 */
data class DeviceGene(
    @SerializedName("status")
    val status: Int // 99表示设备未开启
)

/**
 * 设备地址信息
 */
data class DeviceAddress(
    @SerializedName("detail")
    val detail: String? = null,
    
    @SerializedName("prov")
    val prov: String? = null,
    
    @SerializedName("city")
    val city: String? = null,
    
    @SerializedName("dist")
    val dist: String? = null
)

/**
 * 设备端点信息
 */
data class DeviceEndpoint(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String
)

/**
 * 设备BM信息
 */
data class DeviceBm(
    @SerializedName("dtype")
    val dtype: Int,
    
    @SerializedName("img")
    val img: String? = null
)

/**
 * Master响应数据模型（完整版）
 */
data class MasterResponseData(
    @SerializedName("account")
    val account: UserAccount,
    
    @SerializedName("favos")
    val devices: List<Device>,
    
    @SerializedName("ads")
    val ads: List<Any>? = null,
    
    @SerializedName("pltTotalScore")
    val pltTotalScore: String? = null
)

/**
 * 用户账户信息
 */
data class UserAccount(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("img")
    val avatarUrl: String? = null,
    
    @SerializedName("pn")
    val phoneNumber: String? = null,
    
    @SerializedName("adShow")
    val adShow: Int? = null,
    
    @SerializedName("cas")
    val cas: Any? = null
)

/**
 * 设备列表响应模型（保持向后兼容）
 */
data class DeviceListData(
    @SerializedName("favos")
    val devices: List<Device>
)

/**
 * 设备状态响应模�?
 */
data class DeviceStatusData(
    @SerializedName("list")
    val statusList: List<DeviceStatus>
)

/**
 * 设备状态数�?
 */
data class DeviceStatus(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("status")
    val status: Int, // 设备运行状�?
    
    @SerializedName("online")
    val online: Boolean = false // 是否在线
)

/**
 * 单个设备状态数据（与web实现一致）
 */
data class SingleDeviceStatusData(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("status")
    val status: Int, // 设备运行状态：0-停止，1-运行
    
    @SerializedName("online")
    val online: Boolean = false, // 是否在线
    
    @SerializedName("ltime")
    val ltime: Long? = null, // 最后在线时间
    
    @SerializedName("name")
    val name: String? = null, // 设备名称
    
    @SerializedName("btype")
    val btype: Int? = null // 设备类型
)

/**
 * 添加设备请求模型
 */
data class AddDeviceRequest(
    @SerializedName("did")
    val deviceId: String,
    
    @SerializedName("name")
    val deviceName: String? = null,
    
    @SerializedName("type")
    val deviceType: String? = null
)

/**
 * 添加设备响应
 */
data class AddDeviceResponse(
    @SerializedName("device")
    val device: Device,
    
    @SerializedName("message")
    val message: String? = null
)

/**
 * 钱包数据模型 - 匹配实际API响应
 */
data class WalletData(
    @SerializedName("balance")
    val balance: Double = 0.0, // 余额（兼容旧版本）
    
    @SerializedName("olCash")
    val olCash: Double? = null, // 在线现金余额
    
    @SerializedName("total")
    val total: Double = 0.0, // 实际余额（从API响应中的total字段）
    
    @SerializedName("ofCash")
    val ofCash: Double = 0.0, // 离线现金余额
    
    @SerializedName("ofGift")
    val ofGift: Double = 0.0, // 离线礼品余额
    
    @SerializedName("olGift")
    val olGift: Double = 0.0, // 在线礼品余额
    
    @SerializedName("currency")
    val currency: String = "CNY", // 货币类型
    
    @SerializedName("frozen")
    val frozen: Double = 0.0, // 冻结金额
    
    @SerializedName("ep")
    val ep: WalletEndpoint? = null, // 钱包端点信息
    
    @SerializedName("id")
    val id: String? = null, // 钱包ID
    
    @SerializedName("name")
    val name: String? = null, // 钱包名称
    
    @SerializedName("owner")
    val owner: WalletOwner? = null, // 钱包所有者信息
    
    @SerializedName("rtime")
    val rtime: String? = null, // 创建时间
    
    @SerializedName("utime")
    val utime: String? = null // 更新时间
) {
    // 获取实际显示的余额，优先使用olCash字段（用户要求）
    fun getDisplayBalance(): Double {
        return olCash ?: total.takeIf { it > 0.0 } ?: balance
    }
}

/**
 * 钱包端点信息
 */
data class WalletEndpoint(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("contact")
    val contact: WalletContact? = null,
    
    @SerializedName("setting")
    val setting: WalletSetting? = null
)

/**
 * 钱包联系人信息
 */
data class WalletContact(
    @SerializedName("name")
    val name: String,
    
    @SerializedName("pn")
    val pn: String
)

/**
 * 钱包设置信息
 */
data class WalletSetting(
    @SerializedName("olcharge")
    val olcharge: Int = 0,
    
    @SerializedName("olrefund")
    val olrefund: Int = 0,
    
    @SerializedName("thirdPay")
    val thirdPay: Int = 0
)

/**
 * 钱包所有者信息
 */
data class WalletOwner(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("pn")
    val pn: String
)

/**
 * 钱包响应数据结构 - 匹配实际API响应
 */
data class WalletResponseData(
    @SerializedName("aw")
    val aw: WalletData? = null,
    
    @SerializedName("eps")
    val eps: List<WalletData>? = null,
    
    @SerializedName("charge")
    val charge: Int = 0,
    
    @SerializedName("vip")
    val vip: Int = 0,
    
    @SerializedName("refund")
    val refund: Int = 0
) {
    // 获取主要的钱包数据 - 修复：优先使用aw，确保充值到正确钱包
    fun getPrimaryWalletData(): WalletData? {
        // 优先返回aw（主钱包），只有在aw为null且eps不为空时才使用eps的第一个
        // 但要确保eps中选择的是正确的钱包（通常是余额最高或最近使用的）
        return aw ?: eps?.maxByOrNull { it.getDisplayBalance() }
    }
    
    // 获取所有可用的钱包数据
    fun getAllWalletData(): List<WalletData> {
        val wallets = mutableListOf<WalletData>()
        aw?.let { wallets.add(it) }
        eps?.let { wallets.addAll(it) }
        return wallets
    }
    
    // 根据钱包ID获取特定钱包（如果API支持钱包ID的话）
    fun getWalletById(walletId: String?): WalletData? {
        if (walletId.isNullOrEmpty()) return getPrimaryWalletData()
        
        // 首先检查主钱包aw是否匹配（如果有ID标识的话）
        // 由于API响应中的WalletData没有ID字段，我们需要通过其他方式匹配
        // 这里先返回主钱包作为默认值，实际项目中可能需要根据API文档调整
        
        // 如果eps中有多个钱包，可以尝试通过余额或其他特征匹配
        // 但由于API响应结构限制，目前只能返回主钱包
        return getPrimaryWalletData()
    }
    
    // 根据钱包索引获取钱包数据（用于多钱包场景）
    fun getWalletByIndex(index: Int): WalletData? {
        val allWallets = getAllWalletData()
        return if (index >= 0 && index < allWallets.size) {
            allWallets[index]
        } else {
            getPrimaryWalletData()
        }
    }
}

/**
 * 订单列表响应 - 匹配实际API响应格式
 */
data class OrderListResponse(
    @SerializedName("code")
    val code: Int,
    
    @SerializedName("data")
    val data: List<Order>? = null,
    
    @SerializedName("size")
    val size: String? = null
) {
    fun isSuccess(): Boolean = code == 0
}

/**
 * 充值金额选项（旧版本，保留兼容性）
 */
data class RechargeAmount(
    @SerializedName("amount")
    val amount: Double,
    
    @SerializedName("description")
    val description: String? = null
)

/**
 * 充值产品（新版本，支持优惠信息）
 */
data class Product(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("desc")
    val description: String,
    
    @SerializedName("cata")
    val category: String,
    
    @SerializedName("curPrice")
    val currentPrice: Double,
    
    @SerializedName("ogiPrice")
    val originalPrice: Double,
    
    @SerializedName("count")
    val count: Int,
    
    @SerializedName("status")
    val status: Int,
    
    @SerializedName("show")
    val show: Int,
    
    @SerializedName("type")
    val type: Int,
    
    @SerializedName("mode")
    val mode: Int,
    
    @SerializedName("ctime")
    val createTime: Long,
    
    @SerializedName("utime")
    val updateTime: Long? = null,
    
    @SerializedName("imgs")
    val images: List<String>? = null,
    
    @SerializedName("apply")
    val apply: List<Any>? = null,
    
    @SerializedName("dtype")
    val dtype: Any? = null,
    
    @SerializedName("params")
    val params: String? = null,
    
    @SerializedName("ptype")
    val ptype: List<Any>? = null,
    
    @SerializedName("isOut")
    val isOut: Int? = null
) {
    /**
     * 是否有优惠
     */
    fun hasDiscount(): Boolean {
        return originalPrice > currentPrice
    }
    
    /**
     * 获取优惠金额
     */
    fun getDiscountAmount(): Double {
        return if (hasDiscount()) originalPrice - currentPrice else 0.0
    }
    
    /**
     * 获取优惠描述
     */
    fun getDiscountDescription(): String? {
        return if (hasDiscount()) {
            "送${String.format("%.1f", getDiscountAmount())}元"
        } else null
    }
    
    /**
     * 是否可用
     */
    fun isAvailable(): Boolean {
        return status == 1 && show == 1
    }
}

/**
 * 充值请求
 */
data class RechargeRequest(
    @SerializedName("amount")
    val amount: Double,
    
    @SerializedName("paymentType")
    val paymentType: Int = 21 // 默认支付宝
)

/**
 * 充值订单
 */
data class RechargeOrder(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("amount")
    val amount: Double,
    
    @SerializedName("status")
    val status: String,
    
    @SerializedName("createTime")
    val createTime: String
)

/**
 * 支付渠道响应
 */
data class PaymentChannelsResponse(
    @SerializedName("bill")
    val bill: BillInfo,
    
    @SerializedName("channels")
    val channels: List<PaymentChannel>
)

/**
 * 账单信息
 */
data class BillInfo(
    @SerializedName("cata")
    val cata: Int,
    
    @SerializedName("ep")
    val ep: BillEndpoint,
    
    @SerializedName("id")
    val id: String,
    
    @SerializedName("mode")
    val mode: Int,
    
    @SerializedName("msg")
    val msg: String,
    
    @SerializedName("owner")
    val owner: BillOwner,
    
    @SerializedName("payment")
    val payment: Double,
    
    @SerializedName("type")
    val type: Int
)

/**
 * 账单端点信息
 */
data class BillEndpoint(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String
)

/**
 * 账单所有者信息
 */
data class BillOwner(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("pn")
    val pn: String
)

/**
 * 支付渠道
 */
data class PaymentChannel(
    @SerializedName("activity")
    val activity: String? = null,
    
    @SerializedName("desc")
    val desc: String? = null,
    
    @SerializedName("eid")
    val eid: String? = null,
    
    @SerializedName("imgUrl")
    val imgUrl: String? = null,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("seq")
    val seq: Int,
    
    @SerializedName("type")
    val type: Int
)

/**
 * 支付宝支付数据
 * 注意：API返回的是完整的支付宝SDK调用字符串，不是JSON对象
 */
data class AlipayPaymentData(
    // 这里存储的是完整的支付宝SDK调用字符串
    val paymentString: String
) {
    companion object {
        /**
         * 从API响应的字符串创建AlipayPaymentData
         */
        fun fromApiResponse(responseString: String): AlipayPaymentData {
            return AlipayPaymentData(responseString)
        }
    }
}

/**
 * 订单用户信息
 */
data class OrderOwner(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("pn")
    val phoneNumber: String
)

/**
 * 订单模型 - 匹配实际API响应格式
 */
data class Order(
    @SerializedName("id")
    val id: String,
    
    @SerializedName("cata")
    val category: Int, // 订单分类
    
    @SerializedName("ctime")
    val createTime: Long, // 创建时间
    
    @SerializedName("dir")
    val direction: Int, // 方向�?表示消费�?
    
    @SerializedName("msg")
    val message: String, // 订单描述信息
    
    @SerializedName("owner")
    val owner: OrderOwner, // 订单所有者信�?
    
    @SerializedName("payment")
    val payment: Double, // 支付金额
    
    @SerializedName("status")
    val status: Int, // 订单状�?
    
    @SerializedName("type")
    val type: Int, // 订单类型
    
    @SerializedName("utime")
    val updateTime: Long // 更新时间
) {
    /**
     * 获取订单状态文本
     */
    fun getStatusText(): String {
        return when (status) {
            1 -> "未付款"
            2 -> "待确认"
            3 -> "已付款"
            4 -> "订单失败"
            9 -> "已取消"
            else -> "未知状态"
        }
    }
    
    /**
     * 获取订单类型文本
     */
    fun getTypeText(): String {
        return when (type) {
            91 -> "设备消费"
            2 -> "充值"
            3 -> "退款"
            else -> "其他"
        }
    }
    
    /**
     * 获取设备名称（从消息中提取）
     */
    fun getDeviceName(): String {
        // 从消息中提取设备名称，例如："水控/直饮机设�?2栋宿�?楼温开�?)消费"
        val regex = "\\((.+?)\\)".toRegex()
        val matchResult = regex.find(message)
        return matchResult?.groupValues?.get(1) ?: "未知设备"
    }
    
    /**
     * 获取格式化的金额
     */
    fun getFormattedAmount(): String {
        return "¥${String.format("%.2f", payment)}"
    }
}

/**
 * 正确的订单创建请求 (基于HAR文件分析)
 */
data class BillSaveRequest(
    @SerializedName("cata")
    val cata: Int = 1, // 订单分类，充值为1
    
    @SerializedName("contact")
    val contact: BillContact,
    
    @SerializedName("ep")
    val ep: BillEndpointRef,
    
    @SerializedName("note")
    val note: String,
    
    @SerializedName("owner")
    val owner: BillOwnerRef,
    
    @SerializedName("prds")
    val prds: List<BillProduct>
)

/**
 * 订单联系人
 */
data class BillContact(
    @SerializedName("id")
    val id: String
)

/**
 * 订单端点引用
 */
data class BillEndpointRef(
    @SerializedName("id")
    val id: String
)

/**
 * 订单所有者引用
 */
data class BillOwnerRef(
    @SerializedName("id")
    val id: String
)

/**
 * 订单产品
 */
data class BillProduct(
    @SerializedName("count")
    val count: Int = 1,
    
    @SerializedName("id")
    val id: String
)
