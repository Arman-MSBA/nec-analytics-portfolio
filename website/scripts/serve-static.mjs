import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, resolve, sep } from 'node:path';

const root = resolve('dist');
const port = Number(process.env.PORT || 4173);
const types = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.js': 'text/javascript; charset=utf-8',
  '.pdf': 'application/pdf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
};

createServer((request, response) => {
  let requested;
  try { requested = decodeURIComponent(new URL(request.url || '/', 'http://localhost').pathname); }
  catch { response.writeHead(400); response.end('Invalid request'); return; }
  let file = resolve(root, '.' + requested);
  if (file !== root && !file.startsWith(root + sep)) { response.writeHead(403); response.end('Forbidden'); return; }
  if (existsSync(file) && statSync(file).isDirectory()) file = join(file, 'index.html');
  const found = existsSync(file) && statSync(file).isFile();
  if (!found) file = join(root, '404.html');
  response.writeHead(found ? 200 : 404, { 'Content-Type': types[extname(file)] || 'application/octet-stream' });
  if (request.method === 'HEAD') { response.end(); return; }
  createReadStream(file).pipe(response);
}).listen(port, '127.0.0.1', () => {
  console.log(`Local: http://127.0.0.1:${port}`);
});

