import type {Metadata} from "next";
import "./globals.css";
import {AntdRegistry} from "@ant-design/nextjs-registry";

export const metadata: Metadata = {
    title: "慧生活798（良心版）",
    description: "慧生活798去广告良心版。",
};

export default function RootLayout({
                                       children,
                                   }: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="en">
        ++ <link rel="manifest" href="/manifest.json"/>
        <body>
        <AntdRegistry>{children}</AntdRegistry>
        </body>
        </html>
    );
}
