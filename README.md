<h1>vcp-sidecar-guide</h1>
<p><strong>Official Sidecar Integration Guide for VCP Silver Tier — non-invasive implementation for MT4/MT5, cTrader, and white-label environments.</strong></p>

<p>This repository provides the official implementation guide for integrating the <strong>VeritasChain Protocol (VCP)</strong> into platforms that <strong>do not have server-level privileges</strong>, such as MT4/MT5 white-label servers, cTrader WL instances, and proprietary FX/CFD environments.</p>

<p>The Sidecar model enables <strong>tamper-evident cryptographic logging</strong> without modifying existing trading infrastructure.</p>

<hr>

<h2>📘 Purpose</h2>
<p>The <strong>VCP Sidecar Integration Guide</strong> defines how to implement VCP logging using:</p>
<ul>
  <li><strong>vcp-mql-bridge</strong> (MQL5 client-side hook)</li>
  <li><strong>Manager API integration</strong> (MT4/MT5 server-side read-only polling)</li>
  <li><strong>Hybrid 2-Layer Logging Architecture</strong></li>
  <li><strong>VCP Explorer API v1.1</strong> (Merkle proof &amp; certificate verification)</li>
</ul>
<p>It is the official technical reference for organizations aiming to deploy <strong>VCP Silver Tier</strong> and/or obtain <strong>VC-Certified</strong> compliance.</p>

<hr>

<h2>🧩 Repository Structure (recommended)</h2>
<pre><code>/docs
  SIDEcar_GUIDE_en.md
  SIDEcar_GUIDE_ja.md
  diagrams/

/examples
  mql5/
  python/
  c++/

/schema
  vcp-event.schema.json

LICENSE
README.md
</code></pre>

<hr>

<h2>🚀 What is the Sidecar Integration Model?</h2>
<p>The Sidecar model is a <strong>non-invasive, parallel logging architecture</strong> that records:</p>
<ul>
  <li><strong>SIG</strong> (Signal)</li>
  <li><strong>ORD</strong> (Order Sent)</li>
  <li><strong>ACK</strong> (Order Acknowledged)</li>
  <li><strong>EXE</strong> (Execution)</li>
  <li><strong>REJ</strong> (Rejection)</li>
  <li><strong>CXL</strong> (Cancel)</li>
  <li><strong>PRT</strong> (Partial Fill)</li>
  <li><strong>RISK</strong> snapshots</li>
  <li><strong>GOV</strong> (Algorithm governance metadata)</li>
  <li><strong>HBT/REC</strong> (heartbeat &amp; recovery)</li>
</ul>

<p>…using cryptographic primitives defined in <strong>VCP Specification v1.0</strong>:</p>
<ul>
  <li>UUID v7</li>
  <li>RFC 8785 canonical JSON</li>
  <li>SHA-256 hash chain</li>
  <li>RFC 6962 Merkle trees</li>
  <li>Ed25519 delegated signatures</li>
</ul>

<p>The Sidecar model allows full VCP compliance <strong>without modifying platform internals</strong>, enabling deployment on:</p>
<ul>
  <li>MT4/MT5 White-Label servers</li>
  <li>cTrader instances</li>
  <li>Proprietary FX engines</li>
  <li>Any environment lacking root access</li>
</ul>

<hr>

<h2>🔧 Core Documents</h2>

<h3>📄 VCP Sidecar Integration Guide v1.0</h3>
<p>The complete implementation guide (EN/JA) is available in <code>/docs</code>.</p>
<p>Includes:</p>
<ul>
  <li>Architecture diagrams</li>
  <li>MQL5 bridge implementation</li>
  <li>Manager API polling adapter</li>
  <li>2-layer event correlation</li>
  <li>Recovery &amp; fault tolerance</li>
  <li>Security &amp; compliance requirements</li>
  <li>Silver Tier technical requirements</li>
  <li>Full JSON schema &amp; checklists</li>
</ul>

<h3>📚 Related specs</h3>
<ul>
  <li>VCP Specification v1.0</li>
  <li>VCP Explorer API v1.1</li>
  <li>VC-Certified Compliance Guide</li>
</ul>

<hr>

<h2>🧪 Conformance &amp; Certification</h2>
<p>Organizations implementing Silver Tier integration can obtain:</p>

<h3>✔ VC-Certified (Silver)</h3>
<p>Verifies that:</p>
<ul>
  <li>All required event types are implemented</li>
  <li>Timestamp precision meets standard</li>
  <li>Numeric fields use string encoding</li>
  <li>Merkle proof validation succeeds</li>
  <li>Log integrity is cryptographically verifiable</li>
</ul>

<hr>

<h2>🌐 Maintained by</h2>
<h3>VeritasChain Standards Organization (VSO)</h3>
<p>Independent, vendor-neutral standards body defining VCP — the global cryptographic audit standard for algorithmic trading.</p>
<ul>
  <li>Website: <a href="https://veritaschain.org">https://veritaschain.org</a></li>
  <li>GitHub: <a href="https://github.com/veritaschain">https://github.com/veritaschain</a></li>
  <li>Email: <a href="mailto:technical@veritaschain.org">technical@veritaschain.org</a></li>
</ul>

<hr>

<h2>📜 License</h2>
<p>CC BY 4.0 International</p>
