# ☁️ Terraform AWS Secure Baseline

![Terraform](https://github.com/Aj3036max/terraform-aws-secure-baseline/actions/workflows/terraform.yml/badge.svg)
![Terraform](https://img.shields.io/badge/terraform-%E2%89%A51.10-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-CIS%20Foundations-FF9900?logo=amazonaws&logoColor=white)

**Socle de sécurité AWS en Infrastructure as Code**, aligné sur le **CIS AWS Foundations Benchmark**.
Un `terraform apply` sur un compte AWS neuf met en place la journalisation, la détection de menaces,
le chiffrement, un réseau segmenté et l'alerting — ce qu'une équipe Cloud Security déploie en premier.

## 🧩 Ce qui est déployé

| Domaine | Ressources | Contrôle CIS |
|---|---|---|
| **Identité** | Politique de mots de passe stricte (14 car., rotation 90 j, historique 24), IAM Access Analyzer | 1.8 – 1.9, 1.20 |
| **Journalisation** | CloudTrail multi-région + validation d'intégrité, logs vers S3 durci **et** CloudWatch | 3.1 – 3.7 |
| **Chiffrement** | Clé KMS client avec rotation auto, chiffrement EBS par défaut, S3 SSE-KMS | 2.2.1, 3.7, 3.8 |
| **Stockage** | Blocage accès public S3 (compte + bucket), TLS obligatoire, versioning, cycle de vie | 2.1.1, 2.1.4 |
| **Réseau** | VPC public/privé sur 2 AZ, SG par défaut sans aucune règle, VPC Flow Logs, endpoint S3 | 3.9, 5.4 |
| **Détection** | GuardDuty (+ S3 protection), findings high → SNS / e-mail | — |
| **Alerting** | 6 alarmes CIS : usage root, login sans MFA, appels refusés, changements IAM / CloudTrail / SG | 4.1 – 4.10 |
| **FinOps** | Budget mensuel avec alerte à 80 % | — |

## 🏗️ Architecture

```
                         ┌──────────────── Compte AWS ─────────────────┐
  API calls ──► CloudTrail ──► S3 (KMS, versionné, TLS-only, lifecycle) │
                    │                                                   │
                    └──► CloudWatch Logs ──► Metric filters CIS ──► Alarmes ─┐
                                                                         │
  GuardDuty ──► EventBridge (sévérité ≥ 7) ─────────────────────────► SNS ──► e-mail
  Budgets ─────────────────────────────────────────────────────────────┘
                                                                         
  VPC 10.20.0.0/16                                                       
   ├── public  10.20.0.0/24, 10.20.1.0/24      (IGW, pas d'IP publique auto)
   ├── private 10.20.100.0/24, 10.20.101.0/24  (aucune route Internet, endpoint S3)
   └── Flow Logs ──► CloudWatch (KMS)
```

## 🚀 Déploiement

```bash
cp terraform.tfvars.example terraform.tfvars   # puis renseigner alert_email
terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

> 💰 **Coût** : quasi nul sur un compte de test (pas de NAT Gateway). GuardDuty et CloudTrail → CloudWatch
> ont un coût à l'usage ; le budget à 10 $ prévient en cas de dérive. `terraform destroy` pour tout supprimer.

## ✅ Contrôles automatiques (CI)

Chaque push lance sans accès AWS :

- `terraform fmt` / `terraform validate`
- **TFLint** (ruleset AWS) : erreurs de types d'instance, attributs dépréciés…
- **Checkov** (policy as code) : **130 contrôles passés, 0 échec** ; les 9 exceptions sont **toutes justifiées** dans [`.checkov.yml`](.checkov.yml)

## 📁 Structure

```
versions.tf / variables.tf / outputs.tf
main.tf            KMS, IAM password policy, Access Analyzer, S3 public block, EBS encryption, VPC
logging.tf         CloudTrail + bucket + CloudWatch
detection.tf       GuardDuty, SNS, EventBridge, alarmes CIS, budget
modules/secure-s3  bucket S3 sécurisé réutilisable
modules/vpc        VPC segmenté + flow logs
```

## 📚 Ce que j'ai appris

- Structurer du Terraform en modules réutilisables
- Les contrôles du CIS AWS Foundations Benchmark et pourquoi ils existent
- Écrire des politiques IAM / KMS / S3 en moindre privilège
- Le "policy as code" avec Checkov et la justification des exceptions
