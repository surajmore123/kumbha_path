# Production Readiness

Status on 1 November 2026, for the app and `kumbha_Backend`. Nothing here has been
committed or deployed, and the live server has not been touched.

**Do not merge to `main` casually.** `deploy/auto-deploy.sh` pulls `main` every
minute and redeploys, so a merge is a production deployment.

## AI assistance

Staff ask for it on a case. It never runs by itself, and no workflow waits for it.

| Feature | Behaviour |
| --- | --- |
| Translation (en, hi, mr) | Stored in `CaseTranslation` beside the original, with source and target language. Staff can accept or correct it, and the machine text is kept. |
| Extraction | Stored in `CaseExtraction`, never on the case. A field survives only if the reply quotes the report for it. Sensitive terms are dropped. |
| Matching | Still `matching.py`. It now reports confidence, what agrees, what differs and what's missing. Details count only after a person accepts them. |
| Failure | Every route returns a clear 503 and nothing changes. Set `AI_LOST_FOUND_ENABLED=false` to turn it off. |

Sent to the provider: only the text of the fields being processed, with phone
numbers and emails removed. Never names, coordinates or photographs.

Gaps:

- The app panel translates case fields. The API also translates notes and
  sightings, but no screen offers that yet.
- Families don't see translations. Only staff and assigned volunteers do.
- A live test on synthetic text showed the model can drop part of a mixed-language
  text. Those results are flagged "may be incomplete" by length and number checks,
  which catch most losses but not all, so staff must keep the original in view.
- The panel has widget tests only. It hasn't been used on a device.

**Before real data goes to Gemini:** check the key's tier. Free-tier terms may let
Google use submitted content, which isn't acceptable for reports about missing
people. A paid tier is a cost that needs approval.

## Test results

Run on 1 November 2026, on a local database with synthetic data.

| Suite | Total | Passed | Failed | Skipped |
| --- | --- | --- | --- | --- |
| Backend, all | 977 | 970 | 0 | 7 |
| Flutter, all | 1,156 | 1,156 | 0 | 0 |
| Flutter analyzer | 50 notices | 0 errors | | |

Backend tests included above:

| Category | Tests |
| --- | --- |
| Family Safety Circle | 74 |
| Digital Safety QR | 67 |
| Lost & Found, including AI | 136 |
| Family location | 69 |
| Reunification | 74 |
| Notifications and SOS | 88 |
| Volunteer operations and security | 172 |
| End-to-end scenarios A to E | 5 |

The 7 skipped tests are live checks that need outside services.

Scenarios A to E run through the real APIs in the test client, with push and Gemini
replaced. The offline half of scenario E is tested as a replayed `client_id` plus
the app's draft tests, not on a device that actually lost signal.

Live checks from earlier phases passed on an Android emulator: operations 5/5,
SOS 2/2, reunion 5/5, location 3/3. They were not rerun after this phase.

**Not implemented or not tested:** physical phones, iOS, real FCM delivery, real SMS
delivery, background location on real devices, Redis-backed cache in a running
system, gunicorn under load, and backup restore. `apps.authentication` and
`apps.crowd` had no tests of their own, and authentication is now covered from
`apps/operations/test_platform.py`.

## Security findings

### Fixed

| Severity | Component | Finding | Fix |
| --- | --- | --- | --- |
| Critical | Settings | `production.py` was empty, leaving a dev `SECRET_KEY` fallback, open CORS and no HTTPS settings | Written, and refuses to start on weak secrets. **Not active until compose is switched** |
| Critical | OTP | Every code was `111111` | Reuses the website's SMS integration with random, hashed, attempt-limited codes. **Needs MSG91 credentials** |
| High | OTP | No rate limit on sending or verifying | Limited per number, however it's written, and per address |
| High | Sign-in | Throttles and locks were per worker, so limits were about three times looser | Redis cache in production settings |
| High | App logs | About 65 `print` calls wrote API responses, profiles included, to the device log | Removed, with a test that stops them returning |
| High | Notifications | Safety alerts put a first name and "medical help" on the lock screen | Generic text, private visibility |
| Medium | OTP | Numbers starting 91 couldn't verify, from `len("phone_number")` | Fixed |
| Medium | Admin | OTP codes were listed and searchable | Removed from the list |
| Medium | Logs | No logging config, and unformatted output | Structured logs. Tokens, phones, emails, codes and coordinates are redacted |
| Medium | Performance | Staff case list ran queries per row | One annotated query |
| Medium | Android | `allowBackup` defaulted to on | Off |
| Low | Backend | `print` calls in crowd and journal code | Replaced with logging |

### Open

| Severity | Component | Risk | Recommendation |
| --- | --- | --- | --- |
| Critical | Deployment | Production still runs `config.settings.local`. If `SECRET_KEY` isn't set there, tokens can be forged | Check the server, then switch settings |
| High | Tokens | Access tokens last 7 days, with no refresh flow in the app, and sign-out doesn't end them on the server | Add refresh tokens, then shorten. Changing this alone would sign people out weekly in the middle of use |
| High | Backups | No backup service exists in compose | See below |
| Medium | AI | Free-tier data terms | Confirm before real use |
| Medium | Matching | Compares the newest 500 opposite cases, so older ones are skipped at large scale | Filter by zone and date in SQL before launch |
| Medium | OTP | A limit per number means someone can briefly block a victim's sign-in | Accepted: existing sessions keep working. Review after launch |
| Medium | Android | The Maps key is in the manifest | Restrict by package and fingerprint |
| Medium | Access logs | gunicorn logs full paths. QR tokens are in request bodies, so they're safe, but other ids aren't hidden | Drop `--access-logfile`, as the app logs routes |
| Low | Repo | `celerybeat-schedule` is tracked | Remove from git |
| Low | Dependencies | `google.generativeai` used by the journal is end-of-life | Move to `google.genai` |
| Low | HSTS | Starts at one hour | Raise once HTTPS is proven |

Automated checks now cover every private route refusing anonymous callers, an
allow-list of public routes, forged, unsigned and expired tokens, extra role claims,
privilege fields on profile updates, cross-family and cross-zone access, invalid
QR codes, and unauthorised case and SOS actions.

## Privacy

Confirmed by tests: adults must consent to sharing, sharing stops on stop or expiry
and the position is removed, a QR scan creates no case and shows no phone number,
child positions are withheld from volunteers, and reunions need a recorded human
check.

Recommended policy, for a person to approve. Nothing is deleted automatically yet.

| Data | Keep for | Access |
| --- | --- | --- |
| Live positions | Removed when the session ends | Chosen recipients |
| SOS location | 30 days after closure | Operators in that zone |
| Cases and notes | 90 days after closure, unless legally required | Staff in that zone |
| Attachments | 30 days after closure | Staff, family side as allowed |
| AI translations and extractions | Deleted with the case | Staff |
| Audit logs | 1 year, with no personal content | Administrators |
| OTP rows | 7 days | Nobody needs them |
| Application logs | 30 days | Engineers |

## Performance

`scripts/load_test.py` in the backend. It refuses any host but this machine, and all
data is synthetic and removed afterwards.

Setup: Django `runserver` as one threaded process, `DEBUG=False`, local PostgreSQL,
300 users, 2,000 cases, 5,000 notifications. Redis and Celery were not running.
**These numbers are not a production forecast:** this isn't gunicorn, and client and
server shared one Windows laptop.

Second run, 150 requests per scenario (90 for SOS), at 50 concurrent users:

| Scenario | Requests/s | p50 ms | p95 ms | Max ms | Errors |
| --- | --- | --- | --- | --- | --- |
| Request OTP | 88 | 457 | 1,022 | 1,539 | 0% |
| Read profile | 95 | 390 | 1,411 | 1,523 | 0% |
| List family circles | 85 | 434 | 1,495 | 1,584 | 0% |
| File Lost & Found report | 29 | 1,247 | 3,052 | 3,444 | 4.7% |
| Staff case list | 65 | 588 | 1,333 | 2,187 | 0% |
| Create SOS | 47 | 720 | 1,539 | 1,634 | 0% |
| List notifications | 85 | 416 | 1,467 | 1,561 | 0% |
| Volunteer cases | 86 | 462 | 990 | 1,554 | 0% |

At 5 concurrent users, every scenario had a p95 of 199 ms or less, with no errors.

- **Bottleneck:** filing a report costs about 90 ms of CPU, so one Python process
  stops near 11 to 30 a second. Two runs of the same code gave 11 and 30, so treat
  these as rough.
- **Errors:** at 50 users some report requests failed to connect, 19% in the first
  run and 4.7% in the second. The likely cause is the dev server's small connection
  queue, but that isn't proven. Repeat this under gunicorn before relying on it.
- Selecting fewer columns for matching made no measurable difference, so that
  change was reverted. Moving matching to Celery would save about 25 ms a report.
- Every request opens a new database connection. Set `CONN_MAX_AGE` under gunicorn.
- The Celery and FCM path wasn't under load, because no broker was running.

Lists are protected by query budget tests. `gunicorn --workers 3` is likely too few
for a crowd event. Size it from a staging load test.

## Monitoring

| Endpoint | Who | Shows |
| --- | --- | --- |
| `/api/health/` | Public | Process is alive |
| `/api/health/ready/` | Public | Database and broker, 503 if down, and whether sweeps are late |
| `/api/health/operations/` | Admin | Delivery counts by outcome, open cases, open SOS, sharing sessions |

Logs are JSON on stdout. Each request has an `X-Request-ID`. Task failures log
`event: task_failure`. No alerting exists: connect these to an uptime monitor, and
alert on `ready` failing, on `background_tasks` false and on failed deliveries.

## Backup and recovery

There is no backup in compose. This plan has not been run.

| Item | Plan |
| --- | --- |
| PostgreSQL | `pg_dump` nightly, with write-ahead log archiving during the event |
| Retention | 7 daily, 4 weekly, plus one kept after the event |
| Storage | Encrypted, off the server, with access limited to two people |
| Attachments | In PostgreSQL, so they're covered. The `media` volume is backed up separately |
| Redis | Enable AOF. It holds queues and limits, so losing it delays work but loses no records |
| Secrets | Kept in a password manager, never with the backups |
| Testing | Restore into a separate staging database monthly. Never test on production |

Target: lose at most 15 minutes of data, and recover within an hour.

## Deployment checklist

Do these in order. Each needs a person's approval.

1. Back up the production database and confirm the restore works on staging.
2. On the server, check whether `SECRET_KEY` is set to a real value.
3. Set strong, separate `SECRET_KEY`, `JWT_SECRET_KEY` and `SAFETY_QR_SECRET`.
   - Changing `JWT_SECRET_KEY` signs everyone out.
   - Changing the QR secret may invalidate printed QR codes. Test this on staging,
     and regenerate them if needed.
4. Set `KP_SMS_PROVIDER=msg91`, `KP_MSG91_AUTH_KEY`, `KP_MSG91_TEMPLATE_ID`. In India
   the template needs DLT approval, which takes time.
5. Set `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `NUM_PROXIES`, `CACHE_URL`,
   `GOOGLE_ROUTES_API_KEY`, `AI_LOST_FOUND_ENABLED`.
6. Confirm Nginx terminates HTTPS and sends `X-Forwarded-Proto`. Its config lives in
   another repository and wasn't reviewed.
7. Change `DJANGO_SETTINGS_MODULE` to `config.settings.production` in
   `docker-compose.prod.yml` for web, worker and beat. Test on staging first.
8. Migrations add tables and columns only: `lostfound.0003`, `authentication.0008`,
   plus those from earlier phases. `entrypoint.sh` applies them and now registers
   the background tasks.
9. Reissue setup codes for helpers from before Phase 7, and give zones a radius.
10. Point the health check at `/api/health/ready/`.
11. Provide Firebase credentials, and confirm `android`/`ios` app identifiers.
12. Sign the app. `com.example` identifiers, the release keystore and the Apple Team
    ID are still missing. Build it with `API_PROTOCOL=https`.
13. Add a Flutter CI job. The backend has CI and the app doesn't.

## Readiness

| Area | Status | Why |
| --- | --- | --- |
| Backend | NEEDS ATTENTION | Tests pass, but production settings aren't active |
| Flutter | NEEDS ATTENTION | Tests pass, but no signing or physical device testing |
| Database | NEEDS ATTENTION | Migrations are additive, but no backups |
| Notifications | NOT TESTED | Real FCM delivery has never been checked |
| Location services | NOT TESTED | Emulator only, not real background use |
| Security | BLOCKED | OTP needs SMS credentials, and the settings switch is outstanding |
| Monitoring | NEEDS ATTENTION | Endpoints and logs exist, but nothing alerts |
| Backup and recovery | BLOCKED | No backups exist |
| Deployment configuration | BLOCKED | Compose still uses development settings |
| External providers | BLOCKED | SMS, Routes and Firebase need credentials |

**Not ready for production.** The code for the critical issues is in place, and what
remains is mostly configuration and accounts.

## Remaining manual requirements

- Verify real volunteers, and assign zones.
- Agree any partnerships. The app must not claim police or administration links.
- Provide production credentials for SMS, Routes, Firebase and Gemini.
- Set up Android and iOS signing, permissions and store declarations.
- Verify `kumbhapath.in` association for links.
- Test background location on real Android and iOS phones.
- Write operational emergency procedures, including who watches SOS at all hours.
- Approve the final production deployment.
