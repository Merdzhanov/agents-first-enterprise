"""Base types and regulatory compliance knowledge bases."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from ..tools import Handoff, RequestInput


@dataclass
class AgentResult:
    agent_name: str
    status: str
    message: str
    data: Dict[str, Any]
    handoff: Optional[Handoff] = None
    request_input: Optional[RequestInput] = None


# =====================================================================
# REGULATORY COMPLIANCE KNOWLEDGE BASE
# =====================================================================

GDPR_REQUIREMENTS = {
    "article_5_principles": [
        "Lawfulness, fairness and transparency",
        "Purpose limitation",
        "Data minimization",
        "Accuracy",
        "Storage limitation",
        "Integrity and confidentiality",
        "Accountability",
    ],
    "article_13_14_transparency": [
        "Identity and contact details of controller",
        "Purposes of processing and legal basis",
        "Right to withdraw consent",
        "Right to lodge complaint with supervisory authority",
    ],
    "article_15_22_data_subject_rights": [
        "Right of access", "Right to erasure", "Right to data portability",
        "Right to object", "Right to restriction of processing",
    ],
}

BULGARIA_REQUIREMENTS = {
    "zzld": {
        "full_name": "Закон за защита на личните данни (ЗЗЛД)",
        "authority": "Комисия за защита на личните данни (КЗЛД)",
        "requirements": [
            "Регистър на дейностите по обработване (чл. 30 ОРЗЛД)",
            "Оценка на въздействието при висок риск (чл. 35 ОРЗЛД)",
            "Уведомяване за нарушаване в 72 часа (чл. 37 ОРЗЛД)",
            "Право на информация, достъп, корекция, изтриване",
            "Специални категории данни – изрично съгласие (чл. 9)",
            "Забрана за профилиране на малолетни под 14 г.",
        ],
    },
    "nzok": {
        "authority": "НЗОК – Национална здравноосигурителна каса",
        "requirements": [
            "ЕГН – само с правно основание (ЗЗЛД + ЗДО)",
            "Медицински данни – специална категория (чл. 9 ОРЗЛД)",
            "Криптиране при пренос на здравна информация",
        ],
    },
    "financial": {
        "authority": "БНБ / Комисия за финансов надзор (КФН)",
        "requirements": [
            "PSD2 – отворен достъп до платежни данни чрез API",
            "AML Директива (EU) 2015/849",
            "ДДС регистрация при оборот > 50 000 лв.",
            "DAC7 – отчетност за платформена икономика",
        ],
    },
    "consumer_protection": {
        "authority": "КЗП – Комисия за защита на потребителите",
        "requirements": [
            "Право на отказ от покупка на разстояние (14 дни)",
            "Закон за електронната търговия – идентификация на търговеца",
        ],
    },
}

GLOBAL_REQUIREMENTS = {
    "california_ccpa": {
        "name": "CCPA/CPRA (California)",
        "authority": "California Privacy Protection Agency",
        "requirements": [
            "Right to know, delete, opt-out of sale",
            "Right to correct, limit use of sensitive data",
            "Do Not Sell link required on homepage",
        ],
    },
    "brazil_lgpd": {
        "name": "LGPD (Brazil)",
        "authority": "ANPD",
        "requirements": [
            "Free, informed, unambiguous consent",
            "DPO (Encarregado) must be appointed",
            "Data Protection Impact Report for high-risk",
        ],
    },
    "canada_pipeda": {
        "name": "PIPEDA (Canada)",
        "authority": "Office of the Privacy Commissioner",
        "requirements": [
            "Meaningful consent for collection, use, disclosure",
            "Breach reporting to OPC and affected individuals",
        ],
    },
    "pci_dss": {
        "name": "PCI DSS v4.0",
        "requirements": [
            "Never store CVV, full track data, or PIN",
            "Encrypt cardholder data across open networks",
            "Restrict access by business need-to-know",
            "Regularly test security systems",
        ],
    },
    "accessibility": {
        "name": "Web Accessibility (WCAG 2.1 AA)",
        "requirements": [
            "WCAG 2.1 AA minimum (EU Web Accessibility Directive)",
            "EN 301 549 – European ICT accessibility",
            "ADA Title III – US public accommodations",
        ],
    },
}
