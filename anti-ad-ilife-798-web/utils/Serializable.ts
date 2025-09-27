type Serializable = Record<string, any>;

export function serializeToLocalStorage(key: string, data: Serializable): void {
    try {
        const jsonData = JSON.stringify(data);
        localStorage.setItem(key, jsonData);
    } catch (error) {
        console.error("Failed to serialize data:", error);
    }
}

export function deserializeFromLocalStorage<T>(key: string): T | null {
    try {
        const jsonData = localStorage.getItem(key);
        return jsonData ? JSON.parse(jsonData) as T : null;
    } catch (error) {
        console.error("Failed to deserialize data:", error);
        return null;
    }
}
