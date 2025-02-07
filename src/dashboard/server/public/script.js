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
    this.setTheme(this.getThemePreference());
    this.themeToggle.addEventListener('click', () => this.toggleTheme());
    this.updateThemeToggleIcons();

    // Watch for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('theme')) {
        this.setTheme(e.matches ? 'dark' : 'light');
      }
    });
  }

  getThemePreference() {
    return localStorage.getItem('theme') ||
           (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  }

  setTheme(theme) {
    document.documentElement.classList.toggle('dark', theme === 'dark');
    localStorage.setItem('theme', theme);
    this.updateThemeToggleIcons();
  }

  toggleTheme() {
    const isDark = document.documentElement.classList.contains('dark');
    this.setTheme(isDark ? 'light' : 'dark');
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
      button.classList.add('copy-success');
      setTimeout(() => button.classList.remove('copy-success'), 300);
    } catch (err) {
      console.error('Failed to copy text:', err);
    }
  }
}

class RouteManager {
  constructor() {
    this.routesContainer = document.getElementById('routes-container');
    this.loading = document.getElementById('loading');
    this.init();
  }

  init() {
    this.fetchRoutes();
    // Refresh every 30 seconds
    setInterval(() => this.fetchRoutes(), 30000);
  }

  /**
   * @param {Route} route
   * @returns {string}
   */
  createRouteCard(route) {
    return `
      <div class="bg-white rounded-lg shadow-md p-6 fade-in">
        <div class="flex items-center justify-between mb-4">
          <div>
            <span class="text-sm font-semibold text-blue-600 bg-blue-100 px-2 py-1 rounded">
              ${this.escapeHtml(route.name)}
            </span>
          </div>
        </div>
        <div class="space-y-2">
          ${route.urls.map(url => `
            <a href="${this.escapeHtml(url)}" target="_blank" class="block hover:bg-gray-50 p-2 rounded transition-colors">
              <div class="flex items-center text-gray-700 hover:text-blue-600">
                <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                </svg>
                ${this.escapeHtml(url)}
              </div>
            </a>
          `).join('')}
          ${this.createCredentialsSection(route.credentials)}
        </div>
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
      <div class="mt-4 p-4 border border-gray-200 rounded-md">
        <h3 class="text-sm font-medium text-gray-700 mb-2">Credentials</h3>
        <div class="space-y-2">
          <div class="flex items-center">
            <span class="text-sm text-gray-600 w-20">Username:</span>
            <code class="text-sm px-3 py-1.5 rounded font-mono">${this.escapeHtml(credentials.username)}</code>
            <button class="copy-button ml-2" onclick="ClipboardManager.copyToClipboard('${this.escapeHtml(credentials.username)}', this)" title="Copy username">
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/>
              </svg>
            </button>
          </div>
          <div class="flex items-center">
            <span class="text-sm text-gray-600 w-20">Password:</span>
            <code class="text-sm px-3 py-1.5 rounded font-mono">${this.escapeHtml(credentials.password)}</code>
            <button class="copy-button ml-2" onclick="ClipboardManager.copyToClipboard('${this.escapeHtml(credentials.password)}', this)" title="Copy password">
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

  async fetchRoutes() {
    try {
      const response = await fetch('/api/routes');
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const routes = await response.json();

      this.loading.style.display = 'none';
      this.routesContainer.innerHTML = routes
        .sort((a, b) => a.name.localeCompare(b.name))
        .map(route => this.createRouteCard(route))
        .join('');
    } catch (error) {
      this.loading.innerHTML = '<p class="text-red-500">Error loading routes. Please try again later.</p>';
      console.error('Error:', error);
    }
  }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
  new ThemeManager();
  new RouteManager();
});
