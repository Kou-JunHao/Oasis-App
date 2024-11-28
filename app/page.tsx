import Main from "@/components/Main";
import {getBaseUrl} from "@/utils/BaseURL";

export default function Home() {
    // 设定相关参数
    const base_url = getBaseUrl()
    const s = Math.random()
    const r = new Date().getTime()

    return (
         <div className={"w-full h-full flex flex-col justify-center items-center"}>
            <h1 className={"font-bold text-3xl"}>慧生活 798 助手</h1>
            <div className={"mt-4 text-gray-400"}>Fuck you, the iLife 798 full of ads!</div>

            <div className={"main-panel"}>
                <Main base_url={base_url} s={s} r={r}/>
            </div>

            <div className={"text-center ml-6 mr-6 text-sm mt-6 text-red-700"}>* 作者郑重承诺，您在本站所输入和生成的所有数据，包括但不限于手机号、验证码、Token等均将保存在前端即本地，不会以任何形式上传到任何云端。</div>

            <div className={"mt-6 text-gray-300"}>Powered by <a href={"https://www.kynix.tw/"} className={"underline text-blue-400"}>Adrian Chen</a></div>
        </div>
    );
}
