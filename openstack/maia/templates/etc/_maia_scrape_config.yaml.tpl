- job_name: 'maia-exporters'
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
    # filter by maia scrape annotation
    - action: keep
      source_labels: [__meta_kubernetes_service_annotation_maia_io_scrape]
      regex: true
    - action: keep
      source_labels: [__meta_kubernetes_pod_container_port_number, __meta_kubernetes_pod_container_port_name, __meta_kubernetes_service_annotation_prometheus_io_port]
      regex: (9102;.*;.*)|(.*;metrics;.*)|(.*;.*;\d+)
    # support existing prometheus annotations (same configuration as everywhere else)
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
      target_label: __scheme__
      regex: (https?)
    - source_labels: [__meta_kubernetes_service_annotation_maia_io_scheme]
      target_label: __scheme__
      regex: (https?)
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__meta_kubernetes_service_annotation_maia_io_path]
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
      target_label: __address__
      regex: ([^:]+)(?::\d+);(\d+)
      replacement: $1:$2
    - source_labels: [__address__, __meta_kubernetes_service_annotation_maia_io_port]
      target_label: __address__
      regex: ([^:]+)(?::\d+);(\d+)
      replacement: $1:$2
    - action: labelmap
      regex: __meta_kubernetes_service_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_service_name]
      target_label: kubernetes_name
    # support injection of custom parameters
    - action: labelmap
      replacement: __param_$1
      regex: __meta_kubernetes_service_annotation_maia_io_scrape_param_(.+)

  metric_relabel_configs:
    - action: drop
      source_labels: [vmware_name]
      regex: c_blackbox.*|c_regression.*
    - action: labeldrop
      regex: "instance|job"
    - source_labels: [ltmVirtualServStatName]
      target_label: project_id
      regex: /Project_(.*)/Project_.*
    - source_labels: [ltmVirtualServStatName]
      target_label: lb_id
      regex: /Project_.*/Project_(.*)

# expose tenant-specific metrics collected by kube-system monitoring
- job_name: 'kube-system'
  static_configs:
    - targets: ['prometheus-collector.kube-monitoring:9090']
  metric_relabel_configs:
    - regex: "instance|job|kubernetes_namespace|kubernetes_pod_name|kubernetes_name|pod_template_hash|exported_instance|exported_job|type|name|component|app|system"
      action: labeldrop
  metrics_path: '/federate'
  params:
    'match[]':
      # import any tenant-specific metric, except for those which already have been imported
      - '{__name__=~"^openstack_.+",project_id!=""}'
      - '{__name__=~"^limes_(project|domain)_(quota|usage)"}'
      - '{__name__=~"^security_group_(max|total)_entanglement$"}'
