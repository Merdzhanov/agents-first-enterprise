"""Compliance Agent — multi-jurisdictional regulatory auditor."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from ..llm import VertexGeminiClient
from ..tools import ToolContext
from .base import AgentResult, GDPR_REQUIREMENTS, BULGARIA_REQUIREMENTS, GLOBAL_REQUIREMENTS


class ComplianceAgent:
    """Multi-jurisdictional regulatory compliance auditor."""
    name: str = "ComplianceAgent"

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def run(self, context: ToolContext) -> AgentResult:
        selected_idea = context.state.get("selected_idea", {})
        submission = context.state.get("submission_package", {})
        idea_title = selected_idea.get("title", "Unknown Product")
        report = self._audit_compliance(selected_idea, submission)
        context.state["compliance_report"] = report
        return AgentResult(
            agent_name=self.name, status="completed",
            message=f"Compliance audit complete for {idea_title}. "
                    f"{report['critical_issues_count']} critical, {report['warnings_count']} warnings.",
            data=report,
        )

    def _audit_compliance(self, idea, submission):
        findings = []
        findings.extend(self._check_gdpr(idea))
        findings.extend(self._check_bulgaria(idea))
        findings.extend(self._check_global(idea))
        findings.extend(self._check_accessibility(idea, submission))
        critical_count = sum(1 for f in findings if f["severity"] == "critical")
        warning_count = sum(1 for f in findings if f["severity"] == "warning")
        return {
            "audit_timestamp": datetime.now(timezone.utc).isoformat(),
            "product": idea.get("title", "Unknown"),
            "audited_scope": ["GDPR", "Bulgaria", "CCPA", "LGPD", "PIPEDA", "PCI DSS", "WCAG"],
            "critical_issues_count": critical_count,
            "warnings_count": warning_count,
            "findings": findings,
            "recommendations": self._generate_recommendations(findings),
            "compliance_score": self._score(critical_count, warning_count),
        }

    def _check_gdpr(self, idea):
        findings = []
        tech_stack = [t.lower() for t in (idea.get("tech_stack") or [])]
        description = (idea.get("description") or "").lower()
        pii_keywords = ["user", "email", "profile", "account", "payment", "personal", "health"]
        if any(kw in description for kw in pii_keywords):
            findings.append({"jurisdiction": "EU / GDPR", "severity": "warning", "article": "Art. 5, 6, 13", "description": "Product processes personal data.", "requirements": GDPR_REQUIREMENTS["article_5_principles"][:3]})
        findings.append({"jurisdiction": "EU / GDPR", "severity": "warning", "article": "Art. 7", "description": "Ensure granular consent mechanism.", "requirements": ["Consent must be freely given, specific, informed, unambiguous"]})
        cloud_providers = ["aws", "gcp", "azure", "cloudflare"]
        if any(p in " ".join(tech_stack) for p in cloud_providers):
            findings.append({"jurisdiction": "EU / GDPR", "severity": "warning", "article": "Art. 44-49", "description": "Cloud provider detected. Verify SCCs.", "requirements": ["EU-US Data Privacy Framework or SCCs"]})
        return findings

    def _check_bulgaria(self, idea):
        findings = []
        description = (idea.get("description") or "").lower()
        if any(kw in description for kw in ["user", "email", "profile"]):
            findings.append({"jurisdiction": "Bulgaria / ЗЗЛД", "severity": "warning", "legal_basis": "ЗЗЛД чл. 30", "description": "Обработване на лични данни.", "requirements": BULGARIA_REQUIREMENTS["zzld"]["requirements"][:3]})
        if any(kw in description for kw in ["health", "medical", "patient"]):
            findings.append({"jurisdiction": "Bulgaria / НЗОК", "severity": "critical", "legal_basis": "ЗЗЛД чл. 9 + ЗДО", "description": "Медицински данни – специална категория.", "requirements": BULGARIA_REQUIREMENTS["nzok"]["requirements"]})
        if any(kw in description for kw in ["payment", "billing", "invoice"]):
            findings.append({"jurisdiction": "Bulgaria / БНБ-КФН", "severity": "warning", "legal_basis": "PSD2, ЗДО", "description": "Финансови услуги – проверете лицензиране.", "requirements": BULGARIA_REQUIREMENTS["financial"]["requirements"][:2]})
        if any(kw in description for kw in ["buy", "purchase", "shop"]):
            findings.append({"jurisdiction": "Bulgaria / КЗП", "severity": "warning", "legal_basis": "ЗЗП / Директива 2011/83/ЕС", "description": "E-commerce – право на отказ 14 дни.", "requirements": BULGARIA_REQUIREMENTS["consumer_protection"]["requirements"]})
        return findings

    def _check_global(self, idea):
        findings = []
        description = (idea.get("description") or "").lower()
        if any(kw in description for kw in ["user", "profile", "email"]):
            findings.append({"jurisdiction": "California / CCPA", "severity": "warning", "legal_basis": "Cal. Civ. Code", "description": "California residents: implement Do Not Sell link.", "requirements": GLOBAL_REQUIREMENTS["california_ccpa"]["requirements"][:3]})
        if "user" in description or "personal" in description:
            findings.append({"jurisdiction": "Brazil / LGPD", "severity": "warning", "legal_basis": "Lei 13.709/2018", "description": "Brazil: appoint DPO, implement data subject rights.", "requirements": GLOBAL_REQUIREMENTS["brazil_lgpd"]["requirements"][:2]})
        payment_keywords = ["payment", "credit card", "stripe", "paypal", "billing", "checkout"]
        if any(kw in description for kw in payment_keywords):
            findings.append({"jurisdiction": "Global / PCI DSS", "severity": "critical", "legal_basis": "PCI DSS v4.0", "description": "Never store CVV. Use tokenization.", "requirements": GLOBAL_REQUIREMENTS["pci_dss"]["requirements"][:2]})
        return findings

    def _check_accessibility(self, idea, submission):
        findings = []
        tech_stack = [t.lower() for t in (idea.get("tech_stack") or [])]
        project_type = submission.get("project_type", "")
        frontend_indicators = ["flutter", "dart", "react", "vue", "angular", "web", "wasm", "frontend"]
        is_frontend = any(t in " ".join(tech_stack) for t in frontend_indicators) or project_type in ("flutter_wasm",)
        if is_frontend:
            findings.append({"jurisdiction": "Global / WCAG 2.1 AA", "severity": "warning", "legal_basis": "EN 301 549 / ADA Title III", "description": "Ensure WCAG 2.1 AA — Semantics, focus management, screen reader.", "requirements": GLOBAL_REQUIREMENTS["accessibility"]["requirements"]})
        return findings

    def _generate_recommendations(self, findings):
        recs = []
        for f in findings:
            if f["severity"] == "critical":
                recs.append(f"[CRITICAL] {f['jurisdiction']}: {f['description']}")
            elif f["severity"] == "warning":
                recs.append(f"[WARNING] {f['jurisdiction']}: {f['description']}")
        if not recs:
            recs.append("No critical compliance issues detected.")
        return recs

    def _score(self, critical, warning):
        base = 100 - critical * 25 - warning * 5
        score = max(0, min(100, base))
        return {"overall": score, "grade": "A" if score >= 90 else "B" if score >= 75 else "C" if score >= 60 else "D" if score >= 40 else "F", "blocking": critical > 0}
