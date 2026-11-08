# Static blog hosting

The public proxy configures both language HTTPS hosts and forwards to backend
port 80 with fixed Host and client headers. The backend keeps Czech WordPress
on loopback port 8081 and returns English 503 until static selection is enabled.
Static storage listens only on loopback port 8080; `serveStatic=true` requires
`enable=true` and selects both language roots without a WordPress fallback.
Unknown Hosts and reserved deployment/webhook paths are rejected.

WordPress accounts, PHP protections, data, MariaDB, cron and health checks remain
available. Internal directory redirects are relative. Czech legacy aliases keep
fixed HTTPS targets; static feeds use the regular RSS index with its MIME type.
No external static/receiver port is opened and no publisher is installed.
Keep WordPress and prior system/data backups for route recovery. Backend route
selection and system deployment remain operator actions.
