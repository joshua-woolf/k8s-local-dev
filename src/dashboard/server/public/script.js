// Types
/**
 * @typedef {Object} Credentials
 * @property {string} username
 * @property {string} password
 */

/**
 * @typedef {Object} Route
 * @property {string} name
 * @property {string[]} urls
 * @property {Credentials} [credentials]
 */

class ThemeManager {
  constructor() {
    this.themeToggle = document.getElementById('theme-toggle');
    this.darkIcon = document.getElementById('theme-toggle-dark-icon');
    this.lightIcon = document.getElementById('theme-toggle-light-icon');
    this.init();
  }

  init() {
    // Initial state is already set by the script in head
    this.updateThemeToggleIcons();

    // Watch for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.theme) {
        if (e.matches) {
          document.documentElement.classList.add('dark');
        } else {
          document.documentElement.classList.remove('dark');
        }
        this.updateThemeToggleIcons();
      }
    });

    // Watch for theme changes
    const observer = new MutationObserver(() => {
      this.updateThemeToggleIcons();
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class']
    });
  }

  updateThemeToggleIcons() {
    const isDark = document.documentElement.classList.contains('dark');
    this.darkIcon.classList.toggle('hidden', isDark);
    this.lightIcon.classList.toggle('hidden', !isDark);
  }
}

class ClipboardManager {
  /**
   * @param {string} text
   * @param {HTMLElement} button
   */
  static async copyToClipboard(text, button) {
    try {
      await navigator.clipboard.writeText(text);
      button.classList.add('text-green-500', 'dark:text-green-400', 'scale-110');
      setTimeout(() => {
        button.classList.remove('text-green-500', 'dark:text-green-400', 'scale-110');
      }, 300);
    } catch (err) {
      console.error('Failed to copy text:', err);
    }
  }
}

class RouteManager {
  constructor() {
    this.routesContainer = document.getElementById('routes-container');
    this.loading = document.getElementById('loading');
    this.error = document.getElementById('error');
    this.noResults = document.getElementById('no-results');
    this.searchInput = document.getElementById('route-search');
    this.refreshButton = document.getElementById('refresh-button');
    this.routes = [];
    this.init();
  }

  init() {
    this.fetchRoutes();
    this.setupEventListeners();
    // Focus the search input when the page loads
    this.searchInput.focus();
    // Refresh every 30 seconds
    setInterval(() => this.fetchRoutes(), 30000);
  }

  setupEventListeners() {
    this.searchInput.addEventListener('input', () => this.filterRoutes());
    this.refreshButton.addEventListener('click', () => {
      this.refreshButton.classList.add('animate-spin');
      this.fetchRoutes().finally(() => {
        this.refreshButton.classList.remove('animate-spin');
      });
    });

    // Add keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      // Ctrl/Cmd + K to focus search
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        this.searchInput.focus();
      }
      // Ctrl/Cmd + R to refresh
      if ((e.ctrlKey || e.metaKey) && e.key === 'r') {
        e.preventDefault();
        this.refreshButton.click();
      }
    });
  }

  /**
   * @param {Route} route
   * @returns {string}
   */
  createRouteCard(route) {
    return `
      <div class="route-card bg-white dark:bg-gray-800 rounded-lg shadow-md hover:shadow-lg p-6 transition-all duration-200">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center">
            <span class="route-name text-lg font-semibold px-3 py-1 bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 rounded-lg">
              ${this.escapeHtml(route.name)}
            </span>
          </div>
        </div>
        <div class="space-y-2">
          ${route.urls.map(url => this.createUrlLink(url)).join('')}
          ${this.createCredentialsSection(route.credentials)}
        </div>
      </div>
    `;
  }

  /**
   * @param {string} url
   * @returns {string}
   */
  createUrlLink(url) {
    return `
      <div class="group">
        <a href="${this.escapeHtml(url)}"
           target="_blank"
           class="route-url block p-2 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700/50 group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors"
           rel="noopener noreferrer">
          <div class="flex items-center text-gray-700 dark:text-gray-300">
            <svg class="h-4 w-4 mr-2 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
            </svg>
            <span class="truncate">${this.escapeHtml(url)}</span>
          </div>
        </a>
      </div>
    `;
  }

  /**
   * @param {Credentials} credentials
   * @returns {string}
   */
  createCredentialsSection(credentials) {
    if (!credentials) return '';

    return `
      <div class="mt-4 p-4 rounded-lg border border-gray-200 dark:border-gray-700">
        <div class="space-y-2">
          <div class="flex items-center">
            <span class="text-sm text-gray-700 dark:text-gray-300 w-20">Username:</span>
            <code class="px-3 py-1 rounded bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200 font-mono text-sm">${this.escapeHtml(credentials.username)}</code>
            <button class="ml-2 p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500 dark:text-gray-400 transition-all duration-200"
                    onclick="ClipboardManager.copyToClipboard('${this.escapeHtml(credentials.username)}', this)"
                    title="Copy username">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/>
              </svg>
            </button>
          </div>
          <div class="flex items-center">
            <span class="text-sm text-gray-700 dark:text-gray-300 w-20">Password:</span>
            <code class="px-3 py-1 rounded bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200 font-mono text-sm">${this.escapeHtml(credentials.password)}</code>
            <button class="ml-2 p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500 dark:text-gray-400 transition-all duration-200"
                    onclick="ClipboardManager.copyToClipboard('${this.escapeHtml(credentials.password)}', this)"
                    title="Copy password">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `;
  }

  /**
   * @param {string} str
   * @returns {string}
   */
  escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  filterRoutes() {
    const query = this.searchInput.value.toLowerCase();
    const filteredRoutes = this.routes.filter(route => {
      return route.name.toLowerCase().includes(query) ||
             route.urls.some(url => url.toLowerCase().includes(query));
    });

    this.routesContainer.innerHTML = filteredRoutes
      .sort((a, b) => a.name.localeCompare(b.name))
      .map(route => this.createRouteCard(route))
      .join('');

    this.noResults.classList.toggle('hidden', filteredRoutes.length > 0);
    this.routesContainer.classList.toggle('hidden', filteredRoutes.length === 0);
  }

  async fetchRoutes() {
    this.loading.style.display = 'block';
    this.error.classList.add('hidden');
    this.routesContainer.classList.add('hidden');
    this.noResults.classList.add('hidden');

    try {
      const response = await fetch('/api/routes');
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      this.routes = await response.json();

      this.loading.style.display = 'none';
      this.routesContainer.classList.remove('hidden');
      this.filterRoutes();
    } catch (error) {
      this.loading.style.display = 'none';
      this.error.classList.remove('hidden');
      console.error('Error:', error);
    }
  }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
  new ThemeManager();
  new RouteManager();
});
