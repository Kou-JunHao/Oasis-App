import DeviceList from "@/components/DeviceList";
import {getBaseUrl} from "@/utils/BaseURL";
import LogoutBtn from "@/components/LogoutBtn";

export default function Control() {
    const base_url = getBaseUrl()

    return (
        <div>
            <h1 className={"m-4 text-2xl font-bold"}>设备列表</h1>
            <DeviceList base_url={base_url}/>
            <LogoutBtn base_url={base_url}/>
        </div>
    )
}
