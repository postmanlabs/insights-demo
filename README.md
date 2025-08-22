# Postman Insights Demo

This repo provides a quick way to try out [Postman Insights](https://www.postman.com/product/postman-insights/) using the **Demo Dogs** service.  
You’ll spin up a demo app, generate synthetic traffic, and stream telemetry to a Postman Insights project — all with a single command.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running.
- A Postman account with access to **Insights**.
- A [Postman API Key](https://learning.postman.com/docs/developer/postman-api/authentication/).

---

## Step 1 — Create or Use an Insights Project

1. Log into [Postman](https://go.postman.co).
2. Either create a new **Insights project**, or walk through our **demo workflow** to set up one quickly.
3. Copy the **Service ID** for your project. You can find it by clicking on any of the tech stacks shown during onboarding — the ID will be prefixed with `svc_`.

---

## Step 2 — Run the Demo

Provide your **Service ID** and **Postman API Key** inline with the command and run the script via `curl`:

```bash
SERVICE_ID="svc_123456789" \
POSTMAN_API_KEY="pmk-xxxxxxxxxxxxxxxxxxxx" \
APP_PORT_HOST=8000 \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/postmanlabs/insights-demo/main/run.sh)"

