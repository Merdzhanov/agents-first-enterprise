# ⚡ Agent-First Enterprise

> **Autonomous Polyglot Fleet on Google Cloud — Powered by Google ADK 2.0, Gemini 3.5 on Vertex AI, and Dart Functional Nodes.**

[![Google Cloud](https://img.shields.io/badge/Google_Cloud-Cloud_Run_%7C_Firestore_%7C_Pub%2FSub-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com)
[![Vertex AI](https://img.shields.io/badge/Vertex_AI-Gemini_3.5_Flash_%26_Pro-8E24AA?logo=google)](https://cloud.google.com/vertex-ai)
[![Google ADK](https://img.shields.io/badge/Framework-Google_ADK_2.0-34A853?logo=python)](https://github.com/google/agent-development-kit)
[![Dart Shelf](https://img.shields.io/badge/Worker-Dart_Shelf_3.0-0175C2?logo=dart)](https://dart.dev)
[![Flutter Web](https://img.shields.io/badge/Frontend-Flutter_Web_3.47-02569B?logo=flutter)](https://flutter.dev)
[![Scale to Zero](https://img.shields.io/badge/FinOps-min--instances%3D0-F59E0B)]()

---

## 🏛️ Executive Summary & Concept

**Agent-First Enterprise** is a next-generation enterprise innovation engine and prototype factory. It decouples high-level probabilistic reasoning from low-latency deterministic execution through a **polyglot multi-agent architecture on Google Cloud**:

1. **Reasoning Layer (The Brain)**: Python ADK 2.0 running Gemini 3.5 / 2.5 on Vertex AI to handle multi-step planning, domain routing, and chain-of-thought analysis.
2. **Deterministic Layer (The Muscle)**: Containerized native Dart Shelf functional nodes on Cloud Run executing JSON filtering, API calls, and repository provisioning in sub-milliseconds with zero LLM token overhead.
3. **Human-in-the-Loop Governance (The CEO)**: A high-density Flutter Web Command Center giving the executive governor absolute authority over strategy, concept greenlighting (via a mandatory **2-Idea Proposal Gate**), Git hosting selection (**GitHub** vs. **GitLab**), and skip options before any code or infrastructure is provisioned.

> [!NOTE]
> **Repository Context**: This repository (`agents-first-enterprise`) is the central meta-platform and orchestration engine. The repositories provisioned by `github_service.dart` and `gitlab_service.dart` are the autonomous downstream prototype repositories created over time by the fleet.

---

## 🏗️ System Architecture Diagram

```mermaid
graph TD
    subgraph Governance ["Executive Governance Layer (Flutter Web)"]
        CEO["👑 Human-in-the-Loop CEO"]
        UI["Flutter Web Command Center<br/>(Firebase / Cloud Run)"]
        CEO <-->|1. Propose 2 Ideas<br/>2. Select GitHub/GitLab<br/>3. Approve / Skip (RequestInput)| UI
    end

    subgraph StateAndMemory ["Google Cloud State & Memory Layer"]
        FS[("🔥 Cloud Firestore<br/>• Session State<br/>• Memory Bank & Facts<br/>• Real-Time Traces")]
        SQL[("🐘 Cloud SQL PostgreSQL<br/>• Multi-Tenant Row-Level Security (RLS)")]
    end

    subgraph ReasoningLayer ["Reasoning Fleet (Python ADK 2.0 on Cloud Run)"]
        Supervisor["🧠 Supervisor / Planner Agent"]
        Scout["🔭 Scout Agent (Discovery)"]
        Architect["📐 Architect Agent (Topologies)"]
        Dev["💻 Lead Dev Agent (Code Scaffolding)"]
        Marketing["📣 Marketing Agent (Submission & Video)"]

        Supervisor <--> Scout
        Supervisor <--> Architect
        Supervisor <--> Dev
        Supervisor <--> Marketing
        Supervisor <-->|Vertex AI SDK| Vertex["⚡ Vertex AI Gemini 3.5<br/>(global shared quota)"]
    end

    subgraph DeterministicLayer ["Deterministic Muscle (Dart Shelf on Cloud Run)"]
        DartNode["⚡ Dart Functional Node<br/>• Devpost Direct API Discovery<br/>• Sub-ms JSON Filtering<br/>• Base64 Pub/Sub Unwrapping"]
        GitService["📦 Git Provisioning Service<br/>• GitHub REST API<br/>• GitLab REST API"]
        DartNode --> GitService
    end

    subgraph AsyncBroker ["Event Broker & Downstream Prototypes"]
        PS[("📬 Cloud Pub/Sub<br/>Topic: agent-state-updates")]
        DownstreamGitHub["🐙 Downstream GitHub Repositories<br/>(e.g., ephemeraflow-fleet)"]
        DownstreamGitLab["🦊 Downstream GitLab Repositories<br/>(e.g., armorguard-hub)"]
    end

    %% Connections
    UI <-->|Live Stream| FS
    UI -->|REST / OIDC| Supervisor
    Supervisor <-->|FirestoreSessionService| FS
    Supervisor -->|IAM OIDC Bearer Token| DartNode
    DartNode -->|Async Push Webhook| PS
    PS -->|Push Callback /webhooks/pubsub| DartNode
    GitService -->|Create & Commit Scaffold| DownstreamGitHub
    GitService -->|Create & Commit Scaffold| DownstreamGitLab

    classDef gcp fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#f8fafc;
    classDef highlight fill:#0284c7,stroke:#38bdf8,stroke-width:2px,color:#ffffff;
    class UI,Supervisor,DartNode,FS,SQL,PS,Vertex,GitService gcp;
    class CEO highlight;
```

---

## 🎯 Why it's Truly "Agentic" (Action over Recall)

Judges heavily penalize simple "chatbots with recall". *Agent-First Enterprise* proves true agentic autonomy:

* **Action Over Recall**: Historical context from the Firestore Memory Bank directly triggers tool execution, repository creation, and multi-turn handoffs rather than mere text completion.
* **The 2-Idea CEO Proposal Gate**: For every discovery run, the Planner Agent autonomously synthesizes two competing, high-ROI concepts (Concept A vs. Concept B), proposes a sanitized project name, and presents choices to the CEO via `RequestInput`.
* **Zero LLM Token Overhead on Deterministic Code**: Tasks like parsing Devpost feeds, calculating prize thresholds, and scaffolding Git files are handled by native Dart functions running in microseconds.
* **FinOps Scale-to-Zero**: All Cloud Run services are configured with `--min-instances=0`, ensuring zero idle cloud costs while maintaining sub-second cold starts with native Dart binaries.

---

## 📁 Repository Structure

```
agents_first_enterprise/
├── README.md                     # Master project documentation and architecture
├── setup_enterprise.sh           # Automated GCP IAM, Firestore & Pub/Sub setup
├── verify_fleet.sh               # Real probe verification script for GCP
│
├── services/
│   ├── dart_node/                # Deterministic Dart Shelf functional worker
│   │   ├── bin/server.dart       # Cloud Run HTTP router & webhook handlers
│   │   ├── lib/services/         # Devpost discovery, GitHub & GitLab services
│   │   ├── test/server_test.dart # Dart unit & integration test suite
│   │   └── Dockerfile            # Multi-stage scratch build for sub-second cold starts
│   │
│   └── orchestrator/             # Multi-Agent Reasoning Fleet (Python ADK 2.0)
│       ├── app/agents.py         # Supervisor, Scout, Architect, Dev, Marketing agents
│       ├── app/tools.py          # RequestInput, OIDC Dart caller, Memory tools
│       ├── app/main.py           # FastAPI & Cloud Run runner endpoints
│       ├── tests/test_agents.py  # Python unittest test suite
│       └── Dockerfile            # Cloud Run Python container
│
├── frontend/
│   └── governance_dashboard/     # Flutter Web CEO Command Center
│       ├── lib/main.dart         # Flutter Web UI with GitHub/GitLab selector & logs
│       └── pubspec.yaml          # Flutter dependencies
│
├── scripts/
│   └── run_e2e_pipeline.py       # End-to-end autonomous pipeline runner
│
├── docs/
│   └── index.html                # Compiled 11-page technical documentation portal
└── internal/                     # Architectural Working Papers (WP_01 to WP_07)
```

---

## 🚀 Quickstart & Reproducibility Guide

### Prerequisites
* Python 3.10+
* Dart 3.0+ & Flutter 3.19+
* Google Cloud CLI (`gcloud`) authenticated (`gcloud auth application-default login`)

---

### Step 1: Run Local Tests & Verification (Zero Cloud Cost)

Verify all components offline:

```bash
# 1. Run Dart Functional Node Unit Tests
cd services/dart_node
dart test
# Output: 4/4 tests passed (BriefParser, GitLabService, GitHubService, DevpostService)

# 2. Run Python ADK Multi-Agent Fleet Tests
cd ../orchestrator
python3 -m unittest discover -s tests -p "test_*.py"
# Output: 5/5 tests passed (Scout, 2-Idea Proposal Gate, GitHub, GitLab, Skip Path)

# 3. Analyze Flutter Governance Dashboard
cd ../../frontend/governance_dashboard
flutter analyze
# Output: No issues found!
```

---

### Step 2: Run the End-to-End Pipeline Simulation

Execute the full autonomous lifecycle:

```bash
# Option A: Approve Concept A, Target GitHub, Custom Project Name
python3 scripts/run_e2e_pipeline.py --decision approve_idea_a --provider github --project-name ephemeraflow-fleet

# Option B: Approve Concept B on GitLab
python3 scripts/run_e2e_pipeline.py --decision approve_idea_b --provider gitlab

# Option C: CEO elects to Skip Implementation (Halts safely with zero cloud spend)
python3 scripts/run_e2e_pipeline.py --decision skip_implementation
```

---

### Step 3: Launch the Flutter Web CEO Command Center

```bash
cd frontend/governance_dashboard
flutter run -d chrome
```

---

### Step 4: Deploy to Google Cloud (Production)

```bash
# 1. Provision GCP IAM, Firestore, and Pub/Sub
./setup_enterprise.sh <YOUR_PROJECT_ID>

# 2. Deploy Dart Functional Node to Cloud Run (Scale to zero)
cd services/dart_node
gcloud run deploy dart-node-1 \
    --source . \
    --service-account=dart-node-sa@<YOUR_PROJECT_ID>.iam.gserviceaccount.com \
    --no-allow-unauthenticated \
    --min-instances=0 \
    --region=europe-west1

# 3. Deploy Python ADK Orchestrator to Cloud Run
cd ../orchestrator
gcloud run deploy adk-orchestrator \
    --source . \
    --service-account=orchestrator-sa@<YOUR_PROJECT_ID>.iam.gserviceaccount.com \
    --no-allow-unauthenticated \
    --min-instances=0 \
    --region=europe-west1

# 4. Verify Cloud Fleet
./verify_fleet.sh <YOUR_PROJECT_ID>
```

---

## 🎬 4-Minute Demo Video Script Outline

* **[0:00 - 0:45] Instant Hook & Action Over Recall**:
  * Reveal live Cloud Run console with Scale-to-Zero (`min-instances=0`) status.
  * Trigger autonomous discovery from the Flutter Web UI.
* **[0:45 - 1:45] The 2-Idea CEO Decision Gate**:
  * Show the Planner Agent formulating Concept A vs. Concept B.
  * Demonstrate the CEO selecting Concept A, selecting **GitHub**, and confirming the custom project name.
* **[1:45 - 2:45] Polyglot Execution & Zero LLM Overhead**:
  * Show Dart Functional Node logs executing repository provisioning and file scaffolding in milliseconds.
  * Show Firestore state updating in real-time.
* **[2:45 - 4:00] Cloud Native Proofs & Submission Package**:
  * Inspect the generated GCP architecture diagram, code contracts, and marketing transcript.

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
