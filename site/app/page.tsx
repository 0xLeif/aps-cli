const installCommand = "brew install 0xLeif/tap/aps";

const commands = [
  {
    command: "aps get note --json",
    label: "Read",
    output: '{"key":"note","value":"ship it"}',
  },
  {
    command: "aps set flag true",
    label: "Write",
    output: "set flag = true",
  },
  {
    command: "aps watch profileName --jsonl",
    label: "Observe",
    output: '{"type":"change","value":"leif"}',
  },
  {
    command: "aps schema --json",
    label: "Discover",
    output: '{"schemaVersion":4,"keys":[…]}',
  },
];

const surfaces = [
  {
    title: "For your terminal",
    description:
      "Human output stays concise and readable. Tables align, colors carry meaning, and errors tell you what to do next.",
    mark: "tty",
  },
  {
    title: "For your agents",
    description:
      "JSON, JSONL, stable exit codes, and a self-describing schema give automation a contract it can cache and trust.",
    mark: "{}",
  },
  {
    title: "For your builds",
    description:
      "Run the same state surface through fledge, isolate it with APS_HOME, and exercise it across macOS, Linux, and Windows.",
    mark: "ci",
  },
];

const storage = [
  ["State", "Process-local values"],
  ["StoredState", "UserDefaults persistence"],
  ["FileState", "Portable JSON files"],
  ["EncryptedFile", "Encrypted state at rest"],
  ["Slice", "Typed projections"],
];

export default function Home() {
  return (
    <main>
      <header className="site-header">
        <a className="wordmark" href="#top" aria-label="aps home">
          <span className="wordmark-mark" aria-hidden="true">
            @
          </span>
          <span>aps</span>
        </a>
        <nav aria-label="Primary navigation">
          <a href="#why">Why aps</a>
          <a href="#commands">Commands</a>
          <a href="#architecture">Architecture</a>
          <a href="https://github.com/0xLeif/aps-cli">GitHub</a>
        </nav>
        <a className="header-cta" href="#install">
          Install
        </a>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <p className="eyebrow">
            <span className="status-dot" aria-hidden="true" />
            Swift state, outside SwiftUI
          </p>
          <h1>
            State you can see.
            <span>Contracts you can trust.</span>
          </h1>
          <p className="hero-deck">
            aps is a tiny Swift CLI that brings AppState to the terminal. Declare
            typed state, read it, change it, watch it, and hand the same stable
            contract to humans, agents, and CI.
          </p>
          <div className="hero-actions" id="install">
            <code>
              <span aria-hidden="true">$</span> {installCommand}
            </code>
            <a href="https://github.com/0xLeif/aps-cli/releases">
              View releases <span aria-hidden="true">↗</span>
            </a>
          </div>
          <div className="release-line" aria-label="Project status">
            <span>v1.0 available</span>
            <span>v1.1 hardening in progress</span>
            <span>Swift 6</span>
          </div>
        </div>

        <div className="state-console" aria-label="Live state transition example">
          <div className="console-bar">
            <span>state tape</span>
            <div aria-hidden="true">
              <i />
              <i />
              <i />
            </div>
          </div>
          <div className="schema-block">
            <p>
              <span className="syntax-key">let</span> profile ={" "}
              <span className="syntax-type">@FileState</span>(
            </p>
            <p className="indent">
              key: <span className="syntax-string">&quot;profile&quot;</span>,
            </p>
            <p className="indent">
              value: <span className="syntax-value">Profile</span>(
            </p>
            <p className="indent-2">
              name: <span className="syntax-string">&quot;leif&quot;</span>,
            </p>
            <p className="indent-2">
              version: <span className="syntax-number">1</span>
            </p>
            <p className="indent">)</p>
            <p>)</p>
          </div>
          <div className="tape" aria-hidden="true">
            <span className="tape-label">watch</span>
            <div className="tape-track">
              <i />
            </div>
            <span className="tape-value">leif</span>
            <span className="tape-arrow">→</span>
            <span className="tape-value active">corvid</span>
          </div>
          <div className="console-output">
            <span className="prompt">$</span>
            <span>aps set profileName corvid</span>
            <strong>updated in 12ms</strong>
          </div>
        </div>
      </section>

      <section className="manifesto" id="why">
        <p className="section-kicker">One state root. Three native surfaces.</p>
        <div className="surface-grid">
          {surfaces.map((surface) => (
            <article key={surface.title}>
              <span className="surface-mark" aria-hidden="true">
                {surface.mark}
              </span>
              <h2>{surface.title}</h2>
              <p>{surface.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="command-section" id="commands">
        <div className="section-heading">
          <div>
            <p className="section-kicker">A small command surface</p>
            <h2>Get in. Change state. Keep moving.</h2>
          </div>
          <p>
            The same verbs work across built-in and user-defined keys. Output
            changes for the audience, never the underlying contract.
          </p>
        </div>
        <div className="command-grid">
          {commands.map((item) => (
            <article key={item.label}>
              <span>{item.label}</span>
              <code>
                <b aria-hidden="true">$</b> {item.command}
              </code>
              <samp>{item.output}</samp>
            </article>
          ))}
        </div>
      </section>

      <section className="architecture" id="architecture">
        <div className="architecture-copy">
          <p className="section-kicker">A Swift-first architecture</p>
          <h2>Typed at the edges. Honest in the middle.</h2>
          <p>
            Your state root carries a versioned <code>schema.json</code>. aps
            resolves each registered key through an AppState-backed adapter,
            then exposes predictable human and machine output.
          </p>
          <a href="https://github.com/0xLeif/aps-cli/blob/main/docs/design/dynamic-schema.md">
            Read the dynamic schema design <span aria-hidden="true">→</span>
          </a>
        </div>
        <div className="architecture-map" aria-label="aps architecture">
          <div className="map-source">
            <span>01</span>
            <strong>schema.json</strong>
            <small>versioned registry</small>
          </div>
          <div className="map-connector" aria-hidden="true">
            <i />
            <span>resolve</span>
          </div>
          <div className="map-storage">
            {storage.map(([name, detail]) => (
              <div key={name}>
                <strong>{name}</strong>
                <small>{detail}</small>
              </div>
            ))}
          </div>
          <div className="map-connector output" aria-hidden="true">
            <i />
            <span>render</span>
          </div>
          <div className="map-output">
            <span>TTY</span>
            <span>JSON</span>
            <span>JSONL</span>
          </div>
        </div>
      </section>

      <section className="platform-strip" aria-label="Supported platforms">
        <p>Built in Swift. Verified where you ship.</p>
        <div>
          <span>macOS</span>
          <span>Linux</span>
          <span>Windows</span>
          <span>Swift 6</span>
          <span>GitHub Actions</span>
        </div>
      </section>

      <section className="quality">
        <div>
          <p className="section-kicker">Built in public</p>
          <h2>The project tells you what is solid and what comes next.</h2>
        </div>
        <div className="quality-copy">
          <p>
            aps ships with SpecSync contracts, cross-platform smoke tests, and
            the CorvidLabs trust toolchain. The next release is focused on
            filesystem safety, stronger secret handling, and end-to-end
            distribution tests.
          </p>
          <div>
            <a href="https://github.com/0xLeif/aps-cli/blob/main/docs/release-readiness.md">
              Release readiness
            </a>
            <a href="https://github.com/0xLeif/aps-cli/tree/main/specs">
              Browse contracts
            </a>
          </div>
        </div>
      </section>

      <section className="closing">
        <p className="section-kicker">Your state is already there</p>
        <h2>Give it a command line.</h2>
        <code>
          <span aria-hidden="true">$</span> {installCommand}
        </code>
        <a href="https://github.com/0xLeif/aps-cli">
          Explore aps on GitHub <span aria-hidden="true">↗</span>
        </a>
      </section>

      <footer>
        <a className="wordmark" href="#top">
          <span className="wordmark-mark" aria-hidden="true">
            @
          </span>
          <span>aps</span>
        </a>
        <p>A Swift CLI by 0xLeif. Built with AppState and CorvidLabs trust.</p>
        <div>
          <a href="https://github.com/0xLeif/aps-cli">GitHub</a>
          <a href="https://github.com/0xLeif/AppState">AppState</a>
          <a href="https://corvidlabs.xyz">CorvidLabs</a>
        </div>
      </footer>
    </main>
  );
}
