# module "addon_lb" {
#   source                    = "./modules/addon_lb"
#   addon_context             = local.addon_context
#   eks_cluster_id            = local.eks_cluster_id
#   eks_cluster_version       = local.eks_cluster_version
#   cluster_security_group_id = local.cluster_security_group_id
#   resources_precreated      = false
#   tags                      = local.tags
# }

# output "out" {
#   value = module.addon_lb
# }
