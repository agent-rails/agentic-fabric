# Infrastructure Conventions

## Kubernetes
- Always check events first: `kubectl describe pod`
- Check resource limits before scaling
- Explicit `onDelete` on Prisma relations
- Index frequently filtered columns

## Deployment
- ArgoCD GitOps for all environments
- GitHub Actions CI/CD
- Karpenter for node autoscaling
- Helm for package management

## Database (Prisma)
- PascalCase models, camelCase fields
- Explicit relation names + `onDelete`
- `@@index` on frequently filtered columns
- Cascade deletes: always specify explicitly

## Terraform
- Modules for reusable infrastructure
- State in S3 with DynamoDB locking
