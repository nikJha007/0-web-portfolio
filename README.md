# Personal portfolio

A static, single-page portfolio site. No build step, no runtime, no
dependencies. nginx serves the files directly.

## Repo layout

```
.
├── index.html                  the whole site, one page
├── 404.html                    error page
├── robots.txt                  crawler rules
├── sitemap.xml                 one entry per public URL
├── assets/
│   ├── css/styles.css          all styling; theme lives in :root
│   ├── js/main.js              scroll reveal + active nav link
│   └── img/favicon.svg         placeholder monogram
├── deploy/
│   ├── nginx/portfolio.conf    server block
│   ├── setup-server.sh         one-time server bootstrap
│   └── deploy.sh               publish current commit to the web root
└── .gitignore                  blocks *.pem, .env, OS cruft
```

## Editing the content

Everything is plain HTML. Search `index.html` for `EDIT:` comments and the
placeholder strings, then replace them:

| Placeholder | Where |
| --- | --- |
| `Your Name` | `<title>`, nav, hero, footer, meta tags |
| `Your Headline Role` | `<title>`, hero |
| `yourdomain.com` | canonical link, og:url, `robots.txt`, `sitemap.xml`, nginx `server_name` |
| `you@yourdomain.com` | contact section |
| `github.com/you`, `linkedin.com/in/you` | contact section, project links |

Sections are numbered `01`–`06` in the markup. To add a project, duplicate one
`<article class="card">` block. To add a role, duplicate one `<li>` inside
`<ol class="timeline">`. Delete the whole Writing section if you don't blog.

Recolour the site by editing the custom properties at the top of
`assets/css/styles.css`. Changing `--accent` and `--bg` is enough to shift the
look completely.

## Previewing locally

```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

Use a server rather than opening the file directly, because the absolute
asset paths (`/assets/...`) don't resolve over `file://`.

## Deploying to the EC2 instance

First time, on the server:

```bash
sudo dnf install -y git
git clone https://github.com/you/your-repo.git ~/portfolio-src
bash ~/portfolio-src/deploy/setup-server.sh
```

That installs nginx, creates `/var/www/portfolio`, drops the server block into
`/etc/nginx/conf.d/`, and publishes the site.

Every time after, on the server:

```bash
cd ~/portfolio-src && bash deploy/deploy.sh
```

`deploy.sh` pulls, syncs only the publishable files into the web root, fixes
ownership, validates the nginx config, and reloads. It runs `nginx -t` before
reloading so a broken config can't take the site down.

## TLS

Once the domain's A record points at the instance's Elastic IP and
`server_name` is correct:

```bash
sudo dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
sudo certbot renew --dry-run
```

Certbot rewrites the server block to add the 443 listener and the HTTP
redirect, and installs a renewal timer.

## AWS notes

- Security group: inbound 80 and 443 open to `0.0.0.0/0`; keep 22 restricted
  to your own IP.
- Attach an Elastic IP so the address survives a stop/start.
- The `.pem` key belongs in `~/.ssh` on your laptop, never in this repo.
  `.gitignore` blocks `*.pem` as a backstop.

## Content Security Policy

The nginx config ships a strict CSP: `'self'` only, no inline scripts or
styles, `object-src 'none'`. This works because the site loads nothing from a
third party. If you later add an analytics snippet, an embedded video, or a
web font from a CDN, you must widen the matching directive or the browser will
silently block it. Check the console when something doesn't load.
