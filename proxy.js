const http = require('http');
const https = require('https');
const url = require('url');

const TARGET = 'https://backend.ketamiz.com';
const PORT = 8081;

http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const target = url.parse(TARGET);
  const options = {
    hostname: target.hostname,
    port: 443,
    path: req.url,
    method: req.method,
    headers: { ...req.headers, host: target.hostname },
  };

  const proxy = https.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, {
      ...proxyRes.headers,
      'Access-Control-Allow-Origin': '*',
    });
    proxyRes.pipe(res);
  });

  proxy.on('error', (err) => {
    console.error('Proxy error:', err.message);
    res.writeHead(502);
    res.end('Proxy error: ' + err.message);
  });

  req.pipe(proxy);
}).listen(PORT, () => {
  console.log(`CORS proxy running at http://localhost:${PORT} → ${TARGET}`);
});
