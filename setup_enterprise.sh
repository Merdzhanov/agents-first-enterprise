#!/bin/bash
set -e

PROJECT_ID="${1:-${GOOGLE_CLOUD_PROJECT:-$(gcloud config get project)}}"
REGION="${REGION:-europe-west1}"

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: PROJECT_ID not found. Please provide project ID as argument or set GOOGLE_CLOUD_PROJECT."
    exit 1
fi

echo "================================================================"
echo "🚀 Provisioning Agent-First Enterprise Fleet on Google Cloud"
echo "   Project: $PROJECT_ID | Region: $REGION"
echo "================================================================"

echo "1️⃣ Enabling Google Cloud APIs..."
gcloud services enable \
    aiplatform.googleapis.com \
    run.googleapis.com \
    firestore.googleapis.com \
    pubsub.googleapis.com \
    iam.googleapis.com \
    --project="$PROJECT_ID"

echo "2️⃣ Creating Service Accounts (IAM)..."
gcloud iam service-accounts create orchestrator-sa \
    --display-name="ADK Orchestrator SA" \
    --project="$PROJECT_ID" || true

gcloud iam service-accounts create dart-node-sa \
    --display-name="Dart Functional Node SA" \
    --project="$PROJECT_ID" || true

echo "3️⃣ Initializing Firestore (Memory Bank)..."
gcloud firestore databases create \
    --location=eur3 \
    --type=firestore-native \
    --project="$PROJECT_ID" || true

echo "4️⃣ Creating Pub/Sub Topics (for async Dart events)..."
gcloud pubsub topics create agent-state-updates \
    --project="$PROJECT_ID" || true

echo "5️⃣ Granting IAM Invoker Permissions..."
ORCHESTRATOR_SA_EMAIL="orchestrator-sa@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$ORCHESTRATOR_SA_EMAIL" \
    --role="roles/run.invoker" || true

echo "================================================================"
echo "✅ Infrastructure and IAM provisioned successfully!"
echo "   Ready to deploy Dart Functional Node & Python ADK Orchestrator."
echo "================================================================"
