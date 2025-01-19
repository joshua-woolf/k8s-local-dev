const express = require('express');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

function generateRandomWeather() {
  const conditions = ['Sunny', 'Partly Cloudy', 'Cloudy', 'Rain', 'Thunderstorm', 'Snow', 'Windy'];
  const temperatures = {
    min: Math.floor(Math.random() * 30) - 5,
    max: Math.floor(Math.random() * 35) + 5
  };

  return {
    condition: conditions[Math.floor(Math.random() * conditions.length)],
    temperature: {
      current: Math.floor(Math.random() * (temperatures.max - temperatures.min)) + temperatures.min,
      min: temperatures.min,
      max: temperatures.max
    },
    humidity: Math.floor(Math.random() * 100),
    windSpeed: Math.floor(Math.random() * 30),
    timestamp: new Date().toISOString()
  };
}

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.get('/api/weather', (req, res) => {
  res.json(generateRandomWeather());
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Weather API listening at http://0.0.0.0:${port}`);
});
