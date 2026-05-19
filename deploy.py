"""
Deploy the hello_agent to Google Agent Engine (Vertex AI Agent Engine).

Required environment variables:
    GCP_PROJECT_ID   - GCP project ID
    GCP_REGION       - GCP region (e.g. us-central1)
    GCP_STAGING_BUCKET - GCS bucket used by Agent Engine for staging artefacts

Usage:
    python deploy.py [--delete]
"""

import argparse
import os
import sys

import vertexai
from vertexai.preview import reasoning_engines

# ---------------------------------------------------------------------------
# Configuration (read from environment so CI can inject secrets safely)
# ---------------------------------------------------------------------------
PROJECT_ID = os.environ["GCP_PROJECT_ID"]
REGION = os.environ.get("GCP_REGION", "us-central1")
STAGING_BUCKET = os.environ["GCP_STAGING_BUCKET"]

AGENT_DISPLAY_NAME = "hello-agent"
REQUIREMENTS = [
    "google-adk>=0.5.0",
    "google-cloud-aiplatform>=1.60.0",
]


def build_app():
    """Wrap the ADK agent in a ReasoningEngine-compatible app."""
    # Import here so the module is only loaded when actually deploying
    from vertexai.preview.reasoning_engines import AdkApp
    from agent.agent import root_agent

    return AdkApp(agent=root_agent, enable_tracing=False)


def deploy():
    vertexai.init(project=PROJECT_ID, location=REGION, staging_bucket=STAGING_BUCKET)

    print(f"Deploying '{AGENT_DISPLAY_NAME}' to project={PROJECT_ID} region={REGION} ...")

    remote_agent = reasoning_engines.ReasoningEngine.create(
        build_app(),
        requirements=REQUIREMENTS,
        display_name=AGENT_DISPLAY_NAME,
        description="Hello-world ADK agent deployed via deploy.py",
        extra_packages=["agent/"],
    )

    print(f"Deployment complete. Resource name: {remote_agent.resource_name}")
    return remote_agent


def delete_existing():
    """Delete any existing deployments with the same display name."""
    vertexai.init(project=PROJECT_ID, location=REGION)

    agents = reasoning_engines.ReasoningEngine.list(
        filter=f'display_name="{AGENT_DISPLAY_NAME}"'
    )
    for agent in agents:
        print(f"Deleting {agent.resource_name} ...")
        agent.delete()
    print("Done.")


def main():
    parser = argparse.ArgumentParser(description="Manage Agent Engine deployments")
    parser.add_argument(
        "--delete",
        action="store_true",
        help="Delete existing deployments instead of creating a new one",
    )
    args = parser.parse_args()

    if args.delete:
        delete_existing()
    else:
        deploy()


if __name__ == "__main__":
    main()
