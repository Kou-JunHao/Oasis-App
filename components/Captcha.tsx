'use client';
import {useEffect, useState} from "react";

type CaptchaProps = {
    base_url: string;
    s: number;
    r: number;
}

// 请求Captcha方法
const getCaptcha = async (base_url: string, s: number, r: number) => {
    const res = await fetch(base_url + `/api/v1/captcha/?s=${s}&r=${r}`, {
        method: "GET",
        headers: {
            "Sec-Fetch-Dest": "image",
            "Sec-Fetch-Site": "cross-site",
            "Sec-Fetch-Mode": "no-cors",
            "Connection": "keep-alive",
            "Accept": "image/webp,image/avif,image/jxl,image/heic,image/heic-sequence,video/*;q=0.8,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Html5Plus/1.0 (Immersed/20) uni-app",
            "Accept-Language": "zh-TW,zh-Hant;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
        }
    })

    const buffer = await res.arrayBuffer()
    const base64Image = `data:image/jpeg;base64,${Buffer.from(buffer).toString('base64')}`
    console.log(base64Image)
    return base64Image
}

export default function Captcha({base_url, s, r}: CaptchaProps) {
    const [captcha, setCaptcha] = useState<string | undefined>(undefined)
    const getCaptchaImage = () => {
        getCaptcha(base_url, s, r)
            .then((base64Image) => {
                setCaptcha(base64Image)
            })
            .catch((err) => {
                console.error(err)
            })
    }
    useEffect(() => {
        getCaptchaImage()
    }, [])

    return (
        <img src={captcha} onClick={getCaptchaImage} className={"ml-2"}/>
    )
}
