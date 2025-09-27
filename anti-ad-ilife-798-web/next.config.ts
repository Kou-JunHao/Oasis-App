import type { NextConfig } from "next";
import withPWA from "next-pwa";

const nextConfig = withPWA({
    dest: 'public', // 将 Service Worker 文件生成到 public 目录
    register: true, // 自动注册 Service Worker
    skipWaiting: true, // 跳过等待阶段，立即激活新的 Service Worker
})({});

export default nextConfig;
