import { useState, useEffect } from "react";

function useCountdown() {
    const [countdown, setCountdown] = useState(60); // 初始为 60 秒
    const [isRunning, setIsRunning] = useState(false); // 控制是否运行倒计时

    useEffect(() => {
        if (!isRunning) return;

        const timer = setInterval(() => {
            setCountdown((prev) => {
                if (prev <= 1) {
                    clearInterval(timer); // 倒计时结束，清除计时器
                    setIsRunning(false); // 停止倒计时
                    return 60; // 重置为 60
                }
                return prev - 1; // 递减
            });
        }, 1000);

        return () => clearInterval(timer); // 清除副作用
    }, [isRunning]);

    const startCountdown = () => {
        if (!isRunning) {
            setCountdown(60); // 每次开始倒计时时重置为 60
            setIsRunning(true);
        }
    };

    return { countdown, startCountdown, isRunning };
}

export default useCountdown;
