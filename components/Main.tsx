'use client';
import {Button, Input} from "antd";
import {TbUserFilled} from "react-icons/tb";
import React, {useEffect, useState} from "react";
import Captcha from "@/components/Captcha";
import useCountdown from "@/hooks/useCountdown";
import {serializeToLocalStorage} from "@/utils/Serializable";
import {useRouter} from "next/navigation";

type MainProps = {
    base_url: string
    s: number
    r: number
}

export default function Main({base_url, s, r}: MainProps) {
    // 重定向
    useEffect(() => {
        const data = localStorage.getItem("data")
        if (data) {
            router.push("/control")
        }
    }, [])

    // 手机号码
    const [phone, setPhone] = useState("")
    const handlePhoneChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const value = event.target.value
        if (/^\d*$/.test(value) && value.length <= 11) {
            setPhone(value)
        }
    }

    // 图形验证码
    const [captcha, setCaptcha] = useState("")
    const handleCaptchaChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const value = event.target.value
        if (/^\d*$/.test(value)) {
            setCaptcha(value)
        }
    }

    // 手机验证码
    const [sms, setSms] = useState("")
    const handleSmsChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const value = event.target.value
        if (/^\d*$/.test(value) && value.length <= 6) {
            setSms(value)
        }
    }
    // 转圈圈和倒计时
    const [loading, setLoading] = useState(false)
    const {countdown, startCountdown, isRunning} = useCountdown()

    // 请求code
    const getCode = () => {
        setLoading(true)
        fetch(`${base_url}/api/v1/acc/login/code`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Connection": "keep-alive",
                "ApplicationType": "1,1",
                "Accept": "*/*",
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
                "Content-Length": "62",
                "Accept-Language": "zh-TW,zh-Hant;q=0.9",
                "Accept-Encoding": "gzip, deflate, br"
            },
            body: JSON.stringify({
                "s": s,
                "authCode": captcha,
                "un": phone
            })
        })
            .then(async res => {
                setLoading(false)
                if (res.ok) {
                    const status = (await res.json()).code
                    if (status === 0) {
                        alert("验证码已发送，请注意查收")
                        startCountdown()
                    } else if (status === -2) {
                        alert("图形验证码错误")
                    } else {
                        alert("未知错误")
                    }
                }
            })
            .catch(err => {
                setLoading(false)
                console.error(err)
            })
    }

    // 登录
    const router = useRouter()
    const login = () => {
        fetch(`${base_url}/api/v1/acc/login`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Connection": "keep-alive",
                "ApplicationType": "1,1",
                "Accept": "*/*",
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
                "Content-Length": "95",
                "Accept-Language": "zh-TW,zh-Hant;q=0.9",
                "Accept-Encoding": "gzip, deflate, br"
            },
            body: JSON.stringify({
                "openCode": "",
                "un": phone,
                "authCode": sms,
                "cid": ""
            })
        })
            .then(async res => {
                if (res.ok) {
                    const json = (await res.json())
                    if (json.code === 0) {
                        const data = json.data
                        serializeToLocalStorage('data', data)
                        router.push("/control")
                    } else if (json.code === -2) {
                        alert("验证码错误")
                    } else {
                        alert("未知错误")
                    }
                }
            })
            .catch(err => {
                console.error(err)
            })
    }

    return (
        <main>
            <div className={"mt-4"}>
                <Input placeholder={"手机号码..."} addonBefore={<TbUserFilled/>} size={"large"}
                       onInput={handlePhoneChange} value={phone}/>
            </div>

            <div className={"mt-4 flex items-center"}>
                <Input placeholder={"图形验证码..."} size={"large"} onInput={handleCaptchaChange} value={captcha}/>
                <Captcha base_url={base_url} s={s} r={r}/>
            </div>

            <div className={"mt-4 flex items-center"}>
                <Input placeholder={"手机验证码..."} onInput={handleSmsChange} value={sms}/>
                <Button className={"ml-2"} disabled={phone.length < 11 || captcha.length === 0 || isRunning}
                        onClick={getCode} loading={loading}>{countdown === 60 ? "获取" : countdown}</Button>
            </div>

            <div className={"flex justify-center mt-4"}>
                <Button
                    type={"primary"}
                    className={"w-3/5"}
                    size={"large"}
                    disabled={phone.length < 11 || captcha.length === 0 || sms.length < 6}
                    onClick={login}
                >登录</Button>
            </div>
        </main>
    )
}
