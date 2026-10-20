# Draft issue for M3-org/CharacterStudio (not filed)

**Title:** Secrets reach the client bundle, a private key is committed, and wallet prompts can start without a click

**Body:**

Hello, and thank you for CharacterStudio. While evaluating the editor at commit `293182b` (May 8, 2026), we read the source and ran the editor locally with the wallet code removed. A few things look risky for anyone who deploys or forks it. File references are at that commit.

1. **API secrets are read through `VITE_` variables, so they end up in the shipped JavaScript.**
   Vite inlines every `import.meta.env.VITE_*` value into the client bundle.
   - `src/library/mint-utils.js:16-17` reads `VITE_PINATA_API_KEY` and `VITE_PINATA_API_SECRET`, and `:398-399` sends them as headers. A build with these set publishes the Pinata secret to every visitor.
   - The same applies to:
     - `VITE_OPENSEA_KEY` (`mint-utils.js:13`, `src/pages/Landing.jsx:11`)
     - `VITE_HELIUS_KEY` (`mint-utils.js:10-11`, `src/library/solanaManager.js:3-4`)
     - `VITE_ALCHEMY_API_KEY` (`mint-utils.js:523`)

   *Suggested fix:* move the pinning and RPC calls that need a secret behind a small server, which could be the validation server the code already calls. Keep only public, origin-restricted keys in `VITE_` variables, and document which ones are safe to expose.

2. **A TLS private key is committed.**
   `key.pem` (a PEM private key) and `cert.pem` are tracked at the repository root. Nothing in `vite.config.js` reads them.

   *Suggested fix:* remove both, add `*.pem` to `.gitignore`, and treat the key as compromised wherever it was used. For local HTTPS, generate a certificate per machine; `@vitejs/plugin-basic-ssl` is already a dependency.

3. **Loading a manifest can open a wallet connection without a user action.**
   - `CharacterManifestData` calls `this.unlockPurchasedAssetsWithWallet()` while it parses a manifest (`src/library/CharacterManifestData.js:171`).
   - When the manifest has `solanaPurchaseAssets`, this reaches `connectWallet("solana")` (`src/library/walletCollections.js:29-31`) and `window.solana.connect()` (`mint-utils.js:310`).
   - Manifests can be remote (`public/manifest.json` lists three on `m3-org.github.io`). A manifest's contents therefore decide whether a wallet prompt appears.

   *Suggested fix:* connect only from an explicit button, and have manifest parsing record that assets are lockable without connecting.

4. **A server-built transaction is signed with no check in the app.**
   - `buySolanaPurchasableAssets` posts to `${VITE_VALIDATION_SERVER_URL}/request-payment` (`mint-utils.js:116`).
   - It passes the returned base64 transaction to `solana.signTransaction` and `sendRawTransaction` (`mint-utils.js:149-167`).
   - The wallet's own dialog is the only place the user sees what is signed.

   *Suggested fix:* decode the transaction before signing and check its program IDs, recipient and amount against what the UI showed. Prefer `signAndSendTransaction` so the wallet simulates it.

5. **Smaller items.**
   - `mint-utils.js:292` compares against an undeclared `ethereum`. That resolves to `window.ethereum`, so the comparison is always false and Ethereum requests switch to Polygon.
   - `walletCollections.js:58` uses an undeclared `network`, which throws a ReferenceError.
   - `src/components/WalletMenu.jsx:45` hard-codes a test wallet address, and `:50` redirects to `http://localhost:5000/auth/github`.
   - `.github/workflows/main.yml:43` runs `npm install` (not `npm ci`) in the deploy job, so install scripts run with an unpinned resolution. The job holds `contents: write` and a deploy key, and `peaceiris/actions-gh-pages@v3` is pinned by tag rather than by commit SHA (`:30-31`, `:49-51`).
   - `package.json:18` (`get-assets`) clones `loot-assets` at the head of `main`, unpinned.
   - `npm audit --omit=dev` reports 59 production vulnerabilities (30 high) at this commit. Most are in the web3 tree; the high ones include `axios`, `ws`, `undici`, `vite`, `lodash`, `form-data` and `bigint-buffer`.

6. **Two behaviours seen while running the editor.**
   - Headless Chrome 148 with SwiftShader.
   - The GLB export throws `Cannot set properties of undefined (setting 'mergeAppliedMorphs')` after logging "XXX fix glb downloader" (`src/library/characterManager.js:364`), and no file is produced.
   - The VRM 0 export produced a file in 2 of 8 attempts. In the other six, no file appeared and the page stopped answering for at least three minutes. That included every attempt with the Anata female `plate_mail` chest worn.

   We have not established whether the hang occurs on hardware GL.

7. **A design question about culling, offered for the docs.**
   - In the Anata female manifest, `Body` and `Chest` both have culling layer 0, and the other groups have -1. So nothing is culled as shipped.
   - With `Chest` raised to layer 1, rays from 906 body faces hit the plate mail's front face and then its back face. The front/back cancel (`src/library/cull-mesh.js:302-322`) then keeps all of them, because the garment is a closed shell. With the cancel switched off, 809 of 12,908 body triangles were culled.

   It may help modders if the docs said that culling only removes faces under single-surface garments.

We have not used a wallet with the app, and none of the above was exploited. These come from reading the code and running it locally. Happy to clarify any of them.
