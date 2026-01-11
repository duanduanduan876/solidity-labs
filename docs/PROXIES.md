Minimal Proxy：delegatecall + 存储差异演示（无升级）

SimpleUpgrade：升级在 proxy 上（admin upgrade），fallback 不回传返回值（教学限制）

Transparent：admin 不能走 fallback，避免 selector 冲突（return/revert 冒泡）

DemoUUPS：upgrade 在逻辑合约里，delegatecall 修改 proxy 存储（说明：教学版，不是 OZ UUPS）

生产版对应：EIP-1967 / Transparent / UUPS(OZ)


