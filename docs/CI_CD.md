# CI/CD checks

The GitHub Actions workflow at `.github/workflows/ci.yml` runs on every pull
request/push to `main`, `Merge`, the existing floor-worker branch and matching student AI branches, plus manual dispatch.

- **Backend:** restores/builds/tests ASP.NET Core with disposable PostgreSQL, including relational migrations and API performance evidence.
- **Agent service:** installs the FastAPI/LangGraph dependencies and runs the
  PyTest suite, including the mocked allow-listed production-schedule tool
  workflow.
- **Flutter:** runs `flutter analyze` followed by its unit and widget tests.
- **React:** installs the locked dependencies, runs Vitest and builds the route-split application.
- **Delivery:** only after all checks pass on a configured integration-branch push, a debug Android
  APK is built and uploaded as a workflow artifact.

The final artifact is intentionally not deployed automatically. A real cloud
deployment needs the team’s chosen hosting target and repository secrets; those
must be configured before adding a deployment job so credentials are never
stored in source control.
