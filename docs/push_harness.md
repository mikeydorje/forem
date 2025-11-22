Push Notifications (Android) - Minimal Test Harness

Overview
- Purpose: Send a one-off FCM v1 push from Rails to a known device token for staging validation.
- Scope: Android only. Uses Google service account OAuth via `googleauth`.

Prereqs
- Env var `FIREBASE_PROJECT_ID` (e.g. `forem-5d94b`).
- Service account JSON available to the dyno and pointed to by `GOOGLE_APPLICATION_CREDENTIALS`.
- Gem installed: `googleauth`.

Local Test (optional)
1) Ensure `bundle install` includes `googleauth`.
2) Export env:
   - `export FIREBASE_PROJECT_ID=forem-5d94b`
   - `export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/firebase-service-account.json`
3) Run task:
   - `FCM_TOKEN="<device_token>" TITLE="Test" BODY="Hello" bundle exec rake push:send_token`

Heroku Staging
1) Provide JSON to the dyno. Two options:
   - A) Set `FIREBASE_SERVICE_ACCOUNT_JSON` and write to a file before running the task.
   - B) Bake or upload the file to `/app/secrets/firebase.json`.

2) Example (Option A):
   - `heroku config:set FIREBASE_PROJECT_ID=forem-5d94b -a <app>`
   - `heroku config:set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat /local/path/firebase.json)" -a <app>`
   - `heroku run 'mkdir -p /app/secrets && echo "$FIREBASE_SERVICE_ACCOUNT_JSON" > /app/secrets/firebase.json' -a <app>`

3) Send push:
   - `heroku run 'GOOGLE_APPLICATION_CREDENTIALS=/app/secrets/firebase.json FCM_TOKEN=<device_token> TITLE="Test" BODY="Hello from Rails (prod)" rake push:send_token' -a <app>`

Expected Output
- Status 200
- Body includes `name: "projects/.../messages/<id>"`

Device Registration Setup
Before testing registration from the app:
1) Ensure ConsumerApp records exist:
   - `heroku run rake push:setup_apps -a <app>`

Notes
- This harness bypasses Rpush and sends directly via FCM v1 HTTP API.
- For production feature work, device registration and event-triggered sends will follow in subsequent PRs.
