import { useEffect, useRef, useState, type ReactNode } from "react"

type IconName = "grid" | "cpu" | "storage" | "apps" | "battery" | "tools" | "shield" | "settings" | "help" | "arrow" | "refresh" | "check" | "info" | "phone" | "chevron" | "sun" | "moon" | "folder" | "file" | "search" | "close" | "activity" | "lock" | "more"
const paths: Record<IconName, ReactNode> = {
  grid: (
    <>
      <rect x="3" y="3" width="7" height="7" rx="1.5" />
      <rect x="14" y="3" width="7" height="7" rx="1.5" />
      <rect x="3" y="14" width="7" height="7" rx="1.5" />
      <rect x="14" y="14" width="7" height="7" rx="1.5" />
    </>
  ),
  cpu: (
    <>
      <rect x="6" y="6" width="12" height="12" rx="2" />
      <path d="M9 1v5m6-5v5M9 18v5m6-5v5M1 9h5m-5 6h5m12-6h5m-5 6h5" />
      <rect x="9" y="9" width="6" height="6" rx="1" />
    </>
  ),
  storage: (
    <>
      <path d="M5 3h14l3 11v5a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-5L5 3Z" />
      <path d="M2 14h20M6 17h.01M10 17h.01" />
    </>
  ),
  apps: (
    <>
      <rect x="3" y="3" width="7" height="7" rx="2" />
      <rect x="14" y="3" width="7" height="7" rx="2" />
      <rect x="3" y="14" width="7" height="7" rx="2" />
      <path d="M17.5 14v7M14 17.5h7" />
    </>
  ),
  battery: (
    <>
      <rect x="3" y="6" width="17" height="12" rx="2" />
      <path d="M23 10v4M7 10v4m4-4v4m4-4v4" />
    </>
  ),
  tools: (
    <path d="m14 6 4 4 3-3a6 6 0 0 1-8 8l-6 6a2.8 2.8 0 0 1-4-4l6-6a6 6 0 0 1 8-8l-3 3Z" />
  ),
  shield: (
    <>
      <path d="m12 2 9 4v6c0 5-9 10-9 10S3 17 3 12V6l9-4Z" />
      <path d="m8 12 3 3 5-6" />
    </>
  ),
  settings: (
    <>
      <path d="m9 3 1-1h4l1 3 3 1 3 1v4l-2 2-1 3v3l-4 2-3-2-3-1-3-1v-4l2-2 1-3V5l1-2Z" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
  help: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M9 9a3 3 0 0 1 6 0c0 2-3 2-3 4m0 3h.01" />
    </>
  ),
  arrow: <path d="M4 12h16m-6-6 6 6-6 6" />,
  refresh: (
    <>
      <path d="M20 8a8 8 0 0 0-14-3L3 8m0-5v5h5M4 16a8 8 0 0 0 14 3l3-3m0 5v-5h-5" />
    </>
  ),
  check: <path d="m5 12 4 4L19 6" />,
  info: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 11v6m0-10h.01" />
    </>
  ),
  phone: (
    <>
      <rect x="6" y="2" width="12" height="20" rx="3" />
      <path d="M10 5h4m-3 14h2" />
    </>
  ),
  chevron: <path d="m9 5 7 7-7 7" />,
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 1v2m0 18v2M1 12h2m18 0h2M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2" />
    </>
  ),
  moon: <path d="M20 15A9 9 0 0 1 9 4a9 9 0 1 0 11 11Z" />,
  folder: (
    <path d="M3 7V5a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z" />
  ),
  file: (
    <>
      <path d="M14 2H5v20h14V7l-5-5Zm0 0v6h5M8 12h8m-8 4h6" />
    </>
  ),
  search: (
    <>
      <circle cx="10" cy="10" r="7" />
      <path d="m15 15 6 6" />
    </>
  ),
  close: <path d="m6 6 12 12M6 18 18 6" />,
  activity: <path d="M2 12h4l3-8 5 16 3-8h5" />,
  lock: (
    <>
      <rect x="4" y="10" width="16" height="12" rx="2" />
      <path d="M8 10V6a4 4 0 0 1 8 0v4m-4 5v3" />
    </>
  ),
  more: (
    <>
      <circle cx="5" cy="12" r="1" />
      <circle cx="12" cy="12" r="1" />
      <circle cx="19" cy="12" r="1" />
    </>
  ),
}
function Icon({
  name,
  size = 20,
  className = "",
}: {
  name: IconName
  size?: number
  className?: string
}) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.65"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  )
}
type Page = "Dashboard" | "Process Manager" | "Storage Cleaner" | "Application Manager" | "Battery Monitor" | "Manufacturer Tools" | "Diagnostics" | "Permissions" | "Advanced Access" | "Settings" | "About"
const mainNav: [Page, IconName][] = [
  ["Dashboard", "grid"],
  ["Process Manager", "cpu"],
  ["Storage Cleaner", "storage"],
  ["Application Manager", "apps"],
]
const toolsNav: [Page, IconName][] = [
  ["Battery Monitor", "battery"],
  ["Manufacturer Tools", "tools"],
  ["Diagnostics", "activity"],
  ["Permissions", "shield"],
]
const descriptions: Record<Page, string> = {
  Dashboard: "A little clarity. A healthier device.",
  "Process Manager": "Understand what’s running. Stay in control.",
  "Storage Cleaner": "Make room for the things that matter.",
  "Application Manager": "Your applications, all in one place.",
  "Battery Monitor": "A clear picture of your battery.",
  "Manufacturer Tools": "The right tools for your device.",
  Diagnostics: "Transparent information. No guesswork.",
  Permissions: "Your device. Your permissions.",
  "Advanced Access": "More control, only when you choose.",
  Settings: "Make Phone Manager feel like yours.",
  About: "Thoughtful tools for everyday maintenance.",
}
type BatteryReading = {
  level: number
  charging: boolean
}
type BrowserBattery = BatteryReading & EventTarget
type ScanFile = {
  id: number
  file: File
  category: string
  duplicate: boolean
}
const formatBytes = (n: number) =>
  n < 1024
    ? `${n} B`
    : n < 1024 ** 2
      ? `${(n / 1024).toFixed(1)} KB`
      : n < 1024 ** 3
        ? `${(n / 1024 ** 2).toFixed(1)} MB`
        : `${(n / 1024 ** 3).toFixed(2)} GB`
const categoryFor = (f: File) =>
  f.type.startsWith("image/")
    ? "Images"
    : f.type.startsWith("video/")
      ? "Videos"
      : f.type.startsWith("audio/")
        ? "Audio"
        : "Documents"

function Notice({
  title,
  children,
  tone = "blue",
}: {
  title: string
  children: ReactNode
  tone?: string
}) {
  return (
    <div className={`notice ${tone}`}>
      <Icon name="info" size={20} />
      <div>
        <strong>{title}</strong>
        <p>{children}</p>
      </div>
    </div>
  )
}
function Badge({
  children,
  green = false,
}: {
  children: ReactNode
  green?: boolean
}) {
  return (
    <span className={`badge ${green ? "green" : ""}`}>
      <span className="status-dot" />
      {children}
    </span>
  )
}

export default function App() {
  const [page, setPage] = useState<Page>("Dashboard")
  const [theme, setTheme] = useState("Light")
  const [battery, setBattery] = useState<BatteryReading | null>(null)
  const [updated, setUpdated] = useState(new Date())
  const [refreshing, setRefreshing] = useState(false)
  const [toast, setToast] = useState("")
  const [files, setFiles] = useState<ScanFile[]>([])
  const [scanState, setScanState] = useState("Idle")
  const [filter, setFilter] = useState("All files")
  const [search, setSearch] = useState("")
  const [selected, setSelected] = useState<Set<number>>(new Set())
  const [dialog, setDialog] = useState(false)
  useEffect(() => {
    if (!dialog) return
    const previousFocus = document.activeElement as HTMLElement | null
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setDialog(false)
      if (event.key !== "Tab") return
      const controls = document.querySelectorAll<HTMLButtonElement>(
        '[role="dialog"] button',
      )
      const first = controls[0]
      const last = controls[controls.length - 1]
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last?.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first?.focus()
      }
    }
    document.addEventListener("keydown", handleKey)
    return () => {
      document.removeEventListener("keydown", handleKey)
      previousFocus?.focus()
    }
  }, [dialog])
  const fileInput = useRef<HTMLInputElement>(null)
  const scanGeneration = useRef(0)
  const [showMore, setShowMore] = useState(false)
  const [systemDark, setSystemDark] = useState(
    () => matchMedia("(prefers-color-scheme: dark)").matches,
  )
  useEffect(() => {
    const media = matchMedia("(prefers-color-scheme: dark)")
    const update = () => setSystemDark(media.matches)
    media.addEventListener("change", update)
    return () => media.removeEventListener("change", update)
  }, [])
  useEffect(() => {
    let active = true
    let source: BrowserBattery | undefined
    const update = () => {
      if (active && source)
        setBattery({ level: source.level, charging: source.charging })
    }
    const nav = navigator as Navigator & {
      getBattery?: () => Promise<BrowserBattery>
    }
    nav
      .getBattery?.()
      .then((b) => {
        if (!active) return
        source = b
        update()
        b.addEventListener("levelchange", update)
        b.addEventListener("chargingchange", update)
      })
      .catch(() => {})
    return () => {
      active = false
      source?.removeEventListener("levelchange", update)
      source?.removeEventListener("chargingchange", update)
    }
  }, [])
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => setToast(""), 4500)
      return () => clearTimeout(timer)
    }
  }, [toast])
  const navigate = (next: Page) => {
    setPage(next)
    setShowMore(false)
    window.scrollTo({ top: 0 })
  }
  const refresh = () => {
    setRefreshing(true)
    setTimeout(() => {
      setUpdated(new Date())
      setRefreshing(false)
      setToast(
        "Capabilities checked. Android services are not connected in this web preview.",
      )
    }, 600)
  }
  const scan = async (input: FileList | null) => {
    if (!input?.length) return
    const generation = ++scanGeneration.current
    setScanState("Scanning")
    setFiles([])
    setSelected(new Set())
    const result: ScanFile[] = []
    const hashes = new Set<string>()
    let failed = 0
    for (const [id, file] of Array.from(input).entries()) {
      if (generation !== scanGeneration.current) return
      try {
        const digest = await crypto.subtle.digest(
          "SHA-256",
          await file.arrayBuffer(),
        )
        if (generation !== scanGeneration.current) return
        const hash = Array.from(new Uint8Array(digest), (b) =>
          b.toString(16).padStart(2, "0"),
        ).join("")
        result.push({
          id,
          file,
          category: categoryFor(file),
          duplicate: hashes.has(hash),
        })
        hashes.add(hash)
      } catch {
        failed++
      }
    }
    setFiles(result)
    setScanState(failed ? "Partially Completed" : "Completed")
    setFilter("All files")
    setSearch("")
  }
  const selectedFiles = files.filter((f) => selected.has(f.id))
  const filteredFiles = files.filter(
    (f) =>
      (filter === "All files" ||
        (filter === "Duplicates"
          ? f.duplicate
          : filter === "Large files"
            ? f.file.size >= 10 * 1024 ** 2
            : f.category === filter)) &&
      f.file.name.toLowerCase().includes(search.toLowerCase()),
  )
  const navItem = ([label, icon]: [Page, IconName]) => (
    <button
      key={label}
      className={`nav-item ${page === label ? "active" : ""}`}
      onClick={() => navigate(label)}
      aria-current={page === label ? "page" : undefined}
    >
      <Icon name={icon} />
      <span>{label}</span>
      {page === label && <span className="nav-active-dot" />}
    </button>
  )
  const empty = (icon: IconName, title: string, text: string) => (
    <div className="empty-state">
      <div className="empty-icon">
        <Icon name={icon} size={30} />
      </div>
      <h3>{title}</h3>
      <p>{text}</p>
      <Badge>Native connection required</Badge>
    </div>
  )
  const metric = (
    icon: IconName,
    title: string,
    color: string,
    value: string,
    unit: string,
    caption: string,
    footer: string,
  ) => (
    <article className="metric-card card">
      <div className="metric-top">
        <span className={`icon-box ${color}`}>
          <Icon name={icon} />
        </span>
        <span>{title}</span>
        <Icon name="info" size={16} />
      </div>
      <div className="metric-value">
        {value}
        <span>{unit}</span>
      </div>
      <p className="metric-caption">{caption}</p>
      <div className={`metric-track ${color}`}>
        {title === "Battery" && battery && (
          <span style={{ width: `${Math.round(battery.level * 100)}%` }} />
        )}
      </div>
      <div className="metric-bottom">
        <span>{footer}</span>
        <span className="small-status">
          {title === "Battery" && battery ? "Browser reading" : "Unavailable"}
        </span>
      </div>
    </article>
  )

  return (
    <div
      className={`app ${
        theme === "Dark" || (theme === "System" && systemDark) ? "dark" : ""
      }`}
    >
      <aside className="sidebar">
        <button
          className="brand"
          onClick={() => navigate("Dashboard")}
          aria-label="Phone Manager home"
        >
          <span className="brand-icon">
            <Icon name="phone" size={25} />
          </span>
          <span>
            Phone<span className="brand-second">Manager</span>
          </span>
        </button>
        <div className="workspace-label">YOUR WORKSPACE</div>
        <nav aria-label="Main navigation">{mainNav.map(navItem)}</nav>
        <div className="nav-divider" />
        <div className="workspace-label tools-label">DEVICE TOOLS</div>
        <nav aria-label="Device tools">{toolsNav.map(navItem)}</nav>
        <div className="sidebar-bottom">
          <div className="privacy-card">
            <span className="privacy-icon">
              <Icon name="shield" size={19} />
            </span>
            <strong>Your privacy comes first</strong>
            <p>
              No cloud. No tracking.
              <br />
              Your data stays with you.
            </p>
          </div>
          {navItem(["Settings", "settings"])}
          {navItem(["About", "help"])}
          <div className="sidebar-version">
            Phone Manager <span>v1.0.0</span>
          </div>
        </div>
      </aside>
      <div className="main-shell">
        <header className="topbar">
          <div className="breadcrumb">
            Workspace <Icon name="chevron" size={13} />
            <span>{page}</span>
          </div>
          <div className="topbar-right">
            <span className="preview-label">
              <span />
              Web preview
            </span>
            <div className="topbar-separator" />
            <button
              className="icon-button"
              onClick={() => setTheme(theme === "Dark" ? "Light" : "Dark")}
              aria-label="Toggle dark theme"
            >
              <Icon name={theme === "Dark" ? "moon" : "sun"} />
            </button>
            <button
              className="avatar"
              onClick={() => navigate("Settings")}
              aria-label="Open settings"
            >
              PM
            </button>
          </div>
        </header>
        <main>
          <div className="page-heading">
            <div>
              <div className="eyebrow">YOUR DEVICE, SIMPLIFIED</div>
              <h1>
                {page === "Dashboard" ? "A clearer view of your phone." : page}
              </h1>
              <p>{descriptions[page]}</p>
            </div>
            <button
              className="button secondary refresh-button"
              onClick={refresh}
              disabled={refreshing}
            >
              <Icon
                className={refreshing ? "spinning" : ""}
                name="refresh"
                size={17}
              />
              {refreshing ? "Refreshing…" : "Refresh"}
            </button>
          </div>

          {page === "Dashboard" && (
            <>
              <section className="device-card">
                <div className="device-content">
                  <div className="device-kicker">
                    <span className="tiny-phone">
                      <Icon name="phone" size={14} />
                    </span>{" "}
                    DEVICE OVERVIEW
                  </div>
                  <h2>Everything starts with your device.</h2>
                  <p>
                    A simple, honest look at what’s available.
                    <br />
                    Connect Android services to see your live device
                    information.
                  </p>
                  <div className="device-tags">
                    <span>
                      <Icon name="phone" size={14} />
                      Android device <span className="tag-dash">—</span>
                    </span>
                    <span>
                      OS version <span className="tag-dash">—</span>
                    </span>
                    <span className="connection-tag">
                      <span className="status-dot" />
                      Not connected
                    </span>
                  </div>
                  <div className="last-checked">
                    <Icon name="refresh" size={12} /> Last checked{" "}
                    {updated.toLocaleTimeString([], {
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </div>
                </div>
                <div className="phone-art" aria-hidden="true">
                  <div className="orbit orbit-one" />
                  <div className="orbit orbit-two" />
                  <div className="phone-shadow" />
                  <div className="illustrated-phone">
                    <div className="phone-camera" />
                    <div className="phone-screen-logo">
                      <Icon name="shield" size={35} />
                    </div>
                    <div className="phone-screen-line" />
                    <div className="phone-screen-line short" />
                    <div className="phone-screen-cards">
                      <i />
                      <i />
                      <i />
                      <i />
                    </div>
                    <div className="phone-home" />
                  </div>
                  <div className="floating-check">
                    <Icon name="check" size={20} />
                  </div>
                </div>
              </section>
              <section className="metrics-grid" aria-label="Resource overview">
                {metric(
                  "cpu",
                  "Memory",
                  "blue",
                  "—",
                  "GB available",
                  "RAM readings require Android access",
                  "Total RAM  —",
                )}
                {metric(
                  "storage",
                  "Storage",
                  "purple",
                  "—",
                  "GB used",
                  "Device storage is not connected",
                  "Available  —",
                )}
                {metric(
                  "battery",
                  "Battery",
                  "mint",
                  battery ? `${Math.round(battery.level * 100)}` : "—",
                  battery ? "%" : "% remaining",
                  battery
                    ? battery.charging
                      ? "Connected to power"
                      : "Running on battery"
                    : "Battery readings may not be supported",
                  battery
                    ? battery.charging
                      ? "Charging"
                      : "Not charging"
                    : "Charging status  —",
                )}
              </section>
              <section className="quick-section">
                <div className="section-heading">
                  <h2>What would you like to do?</h2>
                  <span>A little maintenance goes a long way</span>
                </div>
                <div className="quick-grid">
                  {([
                    [
                      "Process Manager",
                      "cpu",
                      "blue",
                      "See what’s running",
                      "View memory & processes",
                    ],
                    [
                      "Storage Cleaner",
                      "storage",
                      "purple",
                      "Make a little space",
                      "Review files before removing",
                    ],
                    [
                      "Application Manager",
                      "apps",
                      "orange",
                      "Manage your apps",
                      "Explore installed applications",
                    ],
                    [
                      "Battery Monitor",
                      "battery",
                      "mint",
                      "Know your battery",
                      "Check power & charging",
                    ],
                  ] as [Page, IconName, string, string, string][]).map(
                    ([label, icon, color, title, description]) => (
                      <button
                        className="quick-card card"
                        onClick={() => navigate(label)}
                        key={label}
                      >
                        <div className={`icon-box ${color}`}>
                          <Icon name={icon} size={23} />
                        </div>
                        <h3>{title}</h3>
                        <p>{description}</p>
                        <div className="quick-link">
                          {label}
                          <Icon name="arrow" size={17} />
                        </div>
                      </button>
                    ),
                  )}
                </div>
              </section>
              <div className="bottom-grid">
                <section className="card capability-card">
                  <div className="section-heading">
                    <h2>Built around your device</h2>
                    <Icon name="shield" size={18} />
                  </div>
                  <p>Only the features your device actually supports.</p>
                  <div className="capability-row">
                    <span className="list-icon blue">
                      <Icon name="phone" size={18} />
                    </span>
                    <div>
                      <strong>Android services</strong>
                      <span>Required for live device information</span>
                    </div>
                    <Badge>Not connected</Badge>
                  </div>
                  <div className="capability-row">
                    <span className="list-icon purple">
                      <Icon name="lock" size={18} />
                    </span>
                    <div>
                      <strong>Advanced access</strong>
                      <span>Optional. Always in your control.</span>
                    </div>
                    <button
                      className="text-button"
                      onClick={() => navigate("Advanced Access")}
                    >
                      Disabled
                      <Icon name="chevron" size={14} />
                    </button>
                  </div>
                  <button
                    className="text-link"
                    onClick={() => navigate("Diagnostics")}
                  >
                    View device capabilities
                    <Icon name="arrow" size={16} />
                  </button>
                </section>
                <section className="reassurance-card">
                  <span className="reassurance-icon">
                    <Icon name="shield" size={26} />
                  </span>
                  <h2>
                    Less guesswork.
                    <br />
                    More peace of mind.
                  </h2>
                  <p>
                    No “magic boosts” or made-up numbers.
                    <br />
                    Just clear information and thoughtful tools
                    <br className="desktop-break" /> that put you in control.
                  </p>
                  <button
                    className="text-link"
                    onClick={() => navigate("About")}
                  >
                    Our approach
                    <Icon name="arrow" size={16} />
                  </button>
                  <div className="reassurance-pattern" aria-hidden="true" />
                </section>
              </div>
              <div className="footnote">
                <Icon name="info" size={15} />
                <span>
                  You’re in the web preview. Device measurements and system
                  actions require a native Android connection.
                </span>
              </div>
            </>
          )}

          {page === "Storage Cleaner" && (
            <>
              <Notice title="Your files never leave your device">
                Choose files to analyze locally. This browser cannot scan your
                entire phone or delete its files.
              </Notice>
              <section className="card storage-overview">
                <div>
                  <span className="icon-box purple">
                    <Icon name="storage" size={24} />
                  </span>
                  <h2>A little room to breathe.</h2>
                  <p>
                    Review file sizes, categories, and content-verified
                    duplicates.
                    <br />
                    Nothing is removed automatically.
                  </p>
                  <button
                    className="button primary"
                    onClick={() => fileInput.current?.click()}
                    disabled={scanState === "Scanning"}
                  >
                    <Icon name="folder" size={18} />
                    {files.length
                      ? "Choose more files"
                      : "Choose files to scan"}
                  </button>
                  <input
                    ref={fileInput}
                    type="file"
                    multiple
                    hidden
                    onChange={(e) => {
                      void scan(e.target.files)
                      e.target.value = ""
                    }}
                  />
                </div>
                <div className="scan-summary">
                  <span>
                    {files.length
                      ? formatBytes(
                          files.reduce((sum, f) => sum + f.file.size, 0),
                        )
                      : "—"}
                  </span>
                  <p>
                    {files.length
                      ? `${files.length} accessible files analyzed`
                      : "No files analyzed yet"}
                  </p>
                  <Badge green={scanState === "Completed"}>
                    {scanState === "Idle" ? "Ready when you are" : scanState}
                  </Badge>
                </div>
              </section>
              {scanState === "Scanning" && (
                <div className="notice blue" role="status">
                  <Icon name="refresh" className="spinning" />
                  <div>
                    <strong>Verifying file contents…</strong>
                    <p>
                      Finding exact duplicates with SHA-256. Your files stay
                      local.
                    </p>
                  </div>
                  <button
                    className="button secondary"
                    onClick={() => {
                      scanGeneration.current++
                      setScanState("Canceled")
                    }}
                  >
                    Cancel scan
                  </button>
                </div>
              )}
              <div className="section-heading">
                <h2>Your selected files</h2>
                <span>Only files you explicitly share are visible</span>
              </div>
              <div className="card file-panel">
                <div className="file-toolbar">
                  <div className="search-box">
                    <Icon name="search" size={18} />
                    <input
                      aria-label="Search files"
                      placeholder="Search files…"
                      value={search}
                      onChange={(e) => setSearch(e.target.value)}
                    />
                  </div>
                  <select
                    aria-label="Filter files"
                    value={filter}
                    onChange={(e) => setFilter(e.target.value)}
                  >
                    {[
                      "All files",
                      "Images",
                      "Videos",
                      "Audio",
                      "Documents",
                      "Large files",
                      "Duplicates",
                    ].map((v) => (
                      <option key={v}>{v}</option>
                    ))}
                  </select>
                </div>
                {!filteredFiles.length ? (
                  <div className="empty-state">
                    <div className="empty-icon">
                      <Icon name="folder" size={30} />
                    </div>
                    <h3>
                      {files.length
                        ? "No matching files"
                        : scanState === "Canceled"
                          ? "Scan canceled"
                          : "A fresh start, on your terms"}
                    </h3>
                    <p>
                      {files.length
                        ? "Try a different search or category."
                        : "Choose files above to get a clear view of your storage."}
                    </p>
                  </div>
                ) : (
                  <div className="file-list">
                    {filteredFiles.map((f) => (
                      <label className="file-row" key={f.id}>
                        <input
                          type="checkbox"
                          checked={selected.has(f.id)}
                          onChange={() =>
                            setSelected((previous) => {
                              const next = new Set(previous)
                              next.has(f.id)
                                ? next.delete(f.id)
                                : next.add(f.id)
                              return next
                            })
                          }
                        />
                        <span className="list-icon purple">
                          <Icon name="file" />
                        </span>
                        <div>
                          <strong>{f.file.name}</strong>
                          <span>
                            {f.category}
                            {f.duplicate ? " · Verified duplicate" : ""}
                          </span>
                        </div>
                        <span>{formatBytes(f.file.size)}</span>
                      </label>
                    ))}
                  </div>
                )}
                {selected.size > 0 && (
                  <div className="selection-footer">
                    <span>
                      {selected.size} selected ·{" "}
                      {formatBytes(
                        selectedFiles.reduce((n, f) => n + f.file.size, 0),
                      )}
                    </span>
                    <button
                      className="button secondary"
                      onClick={() => setDialog(true)}
                    >
                      Remove from review
                    </button>
                  </div>
                )}
              </div>
            </>
          )}

          {page === "Process Manager" && (
            <>
              <div className="metrics-grid">
                {metric(
                  "cpu",
                  "Total RAM",
                  "blue",
                  "—",
                  "GB",
                  "Requires native Android services",
                  "Source  —",
                )}
                {metric(
                  "cpu",
                  "Available RAM",
                  "purple",
                  "—",
                  "GB",
                  "No verified measurement available",
                  "Last reading  —",
                )}
                {metric(
                  "activity",
                  "Memory pressure",
                  "mint",
                  "—",
                  "",
                  "Low-memory status is unavailable",
                  "System status  —",
                )}
              </div>
              <Notice title="Process visibility is restricted">
                Android limits access to other applications’ processes. This
                preview never generates a simulated process list or per-app
                memory values.
              </Notice>
              <section className="card">
                {empty(
                  "cpu",
                  "No accessible processes",
                  "Connect verified Android services to see supported process information. Force-stop and other privileged operations are unavailable.",
                )}
              </section>
            </>
          )}
          {page === "Application Manager" && (
            <>
              <Notice title="Application visibility follows Android permissions">
                This browser cannot access installed Android applications. A
                native connection is required for application settings and
                authorized uninstall flows.
              </Notice>
              <section className="card">
                {empty(
                  "apps",
                  "Your applications stay private",
                  "No application inventory is available in this environment. No applications have been read, modified, or removed.",
                )}
              </section>
            </>
          )}
          {page === "Battery Monitor" && (
            <>
              <div className="metrics-grid">
                {metric(
                  "battery",
                  "Battery",
                  "mint",
                  battery ? `${Math.round(battery.level * 100)}` : "—",
                  "%",
                  battery
                    ? "Reported by the browser Battery API"
                    : "No supported battery API available",
                  "Source: browser",
                )}
                {metric(
                  "activity",
                  "Temperature",
                  "orange",
                  "—",
                  "°C",
                  "Not exposed by the browser",
                  "Native access required",
                )}
                {metric(
                  "battery",
                  "Voltage",
                  "purple",
                  "—",
                  "mV",
                  "Not exposed by the browser",
                  "Native access required",
                )}
              </div>
              <section className="card details-card">
                <h2>Power information</h2>
                {[
                  [
                    "Charging status",
                    battery
                      ? battery.charging
                        ? "Charging"
                        : "Not charging"
                      : "Unavailable",
                  ],
                  ["Power source", "Unavailable"],
                  ["System health", "Unavailable"],
                  ["Design capacity", "Unavailable"],
                  ["Cycle count", "Unavailable"],
                ].map(([k, v]) => (
                  <div className="detail-row" key={k}>
                    <span>{k}</span>
                    <strong>{v}</strong>
                  </div>
                ))}
              </section>
              <Notice title="Honest readings, always">
                Battery information is browser-reported and may be limited by
                privacy controls. Health percentages and battery “repair” are
                not supported.
              </Notice>
            </>
          )}
          {page === "Manufacturer Tools" && (
            <>
              <section className="card details-card">
                <h2>Device compatibility</h2>
                {[
                  ["Manufacturer", "Not detected"],
                  ["Model", "Unavailable"],
                  ["Manufacturer utility", "Not connected"],
                  ["Compatibility", "Unverified"],
                ].map(([k, v]) => (
                  <div className="detail-row" key={k}>
                    <span>{k}</span>
                    <strong>{v}</strong>
                  </div>
                ))}
              </section>
              <Notice title="Use your device’s built-in tools">
                On Android, open Settings and search for “Device care,” “Phone
                Manager,” or “Phone Master.” Realme and TECNO utilities require
                a verified native integration; they cannot be launched from this
                preview.
              </Notice>
            </>
          )}
          {page === "Diagnostics" && (
            <>
              <section className="card details-card">
                <h2>Environment & capabilities</h2>
                {[
                  ["Environment", "Web browser"],
                  ["Android services", "Not connected"],
                  [
                    "Browser battery API",
                    battery ? "Available" : "Unavailable",
                  ],
                  [
                    "Local file analysis",
                    "Available — user-selected files only",
                  ],
                  ["Duplicate verification", "SHA-256 content verification"],
                  ["Process control", "Unsupported"],
                  ["Manufacturer integration", "Unverified"],
                  ["Last checked", updated.toLocaleString()],
                ].map(([k, v]) => (
                  <div className="detail-row" key={k}>
                    <span>{k}</span>
                    <strong>{v}</strong>
                  </div>
                ))}
              </section>
              <Notice title="No continuous background monitoring">
                Capabilities are checked when you open the app or press Refresh.
                We don’t collect or transmit diagnostic history.
              </Notice>
            </>
          )}
          {page === "Permissions" && (
            <>
              <Notice title="Only when you need them">
                No permissions are requested on first launch. Denying one
                feature never prevents access to unrelated tools.
              </Notice>
              <section className="card details-card">
                <h2>Permission overview</h2>
                {[
                  [
                    "Local files",
                    "You choose exactly which files to analyze. Access does not extend to the rest of your device.",
                    "Choose files",
                  ],
                  [
                    "Android process information",
                    "Requires native Android services. No browser permission can enable it.",
                    "Unavailable",
                  ],
                  [
                    "Installed applications",
                    "Package visibility follows Android platform restrictions.",
                    "Unavailable",
                  ],
                  [
                    "Advanced authorization",
                    "Disabled by default. Requires a verified native authorization provider.",
                    "Disabled",
                  ],
                ].map(([title, desc, status]) => (
                  <div className="permission-row" key={title}>
                    <span className="list-icon blue">
                      <Icon
                        name={title === "Local files" ? "folder" : "lock"}
                      />
                    </span>
                    <div>
                      <strong>{title}</strong>
                      <p>{desc}</p>
                    </div>
                    {status === "Choose files" ? (
                      <button
                        className="button secondary"
                        onClick={() => navigate("Storage Cleaner")}
                      >
                        Review access
                        <Icon name="arrow" size={16} />
                      </button>
                    ) : (
                      <Badge>{status}</Badge>
                    )}
                  </div>
                ))}
              </section>
            </>
          )}
          {page === "Advanced Access" && (
            <>
              <Notice title="Advanced access is disabled" tone="amber">
                Basic tools always work without advanced authorization.
                Privileged actions require verified Android services and
                explicit authorization.
              </Notice>
              <section className="card details-card">
                <h2>Authorization status</h2>
                {[
                  ["Shizuku service", "Unavailable in web preview"],
                  ["Authorization", "Not authorized"],
                  ["Supported advanced operations", "None verified"],
                ].map(([k, v]) => (
                  <div className="detail-row" key={k}>
                    <span>{k}</span>
                    <strong>{v}</strong>
                  </div>
                ))}
                <button className="button secondary" disabled>
                  <Icon name="lock" size={16} />
                  Native connection required
                </button>
              </section>
            </>
          )}
          {page === "Settings" && (
            <>
              <section className="card details-card">
                <h2>Appearance</h2>
                <p className="section-description">
                  Choose a comfortable look for this session.
                </p>
                <div className="theme-options">
                  {(["Light", "Dark", "System"] as const).map((t) => (
                    <button
                      className={`theme-option ${
                        theme === t ? "selected" : ""
                      }`}
                      key={t}
                      onClick={() => setTheme(t)}
                      aria-pressed={theme === t}
                    >
                      <Icon
                        name={
                          t === "Light"
                            ? "sun"
                            : t === "Dark"
                              ? "moon"
                              : "phone"
                        }
                        size={25}
                      />
                      <strong>{t}</strong>
                      {theme === t && <Icon name="check" size={17} />}
                    </button>
                  ))}
                </div>
              </section>
              <section className="card details-card">
                <h2>Monitoring & privacy</h2>
                <div className="detail-row">
                  <span>Resource refresh</span>
                  <strong>Manual · no background polling</strong>
                </div>
                <div className="detail-row">
                  <span>Local file analysis</span>
                  <strong>On-device only</strong>
                </div>
                <div className="detail-row">
                  <span>Cloud storage & tracking</span>
                  <strong>Not used</strong>
                </div>
                <div className="detail-row">
                  <span>Session data</span>
                  <button
                    className="text-button"
                    onClick={() => {
                      scanGeneration.current++
                      setFiles([])
                      setSelected(new Set())
                      setScanState("Idle")
                      setToast(
                        "Local file review data cleared. Your original files were not changed.",
                      )
                    }}
                  >
                    Clear file review
                    <Icon name="arrow" size={16} />
                  </button>
                </div>
              </section>
            </>
          )}
          {page === "About" && (
            <section className="card about-card">
              <span className="brand-icon">
                <Icon name="phone" size={30} />
              </span>
              <h2>Phone Manager</h2>
              <span className="version-pill">Version 1.0.0 · Web preview</span>
              <h3>Clarity over clever claims.</h3>
              <p>
                Your phone doesn’t need another magic boost. It needs
                understandable information, safe maintenance tools, and a little
                respect for your privacy.
              </p>
              <div className="about-values">
                {[
                  [
                    "shield",
                    "Private by design",
                    "No cloud. No tracking. Your files stay with you.",
                  ],
                  [
                    "check",
                    "Functionally honest",
                    "No fictional statistics or exaggerated cleanup claims.",
                  ],
                  [
                    "lock",
                    "Always your choice",
                    "No destructive actions without informed approval.",
                  ],
                ].map(([icon, title, desc]) => (
                  <div key={title}>
                    <Icon name={icon as IconName} size={24} />
                    <strong>{title}</strong>
                    <p>{desc}</p>
                  </div>
                ))}
              </div>
              <Notice title="Built for the browser, designed for Android">
                This responsive React implementation follows the supplied UI/UX
                specification. Native Flutter services, Android system actions,
                and physical-device verification are not part of this web
                preview.
              </Notice>
            </section>
          )}
          <footer className="main-footer">
            <span>Thoughtful tools. Nothing extra.</span>
            <span>
              <Icon name="shield" size={13} />
              Private by design
            </span>
          </footer>
        </main>
      </div>
      <nav className="mobile-nav" aria-label="Mobile navigation">
        {[...mainNav, ["More", "more"] as [string, IconName]].map(
          ([label, icon]) => (
            <button
              key={label}
              className={page === label ? "active" : ""}
              onClick={() =>
                label === "More"
                  ? setShowMore(!showMore)
                  : navigate(label as Page)
              }
            >
              <Icon name={icon} />
              <span>
                {label.replace(" Manager", "").replace(" Cleaner", "")}
              </span>
            </button>
          ),
        )}
      </nav>
      {showMore && (
        <div className="more-menu">
          <div className="section-heading">
            <h2>Device tools</h2>
            <button
              className="icon-button"
              onClick={() => setShowMore(false)}
              aria-label="Close menu"
            >
              <Icon name="close" />
            </button>
          </div>
          {[
            ...toolsNav,
            ["Advanced Access", "lock"] as [Page, IconName],
            ["Settings", "settings"] as [Page, IconName],
            ["About", "help"] as [Page, IconName],
          ].map(navItem)}
        </div>
      )}
      {toast && (
        <div className="toast" role="status">
          <Icon name="info" size={19} />
          <span>{toast}</span>
          <button
            className="icon-button"
            aria-label="Dismiss notification"
            onClick={() => setToast("")}
          >
            <Icon name="close" size={17} />
          </button>
        </div>
      )}
      {dialog && (
        <div className="modal-backdrop" onClick={() => setDialog(false)}>
          <section
            className="modal card"
            role="dialog"
            aria-modal="true"
            aria-labelledby="dialog-title"
            onClick={(e) => e.stopPropagation()}
          >
            <span className="icon-box purple">
              <Icon name="folder" />
            </span>
            <h2 id="dialog-title">Remove files from this review?</h2>
            <p>
              {selected.size} files ·{" "}
              {formatBytes(selectedFiles.reduce((n, f) => n + f.file.size, 0))}
            </p>
            <p>
              This only clears the selected entries from the review. Your
              original files will not be deleted or changed. Device deletion is
              unsupported in this browser.
            </p>
            <div className="modal-actions">
              <button
                className="button secondary"
                autoFocus
                onClick={() => setDialog(false)}
              >
                Cancel
              </button>
              <button
                className="button primary"
                onClick={() => {
                  setFiles(files.filter((f) => !selected.has(f.id)))
                  setSelected(new Set())
                  setDialog(false)
                  setToast("Removed from review. Original files are unchanged.")
                }}
              >
                Remove from review
              </button>
            </div>
          </section>
        </div>
      )}
    </div>
  )
}
