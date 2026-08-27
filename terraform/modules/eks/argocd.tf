# argo cd - gitops reconciler, installed via helm per the plan (not a plain kubectl apply)
# chart 10.4.0's default securityContexts already satisfy restricted psa (checked with `helm template`
# before applying - every container drops all capabilities and runs non-root), so no psa relaxation needed
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "10.4.0"
  namespace  = "argocd"

  # namespace + its restricted psa label were already created in step 5.5, helm shouldn't own it
  create_namespace = false

  # chart default is already ClusterIP - pinned explicitly so it can't silently drift to public exposure later
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}
