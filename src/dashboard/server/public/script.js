// Theme handling
function getThemePreference() {
  if (localStorage.getItem('theme') === 'dark' || (!localStorage.getItem('theme') && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    return 'dark';
  }
  return 'light';
}

function setTheme(theme) {
  if (theme === 'dark') {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
  localStorage.setItem('theme', theme);
  updateThemeToggleIcons();
}

function updateThemeToggleIcons() {
  const isDark = document.documentElement.classList.contains('dark');
  document.getElementById('theme-toggle-dark-icon').classList.toggle('hidden', isDark);
  document.getElementById('theme-toggle-light-icon').classList.toggle('hidden', !isDark);
}

// Set initial theme
document.addEventListener('DOMContentLoaded', () => {
  setTheme(getThemePreference());

  // Theme toggle button handler
  document.getElementById('theme-toggle').addEventListener('click', () => {
    const isDark = document.documentElement.classList.contains('dark');
    setTheme(isDark ? 'light' : 'dark');
  });
});

const routesContainer = document.getElementById('routes-container');
const loading = document.getElementById('loading');

function createRouteCard(route) {
  return `
    <div class="bg-white rounded-lg shadow-md p-6 fade-in">
      <div class="flex items-center justify-between mb-4">
        <div>
          <span class="text-sm font-semibold text-blue-600 bg-blue-100 px-2 py-1 rounded">
            ${route.name}
          </span>
        </div>
      </div>
      <div class="space-y-2">
        ${route.urls.map(url => `
          <a href="${url}" target="_blank" class="block hover:bg-gray-50 p-2 rounded transition-colors">
            <div class="flex items-center text-gray-700 hover:text-blue-600">
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
              </svg>
              ${url}
            </div>
          </a>
        `).join('')}
        ${route.credentials ? `
          <div class="mt-4 p-4 border border-gray-200 rounded-md">
            <h3 class="text-sm font-medium text-gray-700 mb-2">Credentials</h3>
            <div class="space-y-2">
              <div class="flex items-center">
                <span class="text-sm text-gray-600 w-20">Username:</span>
                <code class="text-sm px-3 py-1.5 rounded font-mono">${route.credentials.username}</code>
                <button class="copy-button ml-2" onclick="copyToClipboard('${route.credentials.username}', this)" title="Copy username">
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/>
                  </svg>
                </button>
              </div>
              <div class="flex items-center">
                <span class="text-sm text-gray-600 w-20">Password:</span>
                <code class="text-sm px-3 py-1.5 rounded font-mono">${route.credentials.password}</code>
                <button class="copy-button ml-2" onclick="copyToClipboard('${route.credentials.password}', this)" title="Copy password">
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/>
                  </svg>
                </button>
              </div>
            </div>
          </div>
        ` : ''}
      </div>
    </div>
  `;
}

async function fetchRoutes() {
  try {
    const response = await fetch('/api/routes');
    const routes = await response.json();

    loading.style.display = 'none';
    routesContainer.innerHTML = routes
      .sort((a, b) => a.name.localeCompare(b.name))
      .map(createRouteCard)
      .join('');
  } catch (error) {
    loading.innerHTML = '<p class="text-red-500">Error loading routes. Please try again later.</p>';
    console.error('Error:', error);
  }
}

// Copy to clipboard functionality
async function copyToClipboard(text, button) {
  try {
    await navigator.clipboard.writeText(text);
    button.classList.add('copy-success');
    setTimeout(() => button.classList.remove('copy-success'), 300);
  } catch (err) {
    console.error('Failed to copy text: ', err);
  }
}

// Update copy button themes when theme changes
function updateCopyButtonThemes() {
  const isDark = document.documentElement.classList.contains('dark');
  document.querySelectorAll('.copy-button').forEach(button => {
    button.classList.toggle('dark', isDark);
  });
}

// Add theme observer
const observer = new MutationObserver(updateCopyButtonThemes);
observer.observe(document.documentElement, { attributes: true });

// Initial load
document.addEventListener('DOMContentLoaded', () => {
  fetchRoutes();
  // Refresh every 30 seconds
  setInterval(fetchRoutes, 30000);
});
