# Graphwise: The Company Behind GraphDB

If you have downloaded a GraphDB license for this demo, you may have noticed that the license file is named `GRAPHWISE_GRAPHDB_FREE_v11.3.license` rather than something bearing the Ontotext name you might have expected. This document explains why, and gives you some useful context about the company and technology you are working with.

---

## The Short Version

**Graphwise** is the company formed in October 2024 by the merger of two European knowledge graph pioneers: **Ontotext** (Bulgaria) and **Semantic Web Company** (Austria). GraphDB — the database used in this demo — was originally developed by Ontotext and is now a flagship product of Graphwise.

---

## The Two Companies

### Ontotext (founded ~2000, Sofia, Bulgaria)

Ontotext was one of the earliest commercial companies to bet heavily on semantic graph technologies. Their flagship product, **GraphDB**, is a W3C-standards-compliant RDF triplestore and knowledge graph database with a built-in reasoning engine — exactly the technology that powers the inference side of this demo.

Over the years, Ontotext built GraphDB into one of the most capable semantic databases available, serving clients in finance, media, life sciences, and government. Customers included the BBC, the Financial Times, NASA, AstraZeneca, and major commercial banks.

In 2022–2023, investment firms Integral, PortfoLion, and Carpathian Partners — alongside the European Bank for Reconstruction and Development (EBRD) — acquired Ontotext from its previous parent company, Sirma Group Holding, at a valuation of approximately €30 million, with an additional €11 million invested into the business. This recapitalization set the stage for the eventual merger.

### Semantic Web Company (founded 2004, Vienna, Austria)

Semantic Web Company (SWC) built its reputation around enterprise knowledge management and intelligent content processing. Their flagship product, **PoolParty Semantic Suite**, provides taxonomy management, automated tagging, semantic search, recommender systems, and intelligent document processing — essentially, the tools that help organizations organize, classify, and make sense of large volumes of unstructured content.

SWC and Ontotext had been close partners and fellow travelers in the semantic technology space for roughly two decades before the merger. Their products were technically complementary: GraphDB provides the graph storage and reasoning layer, while PoolParty provides the knowledge management and content intelligence layer that sits on top.

---

## The Merger

On **October 23, 2024**, Ontotext and Semantic Web Company announced their merger under the new brand name **Graphwise**. The combined company positions itself as a **Graph AI** platform provider — a company whose products help organizations build and query knowledge graphs that can then power AI applications, including large language model (LLM) integrations and Retrieval-Augmented Generation (RAG) pipelines.

The two companies described the merger as "20 years in the making" — a recognition that they had long operated in the same space, with aligned missions and complementary capabilities, and that combining forces was a natural evolution rather than a surprise pivot.

The financial terms of the deal were not disclosed. The two organizations maintain separate legal entities while operating under the unified Graphwise brand.

The merged company has:
- Over **200 employees** worldwide
- Offices across **North America, Europe, and APAC**
- Approximately **200 enterprise customers**

---

## Why the Merger Matters

The knowledge graph market is growing rapidly. Analysts valued it at approximately **$77 million in 2023** and project it will reach **$1.15 billion by 2032** — a compound annual growth rate of around 35%. Gartner predicted that by the end of 2025, graph technologies would be used in as many as **80% of data and analytics innovations**, up from just 10% in 2021.

A major driver of this growth is the rise of generative AI. Large language models are powerful but are prone to hallucination and lack grounding in specific, structured enterprise knowledge. Knowledge graphs — and the reasoning engines that power them — are increasingly seen as the "GPS for AI," as Graphwise President **Atanas Kiryakov** put it:

> "Knowledge graphs are like a GPS for AI and large language models. They guide AI models with precision and context to ensure trustworthy, explainable outputs."

By merging, Graphwise combined the graph storage and inference capabilities of GraphDB with the knowledge management and content intelligence of PoolParty into a single integrated platform — one that can take an organization from raw, unstructured data all the way to a queryable, reasoning-capable knowledge graph that LLMs can reliably consult.

---

## GraphDB After the Merger

GraphDB continues as Graphwise's core graph database product. The first major release under the new brand, **GraphDB 11**, brought significant AI-oriented enhancements:

- Expanded LLM support, including Qwen, Llama, Gemini, DeepSeek, and Mistral
- Enhanced **GraphRAG** (Graph Retrieval-Augmented Generation) capabilities
- **Model Context Protocol (MCP)** support for agentic AI workflows
- A "Talk to Your Graph" natural language query feature

The free tier of GraphDB — which is what this demo uses — remains available and is now distributed under the Graphwise name, hence the `GRAPHWISE_GRAPHDB_FREE_v11.3.license` file.

---

## Relevance to This Demo

This demo uses **GraphDB Free v11.3**, which you can obtain from the Graphwise website. The SHACL SPARQLRules used here (`rules.ttl`) represent a core capability of the GraphDB reasoning engine — the ability to declare logical axioms and have the database automatically infer new facts from them. This is a mature, production-grade feature that enterprise customers rely on for complex knowledge graph applications.

When you work through the inference side of this demo, you are using the same reasoning engine that powers knowledge graphs at the BBC, NASA, and major financial institutions worldwide.

---

## Further Reading

- [Graphwise official website](https://graphwise.ai)
- [GraphDB product page](https://graphwise.ai/components/graphdb/)
- [Merger announcement — Ontotext](https://www.ontotext.com/company/news/semantic-web-company-and-ontotext-merge-to-create-knowledge-graph-and-ai-powerhouse-graphwise/)
- [Merger announcement — Graphwise blog](https://graphwise.ai/blog/graphwise-merger-swc-ontotext/)
- [Graphwise bolsters GenAI with GraphDB update — BigDATAwire](https://www.bigdatawire.com/2025/07/08/graphwise-bolsters-genai-app-development-with-graphdb-update/)
- [20 Years in the Making — PoolParty blog](https://www.poolparty.biz/blogposts/swc-ontotext-merger-graphwise)
