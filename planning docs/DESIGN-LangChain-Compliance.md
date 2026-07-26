# DESIGN-LangChain-Compliance-Verifier.md

> **AI-Assisted Documentation**
> Portions of this document were drafted with an AI language model. All architecture decisions require Captain approval before implementation.

---

## 1. What This Is (and What It Is NOT)

### What It IS
An **external compliance verification pipeline** — a Python module using LangChain + LangGraph that:
- Downloads adverse action notice PDFs from the Salesforce org
- Chunks and embeds compliance text (ECOA, Reg B, FCRA)
- Runs a RAG QA chain to verify each notice meets regulatory requirements
- Outputs a PASS/FAIL report with citations
- Surfaces results in a React dashboard

### What It Is NOT
- **NOT replacing Salesforce** — the org remains the source of truth for decisions, rules, and Agentforce
- **NOT modifying Apex/LWC/Flow** — zero changes to `mortagate-de`
- **NOT the primary compliance review** — this is a **pre-check tool**, not legal sign-off (CR-5 remains HITL)
- **NOT an org-deployable component** — runs outside Salesforce entirely

---

## 2. Why LangChain / LangGraph Here?

| Requirement | How LangChain Delivers |
|-------------|------------------------|
| Document ingestion | `PyPDFLoader` / `UnstructuredPDFLoader` to ingest rendered notices |
| Chunking | `RecursiveCharacterTextSplitter` with compliance-aware separators |
| Embeddings | `OpenAIEmbeddings` or `HuggingFaceEmbeddings` for semantic search |
| Vector store | `FAISS` or `Chroma` for local retrieval (no external Pinecone dependency) |
| RAG QA | `RetrievalQA` chain with citation ("Section 1002.9(b)(2) states...") |
| Multi-step workflow | `LangGraph` state machine: Load → Parse → Chunk → Embed → Retrieve → Verify → Report |
| Memory | `ConversationBufferMemory` tracks which checks passed across audit sessions |
| Observability | `LangSmith` tracing for each compliance verification run |

**Portfolio angle:** This demonstrates every skill Wells Fargo requires (chains, RAG, embeddings, vector DBs, LangGraph state machines).

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SALESFORCE ORG (mortagate-de)               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Apex Classes  │  │ LWC Components│  │ Agentforce Copilot│   │
│  │ (unchanged)   │  │ (unchanged)   │  │ (unchanged)       │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
│         │                   │                    │              │
│         └───────────────────┼────────────────────┘              │
│                             │                                   │
│                    ┌────────▼────────┐                        │
│                    │  PDF Output      │                        │
│                    │  (Visualforce     │                        │
│                    │   renderAs="pdf")│                        │
│                    └────────┬────────┘                        │
└─────────────────────────────┼───────────────────────────────┘
                              │
                              │ HTTP GET / Download
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              EXTERNAL: LangChain Compliance Pipeline          │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Phase 1: Document Loading                               │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐ │  │
│  │  │ PyPDFLoader │→│ TextSplitter │→│ OpenAIEmbeddings│ │  │
│  │  └─────────────┘  └─────────────┘  └────────────────┘ │  │
│  └─────────────────────────────────────────────────────────┘  │
│                              │                                │
│                              ▼                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Phase 2: Vector Store (FAISS local)                     │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │ Embedded chunks: ECOA text, Reg B clauses,           │ │  │
│  │  │ FCRA disclosures, specific reason requirements       │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────┘  │
│                              │                                │
│                              ▼                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Phase 3: LangGraph Verification State Machine           │  │
│  │                                                         │  │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐   ┌──────┐ │  │
│  │  │  LOAD   │───→│ PARSE   │───→│ CHUNK   │──→│EMBED │ │  │
│  │  └─────────┘    └─────────┘    └─────────┘   └──────┘ │  │
│  │                                                  │      │  │
│  │                              ┌───────────────────┘      │  │
│  │                              ▼                         │  │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐   ┌──────┐ │  │
│  │  │ REPORT  │←───│ VERIFY  │←───│RETRIEVE │←──│QUERY │ │  │
│  │  │ (PASS/  │    │ (assert │    │ (relevant│   │(ECOA │ │  │
│  │  │  FAIL)  │    │  clauses│    │  chunks) │   │ RegB │ │  │
│  │  └─────────┘    └─────────┘    └─────────┘   └──────┘ │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│                              │                                │
│                              ▼                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Phase 4: React Dashboard (Next.js)                     │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌───────────────┐ │  │
│  │  │ Upload PDF   │  │ Verify Button│  │ Results Table  │ │  │
│  │  │ (dropzone)   │  │ (triggers    │  │ (PASS/FAIL +   │ │  │
│  │  │              │  │  LangGraph)  │  │  citations)    │ │  │
│  │  └─────────────┘  └─────────────┘  └───────────────┘ │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Compliance Boundaries (CRITICAL)

| Constraint | Enforcement |
|-----------|-------------|
| **No org modification** | Pipeline runs entirely outside Salesforce. Only reads PDF URLs. |
| **No PII in pipeline** | PDFs contain applicant names; pipeline must hash/anonymize before embedding |
| **Legal sign-off unchanged** | CR-5 remains HITL. This pipeline is a **developer tool**, not a compliance replacement. |
| **Audit trail preserved** | Every LangGraph run logged to `memory/compliance-runs/` with timestamp + hash |
| **Deterministic output** | Same PDF → same verification result (seeded LLM temperature = 0) |

---

## 5. How This Relates to Agentforce / Copilot

| Component | Role | Stays? |
|-----------|------|--------|
| **Agentforce Copilot** (`Veridact_Auditor_Copilot_v4`) | Conversational audit assistant inside Salesforce. Answers "What's wrong with this loan?" | ✅ Native, unchanged |
| **LangChain Pipeline** | Batch compliance verification outside Salesforce. Answers "Does this notice meet ECOA?" | ✅ External, new |
| **Relationship** | Copilot is for **auditors** (interactive). LangChain is for **compliance officers** (batch report). | Separate but complementary |

**No overlap, no conflict.** Two different personas, two different tools.

---

## 6. Required Documentation (Carlos Gate)

Before implementation:
- [x] `BLUEPRINT.md` (existing)
- [x] `SOLUTION-ARCHITECTURE.md` (existing)
- [ ] **`DESIGN-LangChain-Compliance.md`** (this document) ← Captain approval required
- [ ] **`REQUIREMENTS-MATRIX.md` update** — add row for LangChain pipeline as external tool
- [ ] **`RISKS-AND-DECISIONS.md` update** — document decision to keep pipeline external
- [ ] **`DATA-DICTIONARY.md` update** — add schema for compliance verification runs

---

## 7. Implementation Phases

| Phase | Deliverable | Time |
|-------|-------------|------|
| 1 | Python script: PDF download → text extraction → Flesch-Kincaid | 30 min |
| 2 | LangChain RAG chain: embed ECOA/Reg B text → QA verification | 45 min |
| 3 | LangGraph state machine: multi-step compliance workflow | 45 min |
| 4 | React dashboard: upload → verify → results | 60 min |
| 5 | Documentation update + evidence | 30 min |

**Total: ~3.5 hours**

---

## 8. Files to Create

```
/mortagate/
  compliance-verifier/           ← NEW directory
    README.md
    requirements.txt
    src/
      __init__.py
      config.py                  # API keys, paths
      loader.py                  # PDF download + text extraction
      splitter.py                # Compliance-aware chunking
      embedder.py                # OpenAI/HF embeddings
      vector_store.py            # FAISS/Chroma wrapper
      verifier_chain.py          # LangChain QA chain
      verifier_graph.py          # LangGraph state machine
      dashboard/                 # React app
        package.json
        src/
          App.tsx
          components/
            PdfUploader.tsx
            VerifyButton.tsx
            ResultsTable.tsx
            ComplianceCard.tsx
    tests/
      test_loader.py
      test_verifier_chain.py
      test_verifier_graph.py
    docs/
      ECOA-1002.9.md             # Regulation text (source material)
      Reg-B-reference.md
      FCRA-1681m.md
```

---

## Approval Required

Captain: Confirm this architecture before I proceed with implementation.

Specific decisions needed:
1. **Vector store**: FAISS (local, no cloud dependency) or Chroma?
2. **Embeddings**: OpenAI (requires API key) or local HuggingFace (free, slower)?
3. **Dashboard**: Standalone React app or integrate into Allura Memory dashboard?
4. **PDF source**: Download from live org (requires frontdoor auth) or use existing test PDFs?

