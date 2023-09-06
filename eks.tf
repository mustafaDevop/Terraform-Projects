
# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.21"

  vpc_config {
    subnet_ids         = [aws_subnet.prod_private_1.id, aws_subnet.prod_private_2.id]
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }
}

# EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-node-group"

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 5
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key               = "my-ssh-key"
    source_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  subnet_ids    = [aws_subnet.prod_private_1.id, aws_subnet.prod_private_2.id]
  node_role_arn = "YOUR_NODE_ROLE_ARN" # Replace with the ARN of your node role
}

# Kubernetes Namespace
resource "kubernetes_namespace" "safecho_namespace" {
  metadata {
    name = "safecho-namespace"
  }
}

# Deploy Docker image to EKS
resource "kubernetes_deployment" "safecho_deployment" {
  metadata {
    name      = "example-deployment"
    namespace = kubernetes_namespace.safecho_namespace.metadata[0].name
    labels = {
      app = "example-container"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "safecho-container"
      }
    }

    template {
      metadata {
        labels = {
          app = "safecho-container"
        }
      }

      spec {
        container {
          name  = "example-container"
          image = "${data.aws_ecr_repository.my_repo.repository_url}:latest"
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}
