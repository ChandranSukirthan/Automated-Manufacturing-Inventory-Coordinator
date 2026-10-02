# CI/CD checks

The GitHub Actions workflow at `.github/workflows/ci.yml` runs on every pull
request to `main`, every push to `main`, and manual dispatch.

- **Backend:** restores, builds, and runs the ASP.NET Core xUnit test project.
- **Agent service:** installs the FastAPI/LangGraph dependencies and runs the
  PyTest suite, including the mocked allow-listed production-schedule tool
  workflow.
- **Flutter:** runs `flutter analyze` followed by its unit and widget tests.
- **Delivery:** only after all checks pass on a push to `main`, a debug Android
  APK is built and uploaded as a workflow artifact.

The final artifact is intentionally not deployed automatically. A real cloud
deployment needs the team’s chosen hosting target and repository secrets; those
must be configured before adding a deployment job so credentials are never
stored in source control.
