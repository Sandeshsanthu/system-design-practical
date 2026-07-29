# # 1. AWS Spec Configuration Profile for launched nodes
# resource "kubernetes_manifest" "karpenter_node_class" {
#   # Ensure the Karpenter controller software is fully deployed before applying CRDs
#   depends_on = [helm_release.karpenter]

#   # FIXED: Wrapped within a manifest block using yamldecode()
#   manifest = yamldecode(<<-YAML
#     apiVersion: karpenter.k8s.aws/v1
#     kind: EC2NodeClass
#     metadata:
#       name: default
#     spec:
#       # Pulls the IAM role name directly from your karpenter.tf module configurations
#       role: ${module.karpenter.node_iam_role_name}
      
#       # Auto-discovers subnets and security groups using EKS tags
#       subnetSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${local.name}
#       securityGroupSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${local.name}
            
#       # Uses the lightweight Bottlerocket OS 
#       amiFamily: Bottlerocket
      
#       # Configures cost-efficient root volumes
#       blockDeviceMappings:
#         - deviceName: /dev/xvda
#           ebs:
#             volumeSize: 30Gi
#             volumeType: gp3
#             encrypted: true
      
#       # Tracks node metrics safely
#       monitoring: true
#   YAML
#   )
# }

# # 2. Scheduling and Cost-Saving Policies for Workloads
# resource "kubernetes_manifest" "karpenter_node_pool" {
#   depends_on = [kubernetes_manifest.karpenter_node_class]

#   # FIXED: Wrapped within a manifest block using yamldecode()
#   manifest = yamldecode(<<-YAML
#     apiVersion: karpenter.sh/v1
#     kind: NodePool
#     metadata:
#       name: default
#     spec:
#       template:
#         spec:
#           nodeClassRef:
#             group: karpenter.k8s.aws
#             kind: EC2NodeClass
#             name: default
#           requirements:
#             - key: karpenter.sh/capacity-type
#               operator: In
#               values: ["spot"] # Forces cheap Spot instances to maximize savings
#             - key: kubernetes.io/arch
#               operator: In
#               values: ["amd64"]
#             - key: karpenter.k8s.aws/instance-family
#               operator: In
#               values: ["t3", "t3a"] # Limits compute strictly to burstable testing nodes
#             - key: karpenter.k8s.aws/instance-size
#               operator: In
#               values: ["small", "medium"]
      
#       # Safeguards to block massive automated billing overruns
#       limits:
#         cpu: 20
#         memory: 80Gi
        
#       # Day-2 Consolidation rules for cleaning empty compute spaces
#       disruption:
#         consolidationPolicy: WhenEmptyOrUnderutilized
#         consolidateAfter: 1m
#         expireAfter: 720h # Auto-recycle instances after 30 days
#   YAML
#   )
# }
