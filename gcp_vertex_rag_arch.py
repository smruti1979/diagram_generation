from diagrams import Cluster, Diagram, Edge
from diagrams.gcp.analytics import BigQuery
from diagrams.gcp.compute import Run, Functions
from diagrams.gcp.database import SQL, Memorystore
from diagrams.gcp.devtools import Build
from diagrams.gcp.ml import AIPlatform
from diagrams.gcp.network import Armor, LoadBalancing
from diagrams.gcp.operations import Monitoring
from diagrams.gcp.security import Iam
from diagrams.gcp.storage import GCS

# Tuned Graphviz attributes for high-DPI rendering and zero label overlap
graph_attr = {
    "fontsize": "18",
    "fontname": "Sans-Serif",
    "bgcolor": "white",
    "pad": "0.6",
    "dpi": "200",           # High-DPI (200 DPI) crisp raster output for PNG
    "splines": "polyline",  # Clean straight segments that respect edge labels
    "nodesep": "0.85",      # Vertical spacing between nodes in the same rank
    "ranksep": "1.35",      # Horizontal spacing between columns/tiers
    "concentrate": "false", # Prevents merging edges that stack labels
}

node_attr = {
    "fontsize": "11",
    "fontname": "Sans-Serif",
}

edge_attr = {
    "fontsize": "10",
    "fontname": "Sans-Serif",
    "fontcolor": "#333333",
    "minlen": "2",
}

with Diagram(
    "GCP Vertex AI Multi-Agent RAG Architecture",
    filename="gcp_vertex_rag_arch",
    outformat=["png", "svg"],  # Exports both high-DPI PNG and vector SVG simultaneously
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
):
    # Ingress & Security
    lb = LoadBalancing("Cloud Load Balancing\n& API Gateway")
    armor = Armor("Cloud Armor\n(WAF & DDoS)")
    iam = Iam("Identity & Model Armor\n(Prompt Guardrails)")

    lb >> armor >> iam

    # Offline Document Ingestion Pipeline
    with Cluster("Data Ingestion & Indexing Pipeline"):
        gcs_docs = GCS("Cloud Storage\n(Raw Docs / Multimodal)")
        doc_processor = Functions("Cloud Functions / Workflows\n(Chunking & PII DLP)")
        embed_api = AIPlatform("Vertex AI Embeddings\n(text-embedding-005)")

        gcs_docs >> Edge(label="Eventarc Trigger") >> doc_processor >> embed_api

    # Agentic Runtime & Orchestration
    with Cluster("Agentic Runtime (Cloud Run / Vertex Agent Engine)"):
        supervisor = Run("Supervisor & Agents\n(LangGraph / ADK)")
        tool_runner = Run("Tool Execution Service\n(Code / APIs)")
        reranker = AIPlatform("Vertex AI Ranking API\n(Semantic Reranker)")

        supervisor >> Edge(label="Rerank Top-K") >> reranker
        supervisor >> Edge(label="Function Calling") >> tool_runner

    # Knowledge, Memory & Analytics Layer
    with Cluster("Data, Memory & Vector Stores"):
        vector_search = AIPlatform("Vertex AI Vector Search\n(Hybrid ScaNN Index)")
        redis = Memorystore("Memorystore (Redis)\n(Session & Semantic Cache)")
        alloydb = SQL("AlloyDB / Cloud SQL\n(Metadata & pgvector)")
        bq = BigQuery("BigQuery\n(Enterprise Warehouse & Eval Logs)")

    # Managed Foundation Models
    with Cluster("Vertex AI Model Garden & Endpoints"):
        gemini = AIPlatform("Gemini 2.5 Pro / Flash\n(Reasoning & Synthesis)")
        open_model = AIPlatform("Vertex Endpoints\n(Llama / Gemma / Mistral)")

    # LLMOps & Observability
    with Cluster("LLMOps, Evaluation & Monitoring"):
        cloud_mon = Monitoring("Cloud Trace & Logging\n(Latency & Token Metrics)")
        eval_pipeline = Build("Vertex AI Evaluation\n& CI/CD Pipelines")

    # Cross-Cluster Connections
    iam >> Edge(label="HTTPS / gRPC") >> supervisor
    embed_api >> Edge(label="Stream Upsert") >> vector_search

    supervisor >> Edge(style="dashed", label="State Lookup") >> redis
    supervisor >> Edge(label="ANN + Sparse Search") >> vector_search
    tool_runner >> Edge(label="NL2SQL") >> bq
    tool_runner >> Edge(label="Transactional Lookup") >> alloydb

    supervisor >> Edge(label="Complex Reasoning") >> gemini
    supervisor >> Edge(label="Low-Latency / Custom") >> open_model

    supervisor >> Edge(style="dotted", color="gray", label="Traces") >> cloud_mon
    bq >> Edge(style="dotted", color="gray", label="Groundedness Eval") >> eval_pipeline