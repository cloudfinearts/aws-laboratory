# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

EKS workshop lab — a production-like EKS cluster on AWS using Terraform. Region: `eu-central-1`. All infrastructure is in a single Terraform root module.

## Common Commands

```bash
# From this directory
terraform plan
terraform apply
terraform destroy

# Verify cluster after apply
kubectl get nodes
```

## Architecture

### Terraform file layout

| File | Purpose |
|------|---------|
| `main.tf` | Providers, locals, tags |
| `eks.tf` | EKS cluster, managed node group, core addons |
| `vpc.tf` | VPC, subnets, NAT gateway |
| `karpenter.tf` | Karpenter IAM, helm release, NodePool helm chart |
| `addons.tf` | `aws-ia/eks-blueprints-addons` — ALB controller, metrics server |
| `ebs.tf` | IAM role for EBS CSI driver (pod identity) |
| `efs.tf` | EFS filesystem, mount targets, storage class, IAM role for EFS CSI |
| `workload.tf` | Kubernetes and Helm provider configuration |
| `variables.tf` | Cluster name, version, VPC CIDR |

### IAM authentication: Pod Identity (not IRSA)

OIDC is disabled. All addon IAM roles use **EKS Pod Identity** (`pods.eks.amazonaws.com` trust principal, `sts:AssumeRole` + `sts:TagSession` actions). IRSA patterns from documentation won't apply here.

### Addon split: managed vs blueprints

- **EKS managed addons** (`eks.tf` `addons` block): vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, aws-efs-csi-driver, eks-pod-identity-agent
- **Blueprints addons** (`addons.tf`): AWS Load Balancer Controller, metrics-server

EFS CSI is a managed addon (not blueprints helm chart) because the blueprints chart shipped driver v1.7.6 which used an old AWS SDK incompatible with the pod identity endpoint `169.254.170.23`.

### Node provisioning

Single MNG (`t3.medium`, 1 node) with label `karpenter-controller: yes` — runs Karpenter. Karpenter provisions application nodes from the `karpenter-application` NodePool (spot, instance categories m/t/c, sizes small/medium/large).

### Destroy safety

`helm_release.nodepool` has `wait = true` / `timeout = 120`. On destroy, Helm blocks until the NodePool finalizer is removed — meaning Karpenter has terminated all provisioned nodes — before proceeding to uninstall Karpenter itself. This prevents orphaned EC2 instances blocking VPC subnet deletion.

### LBC webhook ordering

`module.addons` has `depends_on = [module.eks]` to ensure all EKS managed addons (including CoreDNS) are ACTIVE before LBC installs. Without this, LBC's `MutatingWebhookConfiguration` (failurePolicy: Fail) intercepts CoreDNS Service creation while LBC pods have no endpoints, causing CoreDNS addon to fail.

## Kubernetes Manifests

`manifests/` contains example workloads. Apply with `kubectl apply -f manifests/<file>.yaml`.
