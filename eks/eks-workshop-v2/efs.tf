# resource "aws_security_group" "efs" {
#   name        = "${var.cluster_name}-efs"
#   description = "Allow NFS traffic from within the VPC"
#   vpc_id      = module.vpc.vpc_id
# }

# resource "aws_vpc_security_group_egress_rule" "efs_egress" {
#   security_group_id = aws_security_group.efs.id
#   description       = "Allow all outbound"
#   ip_protocol       = "-1"
#   cidr_ipv4         = "0.0.0.0/0"
# }

# resource "aws_vpc_security_group_ingress_rule" "efs_nfs" {
#   security_group_id = aws_security_group.efs.id
#   description       = "NFS from VPC"
#   from_port         = 2049
#   to_port           = 2049
#   ip_protocol       = "tcp"
#   cidr_ipv4         = module.vpc.vpc_cidr_block
# }

# resource "aws_efs_file_system" "this" {
#   encrypted = true

#   tags = {
#     Name = var.cluster_name
#   }
# }

# resource "aws_efs_mount_target" "this" {
#   count = length(module.vpc.private_subnets)

#   file_system_id  = aws_efs_file_system.this.id
#   subnet_id       = module.vpc.private_subnets[count.index]
#   security_groups = [aws_security_group.efs.id]
# }

# resource "kubernetes_storage_class_v1" "efs" {
#   metadata {
#     name = "efs-dynamic-sc"
#   }

#   storage_provisioner    = "efs.csi.aws.com"
#   reclaim_policy         = "Delete"
#   volume_binding_mode    = "WaitForFirstConsumer"
#   allow_volume_expansion = true

#   parameters = {
#     provisioningMode = "efs-ap"
#     fileSystemId     = aws_efs_file_system.this.id
#     directoryPerms   = "700"
#   }

#   depends_on = [aws_efs_mount_target.this]
# }

# resource "aws_iam_role" "efs_csi" {
#   name = "${var.cluster_name}-efs-csi-driver"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "pods.eks.amazonaws.com"
#       }
#       Action = ["sts:AssumeRole", "sts:TagSession"]
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "efs_csi" {
#   role       = aws_iam_role.efs_csi.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
# }
