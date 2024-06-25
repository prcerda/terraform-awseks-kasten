## Demo app

resource "kubernetes_namespace" "stock" {
  depends_on = [module.eks,helm_release.aws-csi-eks]

  metadata {
    name = "stock"
  }
}

resource "helm_release" "stockgres" {
  depends_on = [module.eks,helm_release.aws-csi-eks]

  name = "stockdb"
  namespace = kubernetes_namespace.stock.metadata[0].name
  create_namespace = false

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  
  set {
    name  = "global.postgresql.auth.username"
    value = "root"
  }

  set {
    name  = "global.postgresql.auth.password"
    value = "notsecure"
  }

  set {
    name  = "global.postgresql.auth.database"
    value = "stock"
  }
}

resource "kubernetes_config_map" "stockcm" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name = "stock-demo-configmap"
    namespace = kubernetes_namespace.stock.metadata[0].name
  }

  data = {
    "initinsert.psql" = "${file("${path.module}/initinsert.psql")}"
  }
}

resource "kubernetes_deployment" "stock-deploy" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name = "stock-demo-deploy"
    namespace = kubernetes_namespace.stock.metadata[0].name
    labels = {
      app = "stock-demo"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "stock-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "stock-demo"
        }
      }

      spec {
        volume {
          name = "config"
          config_map {
            name = "stock-demo-configmap"
          }
        }
        container {
          image = "tdewin/stock-demo"
          name  = "stock-demo"
          port {
            name = "stock-demo"
            container_port = "8080"
            protocol = "TCP"
          }
          volume_mount {
            name = "config"
            mount_path = "/var/stockdb"
            read_only = true
          }
          env {
              name = "POSTGRES_DB"
              value = "stock"
          }

          env {
              name = "POSTGRES_SERVER"
              value = "stockdb-postgresql"
          }

          env {
              name = "POSTGRES_USER"
              value = "root"
          }
          env {
              name = "POSTGRES_PORT"
              value = "5432"
          }
          env {
              name = "ADMINKEY"
              value = "unlock"
          }
          env {
              name = "POSTGRES_PASSWORD"
              value_from {
                secret_key_ref {
                  key = "password"
                  name = "stockdb-postgresql"
                }
              }
          }
        }
      }
    }
  }
}


resource "kubernetes_service_v1" "stock-demo-svc" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name = "stock-demo-svc"
    namespace = kubernetes_namespace.stock.metadata[0].name
    labels = {
      app = "stock-demo"
    }
  }
  spec {
    selector = {
      app = "stock-demo"
    }
    
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}
