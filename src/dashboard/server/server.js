const { setupTelemetry } = require('./tracing');
const express = require('express');
const cors = require('cors');
const path = require('path');
const { routesController } = require('./controllers/routes');
const { errorHandler } = require('./middleware/errorHandler');
const { requestLogger } = require('./middleware/requestLogger');

setupTelemetry();

class DashboardServer {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 3000;
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  setupMiddleware() {
    this.app.use(cors({
      origin: process.env.CORS_ORIGIN || '*',
      methods: ['GET', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization']
    }));

    this.app.use(express.static(path.join(__dirname, 'public')));

    this.app.use(requestLogger);
  }

  setupRoutes() {
    this.app.get('/api/routes', routesController);

    this.app.get('*', (req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'index.html'));
    });
  }

  setupErrorHandling() {
    this.app.use(errorHandler);
  }

  start() {
    return new Promise((resolve, reject) => {
      try {
        const server = this.app.listen(this.port, () => {
          console.log(`Server running on port ${this.port}`);
          resolve(server);
        });

        process.on('SIGTERM', () => this.shutdown(server));
        process.on('SIGINT', () => this.shutdown(server));
      } catch (error) {
        reject(error);
      }
    });
  }

  async shutdown(server) {
    console.log('Shutting down server...');
    try {
      await new Promise((resolve) => server.close(resolve));
      console.log('Server shutdown complete');
      process.exit(0);
    } catch (error) {
      console.error('Error during shutdown:', error);
      process.exit(1);
    }
  }
}

if (require.main === module) {
  const server = new DashboardServer();
  server.start().catch(error => {
    console.error('Failed to start server:', error);
    process.exit(1);
  });
}

module.exports = { DashboardServer };
