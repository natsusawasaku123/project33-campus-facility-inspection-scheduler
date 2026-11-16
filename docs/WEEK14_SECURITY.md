# Week 14 security decisions

This is an instructor-approved Laravel and Flutter classroom prototype using fictional data. The protection objectives are to keep credentials confidential in transit, restrict operations to the signed-in role and assigned records, reject malformed requests, and leave useful audit evidence without collecting unnecessary content.

| Requirement | Implementation | Verification |
| --- | --- | --- |
| Authentication | Sanctum random bearer tokens; one-hour expiry; approved role required; current-token logout | `SecureIntegrationTest`; real HTTPS browser sign-in/sign-out |
| Role authorization | API checks supervisor/inspector/maintenance permissions; UI offers corresponding actions | Wrong-role 403 test and recorded request |
| Record authorization | Inspector queries constrain both record ID and assigned inspector; denied records return 404 | Changed-ID read/write tests with unchanged database assertions |
| HTTPS | Local Caddy TLS; same-origin app/API; HTTP API 400; trusted proxy IP allowlist; nonlocal HTTPS cannot be disabled | Actual CA-verified TLS request plus request-level proxy/HTTP tests |
| Protected configuration | Ignored `.env`/local keys/databases; non-secret example; debug false; configuration upgrade script; exact origins | Source archive inspection; local permissions and workstation trust still need user verification |
| Input validation | Laravel type/range/existence/date/checklist-key rules; client required-field checks | 422 tests with database state assertions |
| Safe logging | Dedicated seven-day security log; server-generated UUID; method, route template, status and actor ID; sanitized API exception class only | Canary sent in headers/body/query/exception; absent from response and captured logs |
| Data minimization | User responses explicitly allow only ID/name/role; token kept in memory; most queries select named fields; no body/header/query/IP in security logs | Exact-response and logger-context assertions |
| Adverse behavior | Invalid/altered/expired/missing authentication, forbidden role, changed record ID, invalid input, HTTP and spoofed proxy rejected | Negative tests preserve expected failures as evidence |

## Cryptography has a stated purpose

Passwords use Laravel's configured bcrypt hashing so authentication does not require storing a reversible password. Random Sanctum bearer tokens are stored as SHA-256 digests; this is appropriate for high-entropy random tokens and is not a password-hashing scheme. The plaintext token is returned only at issuance over HTTPS. TLS provides standard transport encryption, integrity and server authentication after the client trusts the correct certificate authority.

No custom encryption, HMAC, JWT signing or digital-signature scheme was added. The application has no documented requirement for independently signed messages or confidential real-world inspection records. Adding a new key-management system without such an objective would not meet a demonstrated need. If real sensitive data is introduced, assess encrypted storage, backups and key custody against that new objective.

## Trust boundaries

Browser → Caddy is HTTPS. Caddy → PHP is HTTP on local loopback. Only the configured loopback proxy addresses may supply the forwarded protocol. The backend and static server must not bind to a LAN/public interface. A process already running under a trusted local account can reach loopback and is outside this network transport boundary.

The client role controls navigation only; the API remains the authorization authority. CORS does not authorize a user. Role fields submitted in a request cannot grant a different role. Tokens are opaque to Flutter; the client does not decode or trust a user-edited JWT payload.

The local demonstration uses a five-minute HSTS policy; the API uses a one-year policy outside local/testing. The short local cache limits interference with other localhost development projects while the demonstration is retired or reconfigured.

## Audit behavior

`security.api_request` records request ID, method, route template, HTTP status and optional actor ID. `security.api_exception` records request ID and exception class. Passwords, access tokens, email addresses, descriptions, query strings, raw URLs, IP addresses, exception messages and SQL traces are not included in these application security records. Expected denials are recorded by their response status. The source's existing scheduler logs retain their fixed IDs, counts and controlled error codes.

Log files rotate daily with seven-day retention and POSIX mode 0600 where supported. Windows ACLs, backups and all other logging systems must be checked separately. The correlation ID helps connect a safe response and log entry without publishing a credential. API server errors return a generic message even if local debug mode is accidentally enabled.

## Remaining risks and limits

- A stolen bearer token can be replayed until its one-hour expiry or server revocation. There is no MFA, refresh-token rotation or self-service account recovery. Browser refresh discards the in-memory session but does not itself revoke an already-issued server token.
- SQLite findings, local configuration and backups are not encrypted at rest by this update. Fictional data is used; local file permissions and trusted account access remain necessary.
- The local CA must be trusted deliberately on the demonstration workstation. This loopback Caddy configuration, development PHP servers and shared demo password are not production deployment or real-user account provisioning.
- Tokens still carry wildcard Sanctum abilities; server-side role/ownership rules enforce the current API boundary. A larger integration should define and enforce purpose-specific token abilities.
- Audit metadata can reveal account/activity patterns. Limit access and retention. Other web-server, operating-system or third-party logs require separate review.
- The Week 13 finding correction/verification/closure, recorded manual-review resolution, Flutter finding-entry form and stored scheduled daily summary remain unfinished. This security update does not claim those workflows were completed.
- Cloud checks establish behavior only for the recorded environment and source revision. The student must reproduce the required Windows/Edge workflow, capture the workstation versions and confirm instructor access and official submission receipt. The full separate SA8 and IA5 marking instructions were not provided.

## Sources

- [Laravel authentication](https://laravel.com/docs/12.x/authentication), [Sanctum](https://laravel.com/docs/12.x/sanctum), [validation](https://laravel.com/docs/12.x/validation), [logging](https://laravel.com/docs/12.x/logging)
- [Caddy local HTTPS](https://caddyserver.com/docs/automatic-https#local-https)
- [Flutter web deployment](https://docs.flutter.dev/deployment/web)

Codex assisted with implementation, test execution, interface styling and documentation. The student should review the changes, run the documented local checks and describe their own contribution accurately.
