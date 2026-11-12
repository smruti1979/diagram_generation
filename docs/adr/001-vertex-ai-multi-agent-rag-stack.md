# ADR-001: Reference Architecture for Enterprise Multi-Agent RAG on Google Cloud (Vertex AI)

* **Status:** Accepted
* **Date:** 2026-11-12
* **Author(s):** AI Architecture Team
* **Deciders:** Principal AI Architect, Cloud Security Lead, Data Platform Lead
* **Related Diagrams:** `../../gcp_vertex_rag_arch.png`, `../../gcp_vertex_rag_arch.svg`

---

## 1. Context & Problem Statement

The organization requires a production-grade, multi-agent Retrieval-Augmented Generation (RAG) platform capable of answering complex enterprise queries across both **unstructured documents** (PDFs, policies, manuals, multimodal assets) and **structured analytical/transactional data** (warehouses and operational databases).

### Key Architectural Drivers
* **Scale & Latency:** Sub-2-second end-to-end P95 latency for hybrid retrieval across millions of document chunks.
* **Accuracy & Grounding:** High precision retrieval with semantic reranking and automated groundedness evaluation to minimize hallucinations.
* **Security & Compliance:** Zero-trust IAM, perimeter DDoS/WAF protection, automated PII redaction during ingestion, and runtime prompt injection guardrails.
* **Operational Simplicity:** Managed serverless and PaaS components to minimize GPU cluster management overhead while retaining model flexibility.

---

## 2. Decision Drivers

1. **Managed vs. Self-Hosted AI Infrastructure:** Minimize operational toil of hosting embedding models, cross-encoder rerankers, and vector index shards.
2. **Hybrid Data Access:** Agents must seamlessly route between unstructured semantic search (Vector DB), structured analytical SQL (Data Warehouse), and operational state (Cache/RDBMS).
3. **Model Optionality & Vendor Lock-in Mitigation:** Support frontier multimodal models (Gemini) alongside open-weight models (Llama, Gemma, Mistral) behind a unified API surface.
4. **End-to-End Observability:** Native distributed tracing across multi-hop agent loops, token usage, and automated RAG evaluation metrics.

---

## 3. Architectural Decisions & Trade-Off Analysis

### Decision 3.1: Agentic Orchestration Runtime
* **Chosen Option:** **Cloud Run + Vertex AI Agent Engine** (running LangGraph / Google ADK).
* **Alternatives Considered:**
  * *Google Kubernetes Engine (GKE):* Rejected for initial rollout due to higher operational overhead and node-pool management complexity.
  * *Cloud Functions (2nd Gen):* Rejected due to execution timeout constraints on long-running multi-agent reasoning loops and streaming responses.
* **Rationale & Trade-Offs:** Cloud Run provides sub-second autoscaling (including scale-to-zero for dev/staging), native gRPC/HTTP streaming, and seamless VPC connector integration. *Trade-off:* Requires externalizing all conversational state to Memorystore (Redis) due to stateless container lifecycles.

### Decision 3.2: Vector Database & Retrieval Engine
* **Chosen Option:** **Vertex AI Vector Search (ScaNN)** paired with **Vertex AI Ranking API**.
* **Alternatives Considered:**
  * *AlloyDB / Cloud SQL with `pgvector`:* Retained strictly for relational metadata and transactional tool lookups; rejected as the primary vector store due to lower ANN throughput at 10M+ vector scale.
  * *Self-hosted Qdrant / Milvus on GKE:* Rejected to avoid managing stateful storage volumes, shard rebalancing, and backup pipelines.
* **Rationale & Trade-Offs:** Vertex AI Vector Search delivers low-latency hybrid (dense + sparse) search backed by Google's ScaNN algorithm, while the managed Ranking API eliminates the need to host GPU-backed cross-encoder pods. *Trade-off:* Higher baseline minimum cost for always-on index endpoints compared to `pgvector` for small datasets (<500k vectors).

### Decision 3.3: Memory, Metadata & Analytical Storage Tier
* **Chosen Option:** Polyglot persistence combining **Memorystore (Redis)**, **AlloyDB / Cloud SQL**, and **BigQuery**.
* **Rationale & Trade-Offs:**
  * **Memorystore (Redis):** Handles sub-millisecond multi-turn session state and semantic caching (cutting duplicate LLM calls by 20–40%).
  * **AlloyDB / Cloud SQL:** Stores document lineage, RBAC/ABAC access control lists (ACLs), and transactional records.
  * **BigQuery:** Serves both as the target for Natural-Language-to-SQL (NL2SQL) analytical agents and as the sink for inference logs used by Vertex AI Evaluation.

### Decision 3.4: Foundation Model Strategy
* **Chosen Option:** **Vertex AI Model Garden** (Primary: **Gemini 2.5 Pro / Flash**; Secondary: **Vertex Endpoints** hosting open-weight models).
* **Rationale & Trade-Offs:**
  * **Gemini 2.5 Flash:** Used for fast intent routing, query decomposition, and high-throughput extraction.
  * **Gemini 2.5 Pro:** Used for complex multi-step synthesis, reasoning, and multimodal document understanding.
  * **Vertex Endpoints (Llama / Gemma / Mistral):** Available for specialized fine-tuned tasks or strict data-residency/open-weight mandates.

### Decision 3.5: Perimeter & AI-Specific Security
* **Chosen Option:** **Cloud Load Balancing + Cloud Armor + IAM + Model Armor + Cloud DLP**.
* **Rationale & Trade-Offs:** Traditional WAFs (Cloud Armor) block network-layer attacks, while **Model Armor** inspects LLM prompts and outputs for indirect prompt injection, jailbreaks, and toxic content. **Cloud DLP** strips PII prior to embedding generation so sensitive data never enters the vector index.

---

## 4. Consequences & Risks

### Positive Consequences
* **Zero Infrastructure Drift:** Serverless ingestion (Eventarc + Cloud Functions) and managed inference auto-scale independently with workload spikes.
* **High Retrieval Precision:** Two-stage retrieval (Hybrid ScaNN search followed by managed cross-encoder reranking) significantly improves answer groundedness.
* **Full Auditability:** Every agent step, tool call, and retrieval score is logged to Cloud Trace and BigQuery for compliance and offline regression testing.

### Negative Consequences & Mitigations
* **Risk — Cold Starts on Scale-to-Zero:** Cloud Run instances scaling from zero may add 1–3 seconds to the first request.
  * *Mitigation:* Configure `min-instances = 1` (or `2`) on production Supervisor and Tool Runner services.
* **Risk — Vector Search Base Cost:** Dedicated index endpoints incur continuous hourly charges regardless of query volume.
  * *Mitigation:* Share a single multi-tenant index with namespace/metadata filtering across multiple business domains.
* **Risk — Multi-Hop Agent Latency:** Sequential agent tool calls can compound total response time.
  * *Mitigation:* Execute independent retrieval and SQL tool calls in parallel (`asyncio` / parallel graph branches) and stream partial tokens to the client.

---

## 5. Compliance & Verification Checklist

- [ ] All service accounts follow least-privilege IAM roles (`roles/aiplatform.user`, `roles/storage.objectViewer`).
- [ ] Private Service Connect (PSC) / VPC Service Controls enabled to prevent data exfiltration.
- [ ] Cloud DLP inspection templates verified on staging GCS ingestion buckets.
- [ ] Vertex AI Evaluation CI/CD gate configured to block deployments if groundedness score drops below `0.85`.
