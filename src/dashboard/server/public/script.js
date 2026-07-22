const elements = {
  container: document.getElementById('services-container'),
  empty: document.getElementById('empty'),
  error: document.getElementById('error'),
  errorMessage: document.getElementById('error-message'),
  lastUpdated: document.getElementById('last-updated'),
  loading: document.getElementById('loading'),
  readyCount: document.getElementById('ready-count'),
  refresh: document.getElementById('refresh-button'),
  search: document.getElementById('service-search'),
  serviceCount: document.getElementById('service-count'),
  theme: document.getElementById('theme-toggle'),
}

let services = []
const credentialCache = new Map()

function createElement(tagName, className, text) {
  const element = document.createElement(tagName)
  if (className) element.className = className
  if (text !== undefined) element.textContent = text
  return element
}

function initialiseTheme() {
  const savedTheme = localStorage.getItem('theme')
  const darkPreferred = window.matchMedia('(prefers-color-scheme: dark)').matches
  document.documentElement.dataset.theme = savedTheme || (darkPreferred ? 'dark' : 'light')
}

function toggleTheme() {
  const nextTheme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'
  document.documentElement.dataset.theme = nextTheme
  localStorage.setItem('theme', nextTheme)
}

async function copyText(value, button) {
  await navigator.clipboard.writeText(value)
  const previousText = button.textContent
  button.textContent = 'Copied'
  button.classList.add('is-copied')
  window.setTimeout(() => {
    button.textContent = previousText
    button.classList.remove('is-copied')
  }, 1200)
}

function createCopyButton(value, label = 'Copy') {
  const button = createElement('button', 'copy-button', label)
  button.type = 'button'
  button.addEventListener('click', () => {
    copyText(value, button).catch(error => console.error('Clipboard write failed', error))
  })
  return button
}

function createTargetRow(label, value, { href, copyValue } = {}) {
  const row = createElement('div', 'target-row')
  row.append(createElement('span', 'target-label', label))

  if (href) {
    const link = createElement('a', 'target-value', value)
    link.href = href
    link.target = '_blank'
    link.rel = 'noopener noreferrer'
    row.append(link)
  }
  else {
    row.append(createElement('span', 'target-value', value))
  }

  if (copyValue) row.append(createCopyButton(copyValue))
  return row
}

function renderCredentialFields(panel, credentials) {
  panel.replaceChildren()
  for (const field of credentials.fields) {
    const row = createTargetRow(field.label, field.value, { copyValue: field.value })
    if (field.sensitive) row.dataset.sensitive = 'true'
    panel.append(row)
  }
}

async function revealCredentials(service, panel, button) {
  button.disabled = true
  button.textContent = 'Loading…'

  try {
    const response = await fetch(`/api/credentials/${encodeURIComponent(service.credentialProfile)}`, {
      cache: 'no-store',
      headers: { Accept: 'application/json' },
    })
    if (!response.ok) throw new Error(`Credentials API returned ${response.status}`)
    const credentials = await response.json()
    credentialCache.set(service.credentialProfile, credentials)
    renderCredentialFields(panel, credentials)
  }
  catch (error) {
    button.disabled = false
    button.textContent = 'Try again'
    const message = createElement('span', 'credential-error', error.message)
    panel.append(message)
  }
}

function createCredentialsPanel(service) {
  if (!service.credentialProfile) return null

  const section = createElement('section', 'credentials-panel')
  const heading = createElement('div', 'credential-heading', 'Credentials')
  const content = createElement('div', 'credential-content')
  content.setAttribute('aria-live', 'polite')
  section.append(heading, content)

  const cached = credentialCache.get(service.credentialProfile)
  if (cached) {
    renderCredentialFields(content, cached)
  }
  else {
    const button = createElement('button', 'credential-button', 'Reveal credentials')
    button.type = 'button'
    button.addEventListener('click', () => {
      revealCredentials(service, content, button).catch(error => console.error('Credential reveal failed', error))
    })
    content.append(button)
  }
  return section
}

function createCard(service) {
  const card = createElement('article', 'service-card')
  const header = createElement('div', 'card-header')
  const titleBlock = createElement('div')
  const title = createElement('h3', 'service-name', service.name)
  const namespace = createElement('div', 'namespace', `${service.namespace} / ${service.resourceName}`)
  const status = createElement('span', `status status-${service.status}`, service.status)

  titleBlock.append(title, namespace)
  header.append(titleBlock, status)
  card.append(header)
  card.append(createElement('p', 'description', service.description || 'Local Kubernetes service'))

  const targets = createElement('div', 'targets')
  for (const url of service.urls || []) {
    targets.append(createTargetRow('URL', url, { href: url, copyValue: url }))
  }
  for (const connection of service.connections || []) {
    targets.append(createTargetRow(connection.label, connection.endpoint, { copyValue: connection.endpoint }))
    if (connection.command) {
      targets.append(createTargetRow('Command', connection.command, { copyValue: connection.command }))
    }
  }
  card.append(targets)
  const credentialsPanel = createCredentialsPanel(service)
  if (credentialsPanel) card.append(credentialsPanel)
  return card
}

function matchesSearch(service, query) {
  if (!query) return true
  const values = [
    service.name,
    service.namespace,
    service.category,
    service.description,
    ...(service.urls || []),
    ...(service.connections || []).flatMap(connection => [connection.endpoint, connection.command]),
  ]
  return values.filter(Boolean).some(value => value.toLowerCase().includes(query))
}

function render() {
  const query = elements.search.value.trim().toLowerCase()
  const filtered = services.filter(service => matchesSearch(service, query))
  const grouped = Map.groupBy(filtered, service => service.category)
  const fragment = document.createDocumentFragment()

  for (const [category, categoryServices] of grouped) {
    const section = createElement('section', 'service-group')
    const heading = createElement('h2', '', category)
    const grid = createElement('div', 'service-grid')
    for (const service of categoryServices) grid.append(createCard(service))
    section.append(heading, grid)
    fragment.append(section)
  }

  elements.container.replaceChildren(fragment)
  elements.empty.hidden = filtered.length !== 0
  elements.serviceCount.textContent = String(services.length)
  elements.readyCount.textContent = String(services.filter(service => service.status === 'ready').length)
}

async function refreshServices() {
  elements.refresh.classList.add('is-refreshing')
  elements.loading.hidden = services.length > 0
  elements.error.hidden = true

  try {
    const response = await fetch('/api/services', { headers: { Accept: 'application/json' } })
    if (!response.ok) throw new Error(`Dashboard API returned ${response.status}`)
    services = await response.json()
    elements.lastUpdated.textContent = `Updated ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
    render()
  }
  catch (error) {
    elements.errorMessage.textContent = error.message
    elements.error.hidden = false
  }
  finally {
    elements.loading.hidden = true
    elements.refresh.classList.remove('is-refreshing')
  }
}

initialiseTheme()
elements.theme.addEventListener('click', toggleTheme)
elements.search.addEventListener('input', render)
elements.refresh.addEventListener('click', refreshServices)
refreshServices()
window.setInterval(refreshServices, 30000)
