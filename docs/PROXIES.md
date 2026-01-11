# Proxy Patterns (demos)

| Pattern | What it proves | Key guardrail | Production analog |
|---|---|---|---|
| Minimal Proxy | delegatecall 上下文 + 存储布局差异（直调 vs 代理） | storage layout 必须对齐 | EIP-1967 storage slots |
| SimpleUpgrade | upgrade 在 proxy 上（admin 改 implementation） | demo：fallback 不冒泡返回值（限制） | Transparent Proxy / EIP-1967 |
| Transparent Proxy | admin 不能走 fallback，避免 selector 冲突；return/revert 冒泡 | admin isolation | OZ TransparentUpgradeableProxy |
| UUPS-style (demo) | upgrade 逻辑在实现合约里，通过 delegatecall 修改 proxy 存储 | demo：非 OZ UUPS（无 UUID/authorize hook） | OZ UUPSUpgradeable + ERC1967 |

## Verify
- Minimal Proxy: `forge test --match-path test/proxies/MinimalProxy.t.sol -vvv`
- SimpleUpgrade: `forge test --match-path test/proxies/SimpleUpgrade.t.sol -vvv`
- Transparent: `forge test --match-path test/proxies/TransparentProxy.t.sol -vvv`
- DemoUUPS: `forge test --match-path test/proxies/DemoUUPS.t.sol -vvv`



