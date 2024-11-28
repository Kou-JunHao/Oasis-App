'use client';

import {Button} from "antd";
import {deserializeFromLocalStorage} from "@/utils/Serializable";
import {useRouter} from "next/navigation";

type Local = {
    al: {
        atype: number,
        dtype: number,
        eid: string,
        oid: string,
        stype: number,
        token: string,
        uid: string
    },
    ar: {
        rids: [],
        types: []
    },
    showAd: number
}

type LogoutBtnProps = {
    base_url: string
}

export default function LogoutBtn({base_url}: LogoutBtnProps) {
    const router = useRouter()
    const logout = () => {
        const storage = deserializeFromLocalStorage<Local>("data")
        let token = null
        if (storage) {
            token = storage.al.token
        }
        if (token) {
            fetch(`${base_url}/api/v1/acc/logout`, {
                method: "GET",
                headers: {
                    "Content-Type": "application/json",
                    "Connection": "keep-alive",
                    "ApplicationType": "1,1",
                    "Accept": "*/*",
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
                    "Accept-Language": "zh-TW,zh-Hant;q=0.9",
                    "Accept-Encoding": "gzip, deflate, br",
                    "Authorization": token
                }
            })
                .then(async res => {
                    if (res.ok) {
                        const json = await res.json()
                        if (json.code === 0) {
                            localStorage.removeItem("data")
                            router.push("/")
                        } else {
                            alert("登出失败，请重试")
                        }
                    }
                })
        }
    }

    return (
        <div className={"flex justify-center mt-6"}>
            <Button className={"w-3/5"} type={"primary"} size={"large"}
                    onClick={logout}
            >退出登录</Button>
        </div>
    )
}
