'use client';
import React, {useEffect, useState} from "react";
import {deserializeFromLocalStorage} from "@/utils/Serializable";
import {Button, Collapse} from "antd";
import {useRouter} from "next/navigation";

type Data = {
    owner: {
        id: string
    },
    status: number,
    btype: number,
    gene: {
        status: number
    },
    id: string,
    addr: {
        geo: {
            type: string,
            coordinates: number[]
        },
        detail: string,
        prov: string,
        city: string,
        dist: string
    },
    ep: {
        id: string,
        name: string
    },
    ltime: number,
    bm: {
        dtype: number,
        img: string
    },
    name: string
}[]

type local = {
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

type DeviceListProps = {
    base_url: string
}

export default function DeviceList({base_url}: DeviceListProps) {
    // 重定向
    const router = useRouter()
    useEffect(() => {
        const data = localStorage.getItem("data")
        if (!data) {
            router.push("/")
        }
    }, [])

    // 获取设备列表
    const [devices, setDevices] = useState([] as Data)
        // token
    const [tk, setTk] = useState("")
    useEffect(() => {
        const storage = deserializeFromLocalStorage<local>("data")
        let token = null
        if (storage) {
            token = storage.al.token
            setTk(token)
        }

        if (token) {
            fetch(`${base_url}/api/v1/ui/app/master?`, {
                method: "GET",
                headers: {
                    "Connection": "keep-alive",
                    "ApplicationType": "1,1",
                    "Accept": "*/*",
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
                    "Authorization": token,
                    "Accept-Language": "zh-TW,zh-Hant;q=0.9",
                    "Accept-Encoding": "gzip, deflate, br"
                }
            })
                .then(async res => {
                    const json = await res.json()
                    if (!json.data.favos) {
                        localStorage.removeItem("data")
                        router.push("/")
                        return
                    }
                    setDevices(json.data.favos)

                    // @ts-expect-error not necessary
                    setIsRunning(json.data.favos.map(device => {
                        return {
                            id: device.id,
                            status: false
                        }
                    }))
                })
                .catch(err => {
                    console.log(err)
                })
        }
    }, [])

    // 检查设备状态
    const [isRunning, setIsRunning] = useState([] as { id: string, status: boolean }[])
    const handleCollapseChange = (key: string[]) => {
        const target = key[key.length - 1]
        if (target && tk !== "") {
            fetch(`${base_url}/api/v1/ui/app/dev/status?did=${target}&more=false&promo=false`, {
                method: "GET",
                headers: {
                    "Connection": "keep-alive",
                    "ApplicationType": "1,1",
                    "Accept": "*/*",
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
                    "Authorization": tk,
                    "Accept-Language": "zh-TW,zh-Hant;q=0.9",
                    "Accept-Encoding": "gzip, deflate, br"
                }
            })
                .then(async res => {
                    const json = await res.json()
                    const status = json.data.device.gene.status
                    if (status === 99) { // 设备没打开
                        setIsRunning(prevState =>
                            prevState.map(item =>
                                item.id === target ? {...item, status: true} : item
                            )
                        )
                    } else {
                        setIsRunning(prevState =>
                            prevState.map(item =>
                                item.id === target ? {...item, status: false} : item
                            )
                        )
                    }
                })
                .catch(err => {
                    console.log(err)
                })
        }
    }

    // 开始或结束设备
    const [loading, setLoading] = useState(false)
    const startOrEnd = (did: string) => {
        setLoading(true)
        if (isRunning.find(item => item.id === did)?.status) {
            fetch(`${base_url}/api/v1/dev/start?did=${did}&upgrade=true&ptype=91&rcp=false`, {
                method: "GET",
                headers: {
                    "Connection": "keep-alive",
                    "ApplicationType": "1,1",
                    "Accept": "*/*",
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
                    "Authorization": tk,
                    "Accept-Language": "zh-TW,zh-Hant;q=0.9",
                    "Accept-Encoding": "gzip, deflate, br"
                }
            })
                .then(async res => {
                    setLoading(false)
                    const json = await res.json()
                    if (json.code === 0) {
                        setIsRunning(prevState =>
                            prevState.map(item =>
                                item.id === did ? {...item, status: false} : item
                            )
                        )
                    } else {
                        alert("设备可能已经开启或者开启失败")
                    }
                })
                .catch(err => {
                    alert(`设备开启失败：${err}`)
                    setLoading(false)
                })
        } else {
            fetch(`${base_url}/api/v1/dev/end?did=${did}`, {
                method: "GET",
                headers: {
                    "Connection": "keep-alive",
                    "ApplicationType": "1,1",
                    "Accept": "*/*",
                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
                    "Authorization": tk,
                    "Accept-Language": "zh-TW,zh-Hant;q=0.9",
                    "Accept-Encoding": "gzip, deflate, br"
                }
            })
                .then(async res => {
                    setLoading(false)
                    const json = await res.json()
                    if (json.code === 0) {
                        setIsRunning(prevState =>
                            prevState.map(item =>
                                item.id === did ? {...item, status: true} : item
                            )
                        )
                    } else {
                        alert("设备可能已经关闭或者关闭失败")
                    }
                })
                .catch(err => {
                    alert(`设备关闭失败：${err}`)
                    setLoading(false)
                })
        }
    }

    return (
        <div>
            <Collapse
                items={
                    devices.map(device => {
                        return {
                            key: device.id,
                            label: device.name,
                            children: <div>
                                <Button
                                    id={device.id}
                                    size={"large"}
                                    variant={"filled"}
                                    color={
                                        isRunning.find(item => item.id === device.id)?.status ? "primary" : "danger"
                                    }
                                    onClick={() => startOrEnd(device.id)}
                                    loading={loading}
                                >
                                    {isRunning.find(item => item.id === device.id)?.status ? "立即开始" : "立即结束"}
                                </Button>
                            </div>
                        }
                    })
                }
                onChange={handleCollapseChange}
            />
        </div>
    )
}
