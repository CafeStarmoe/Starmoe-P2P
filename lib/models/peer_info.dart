/// EasyTier 对等节点状态模型
class PeerInfo {
  final String peerId;
  final String ipv4;
  final String hostname;
  final String tunnelType; // direct / relay
  final String protocol;   // tcp / udp / wg / kcp
  final int latencyMs;
  final int rxBytes;
  final int txBytes;
  final int rxRate; // bytes/sec
  final int txRate; // bytes/sec
  final bool isConnected;

  const PeerInfo({
    required this.peerId,
    required this.ipv4,
    this.hostname = '未知主机',
    this.tunnelType = 'Direct',
    this.protocol = 'TCP',
    this.latencyMs = 0,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.rxRate = 0,
    this.txRate = 0,
    this.isConnected = true,
  });

  factory PeerInfo.fromJson(Map<String, dynamic> json) {
    return PeerInfo(
      peerId: json['peer_id']?.toString() ?? '',
      ipv4: json['ipv4']?.toString() ?? '',
      hostname: json['hostname']?.toString() ?? '未知节点',
      tunnelType: json['tunnel_type']?.toString() ?? 'Direct',
      protocol: json['protocol']?.toString() ?? 'TCP',
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      rxBytes: (json['rx_bytes'] as num?)?.toInt() ?? 0,
      txBytes: (json['tx_bytes'] as num?)?.toInt() ?? 0,
      rxRate: (json['rx_rate'] as num?)?.toInt() ?? 0,
      txRate: (json['tx_rate'] as num?)?.toInt() ?? 0,
      isConnected: json['is_connected'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'ipv4': ipv4,
        'hostname': hostname,
        'tunnel_type': tunnelType,
        'protocol': protocol,
        'latency_ms': latencyMs,
        'rx_bytes': rxBytes,
        'tx_bytes': txBytes,
        'rx_rate': rxRate,
        'tx_rate': txRate,
        'is_connected': isConnected,
      };
}

/// 组网节点实时状态与统计
class NodeStatus {
  final bool isRunning;
  final String virtualIpv4;
  final String virtualIpv6;
  final String nodeName;
  final String networkName;
  final int uploadSpeedBytes;
  final int downloadSpeedBytes;
  final int totalUploadedBytes;
  final int totalDownloadedBytes;
  final Duration uptime;

  const NodeStatus({
    this.isRunning = false,
    this.virtualIpv4 = '',
    this.virtualIpv6 = '',
    this.nodeName = '',
    this.networkName = '',
    this.uploadSpeedBytes = 0,
    this.downloadSpeedBytes = 0,
    this.totalUploadedBytes = 0,
    this.totalDownloadedBytes = 0,
    this.uptime = Duration.zero,
  });
}

