import { createServer } from 'node:http';
import { realpathSync } from 'node:fs';
import { readFile, realpath, stat } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const publicDirectory = fileURLToPath(new URL('../public/', import.meta.url));
const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.webp': 'image/webp',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8',
};

export function createStaticServer(directory = publicDirectory, mountPath = '/') {
  const root = realpathSync(directory);
  if (!/^\/(?:[A-Za-z0-9_-]+\/)*$/.test(mountPath)) {
    throw new TypeError('Use a mount path with leading and trailing slashes.');
  }

  return createServer(async (request, response) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Cache-Control', 'no-store');

    if (!['GET', 'HEAD'].includes(request.method)) {
      response.writeHead(405, { Allow: 'GET, HEAD' }).end();
      return;
    }

    let pathname;
    try {
      pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    } catch {
      response.writeHead(400).end();
      return;
    }

    if (mountPath !== '/' && pathname === mountPath.slice(0, -1)) {
      response.writeHead(308, { Location: mountPath }).end();
      return;
    }
    if (!pathname.startsWith(mountPath)) {
      response.writeHead(404).end();
      return;
    }

    const candidate = resolve(root, './' + pathname.slice(mountPath.length));
    if (candidate !== root && !candidate.startsWith(root + sep)) {
      response.writeHead(403).end();
      return;
    }

    try {
      let file = await realpath(candidate);
      if (file !== root && !file.startsWith(root + sep)) {
        response.writeHead(403).end();
        return;
      }

      if ((await stat(file)).isDirectory()) {
        if (!pathname.endsWith('/')) {
          response.writeHead(308, { Location: pathname + '/' }).end();
          return;
        }
        file = await realpath(join(file, 'index.html'));
        if (!file.startsWith(root + sep)) {
          response.writeHead(403).end();
          return;
        }
      }

      const contents = await readFile(file);
      response.writeHead(200, {
        'Content-Type': contentTypes[extname(file)] ?? 'application/octet-stream',
        'Content-Length': contents.length,
      });
      response.end(request.method === 'HEAD' ? undefined : contents);
    } catch (error) {
      const status = ['ENOENT', 'ENOTDIR', 'EISDIR'].includes(error.code) ? 404 : 500;
      response.writeHead(status).end();
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const port = Number(process.argv[2] ?? 4200);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new RangeError('Use a port between 1 and 65535.');
  }
  const server = createStaticServer();
  server.listen(port, '127.0.0.1', () => {
    console.log(`Cordato: http://127.0.0.1:${port}`);
  });
}
