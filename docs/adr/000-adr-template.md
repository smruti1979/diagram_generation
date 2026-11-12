# ADR-[XXX]: [Short, Descriptive Title of Architectural Decision]

* **Status:** [Proposed | Accepted | Rejected | Deprecated | Superseded by ADR-YYY]
* **Date:** YYYY-MM-DD
* **Author(s):** [Name / Role]
* **Deciders:** [Tech Lead, AI Architect, Security Lead, Platform Owner]
* **Related Diagrams / PRs:** [Links to `.png`/`.svg` diagrams, RFCs, or Terraform PRs]

---

## 1. Context & Problem Statement

[Describe the technical context, business requirement, or architectural problem being solved. Keep it factual and concise—2 to 4 sentences.]

### Key Architectural Drivers
* **Scale & Performance:** [e.g., Target P95 latency, throughput QPS, data volume]
* **Accuracy / Quality:** [e.g., Groundedness threshold, SLA/SLO requirements]
* **Security & Compliance:** [e.g., Data residency, PII handling, IAM/VPC isolation]
* **Cost & Operational Complexity:** [e.g., FinOps budget limits, team maintenance capacity]

---

## 2. Decision Drivers

1. [Primary driver — e.g., Minimize operational overhead of managing stateful GPU clusters]
2. [Secondary driver — e.g., Native integration with existing GCP/Vertex AI ecosystem]
3. [Tertiary driver — e.g., Avoid single-vendor lock-in for foundation models]

---

## 3. Options Considered

### Option A: [Name of Chosen Option] *(Recommended)*
* **Overview:** [1–2 sentence summary of how this option works]
* **Pros:**
  * [Advantage 1]
  * [Advantage 2]
* **Cons / Trade-offs:**
  * [Limitation or trade-off 1]
  * [Limitation or trade-off 2]

### Option B: [Name of Alternative 1]
* **Overview:** [1–2 sentence summary]
* **Pros:**
  * [Advantage 1]
* **Cons / Trade-offs:**
  * [Reason for rejection / limitation]

### Option C: [Name of Alternative 2]
* **Overview:** [1–2 sentence summary]
* **Pros:**
  * [Advantage 1]
* **Cons / Trade-offs:**
  * [Reason for rejection / limitation]

---

## 4. Decision Outcome

**Chosen Option:** **[Option A]** because [concise summary tying back to the Decision Drivers].

### Implementation Scope
* **Infrastructure / Terraform Changes:** [e.g., `terraform/main.tf` modules affected]
* **Architecture Diagram Updates:** [e.g., Update `gcp_vertex_rag_arch.py` and regenerate `.png`/`.svg`]
* **Application / Pipeline Changes:** [e.g., Services, APIs, or SDKs impacted]

---

## 5. Consequences & Risk Mitigation

### Positive Consequences
* [Expected improvement in latency, cost, reliability, or developer velocity]
* [Expected improvement in security or maintainability]

### Negative Consequences & Mitigations
* **Risk — [Identify technical or cost risk]:**
  * *Mitigation:* [Concrete engineering control or fallback mechanism]
* **Risk — [Identify operational or scaling risk]:**
  * *Mitigation:* [Concrete monitoring alert, quota limit, or architectural guardrail]

---

## 6. Verification & Rollout Checklist

- [ ] Architecture diagram updated in code (`*.py` / Mermaid) and rendered.
- [ ] Security, IAM least-privilege, and data privacy (PII/DLP) reviewed.
- [ ] Observability (traces, metrics, alerts) and FinOps cost tags configured.
- [ ] Load/evaluation benchmarks validated against acceptance criteria in staging.