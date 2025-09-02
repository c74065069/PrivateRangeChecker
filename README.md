# ZAMA Private Range Check (FHEVM)

The dApp encrypts a user’s uint32 client-side, verifies on-chain whether it lies in [lower, upper), and returns an encrypted boolean. Supports contract or custom bounds and both private (EIP-712 userDecrypt) and public decryption.

---

## ✨ Features

* 🔐 **Private input** (`euint32`) encrypted client‑side via Relayer SDK
* 📏 Public bounds from the contract (`lowerBound()`, `upperBound()`), or **custom bounds** per call
* ✅ Interval semantics: **inclusive lower**, **exclusive upper** → `[lower, upper)`
* 📤 Emits `RangeChecked(user, lower, upper, resultHandle)` so UI can pick up the ciphertext handle
* 🔓 **Two decryption modes**

  * **Private**: `userDecrypt` with EIP‑712 signature (caller sees the result)
  * **Public**: `makeLastPublic()` + `publicDecrypt` (anyone can read)
* 🧭 **Network guard**: forces **Sepolia** chain
* 🧪 **Verbose developer logs** in the browser Console (encryption handles, proofs sizes, tx/receipt details, parsed events)

---

## 🧱 Smart Contract

Solidity uses the official Zama library only:

```solidity
import { FHE, ebool, euint32, externalEuint32 } from "@fhevm/solidity/lib/FHE.sol";
```

### Public API (subset)

* `function lowerBound() external view returns (uint32)`
* `function upperBound() external view returns (uint32)`
* `function checkInRange(externalEuint32 xExt, bytes calldata proof) external returns (ebool inRangeCt)`
* `function checkInRangeWithBounds(externalEuint32 xExt, uint32 lower, uint32 upper, bytes calldata proof) external returns (ebool inRangeCt)`
* `function getLastResultHandle() external view returns (bytes32)`
* `function makeLastPublic() external` (marks last result as publicly decryptable)

**Event**

```solidity
event RangeChecked(address indexed user, uint32 lower, uint32 upper, bytes32 resultHandle);
```

> **Note**: Avoid FHE operations in `view`/`pure` functions. Access control uses `FHE.allow`, `FHE.allowThis`, and `FHE.makePubliclyDecryptable` only.

---

## 🖥️ Frontend (static)

Single‑file UI in **`frontend/public/index.html`**:

* Connects MetaMask → Sepolia
* Creates encrypted inputs via **Relayer SDK** (`createEncryptedInput().add32(...).encrypt()`)
* Sends `(handle, proof)` to the contract
* Subscribes to `RangeChecked` to obtain `resultHandle`
* Supports **private** and **public** decryption flows
* Includes **extensive Console logs**: encryption handles, proof length, tx fields, receipts, parsed events

> Tip: open DevTools → **Console** and look for grouped logs: `RangeUI connect`, `encrypt`, `sendTx`, `receipt`, `events`, `eip712`, `userDecrypt`.

---

## 📦 Project Structure

```
root/
├─ contracts/
│  └─ PrivateRangeChecker.sol           # FHEVM contract (interval check)
├─ deploy/
│  └─ 001_deploy_private_range_checker.ts  # hardhat-deploy script (Sepolia)
├─ frontend/
│  └─ public/
│     └─ index.html                    # this app’s UI (no build step required)
├─ hardhat.config.ts
└─ README.md
```

> Your repository may contain more files; the crucial part for the app is **`frontend/public/index.html`**.

---

## 🚀 Quick Start (Frontend‑only)

> Requires: **Node 18+**, a local static server, and MetaMask.

1. **Clone** the repo

```bash
git clone <your-repo-url>
cd <repo-folder>
```

2. **Serve** the UI from `frontend/public` (any static server works)

```bash
# Option A: http-server
npx http-server frontend/public -p 5173

# Option B: serve
npx serve -s frontend/public -l 5173

# Option C: python (3.8+)
python3 -m http.server 5173 --directory frontend/public
```

3. Open **[http://localhost:5173](http://localhost:5173)** → click **Connect Wallet** → ensure **Sepolia** → enter number → **Encrypt & Check** → **Decrypt**.

Meta tags in `index.html` already enable COOP/COEP for WASM used by the Relayer SDK.

---

## 🔧 Full Dev Setup (Contract + Deploy)

> If you only need the UI against the existing deployment, skip this section.

**Prerequisites**

* Node 18+
* pnpm / npm
* Sepolia RPC, funded deployer key

**Install**

```bash
pnpm install   # or npm i
```

**Configure** `.env` (example)

```ini
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<KEY>
PRIVATE_KEY=0xabc... # deployer
```

**Deploy**

```bash
npx hardhat deploy --network sepolia
```

**Verify** (optional)

```bash
npx hardhat verify --network sepolia <deployed_address> <constructor_args_if_any>
```

> The app UI uses the address hard‑coded in `frontend/public/index.html`. Update it there if you redeploy.

---

## 🧭 How It Works (Flow)

1. **Encrypt client‑side** using Relayer SDK:

   * `createEncryptedInput(contract, user)`
   * `add32(x)` → `encrypt()` → returns `(handles[], inputProof)`
2. **Call** smart contract with `(handle, proof[, lower, upper])`
3. Contract runs FHE comparisons: `FHE.ge(x, lower)`, `FHE.lt(x, upper)` → encrypted `ebool`
4. Contract **ACL**: `FHE.allow(result, msg.sender)` and optionally `FHE.makePubliclyDecryptable(result)`
5. UI gets `resultHandle` from `RangeChecked` and **decrypts** either via **userDecrypt** (private) or **publicDecrypt** (public)

Semantics are **\[lower, upper)** (inclusive lower, exclusive upper).

---

## 🧪 Troubleshooting

* **"OUT OF RANGE" but number looks valid**

  * Check **interval semantics**: `[lower, upper)`; `upper` is **exclusive**
  * Use **Refresh bounds** to pull current on‑chain lower/upper
* **Relayer errors**: ensure page is served with the included meta tags (COOP/COEP) and that the CDN resources load without CORS issues in Network tab
* **EIP‑712 userDecrypt fails**: re‑connect wallet; signatures expire (the UI creates a new `startTs`/`days` window per decrypt)
* **Sepolia network prompts**: the UI enforces Sepolia; approve the network switch in MetaMask
* **Nonce / fee errors during deploy**: bump gas or cancel/replace pending tx; ensure the account nonce on the RPC is clean

---

## 🔗 Useful Links

* Zama Protocol — Solidity operations guide: [https://docs.zama.ai/protocol/solidity-guides/smart-contract/operations/](https://docs.zama.ai/protocol/solidity-guides/smart-contract/operations/)
* Relayer SDK Guides: [https://docs.zama.ai/protocol/relayer-sdk-guides/](https://docs.zama.ai/protocol/relayer-sdk-guides/)

**Download** (GitHub ZIP):

* Replace with your repo URL: [Download ZIP](https://github.com/<your-username>/<your-repo>/archive/refs/heads/main.zip)

---

## 📜 License

MIT — see `LICENSE`.


